package com.fieldnotes.backend.note;

import com.fieldnotes.backend.note.dto.NoteRequest;
import com.fieldnotes.backend.note.dto.NoteResponse;
import com.fieldnotes.backend.site.Site;
import com.fieldnotes.backend.site.SiteRepository;
import com.fieldnotes.backend.storage.PhotoStorage;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class FieldNoteService {

    private final FieldNoteRepository noteRepository;
    private final SiteRepository siteRepository;
    private final PhotoStorage photoStorage;

    @Transactional(readOnly = true)
    public List<NoteResponse> search(Long userId, String q, NoteStatus status, String siteId) {
        // Build the LIKE pattern once; blank text means "no search".
        String pattern = (q == null || q.isBlank())
                ? null
                : "%" + q.trim().toLowerCase() + "%";

        return noteRepository.search(userId, pattern, status, siteId)
                .stream()
                .map(NoteResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public NoteResponse get(Long userId, String id) {
        FieldNote note = noteRepository.findOwned(id, userId)
                .filter(n -> n.getDeletedAt() == null)
                .orElseThrow(() -> notFound("Note not found"));
        return NoteResponse.from(note);
    }

    /** Create-or-update by client generated id (idempotent, safe to retry). */
    @Transactional
    public NoteResponse upsert(Long userId, String id, NoteRequest request) {
        validateUuid(id);
        Instant now = Instant.now();

        // The parent site must belong to this user (through its customer) and be active.
        Site site = siteRepository.findOwned(request.siteId(), userId)
                .filter(s -> s.getDeletedAt() == null && s.getCustomer().getDeletedAt() == null)
                .orElseThrow(() -> notFound("Site not found"));

        FieldNote note = noteRepository.findById(id).orElse(null);

        if (note == null) {
            note = new FieldNote();
            note.setId(id);
            note.setCreatedAt(now);
        } else if (!note.getSite().getCustomer().getUserId().equals(userId)
                || note.getDeletedAt() != null) {
            // Same 404 for "not yours" and "deleted".
            throw notFound("Note not found");
        }

        note.setSite(site);
        note.setTitle(request.title().trim());
        note.setDescription(request.description());
        note.setLatitude(request.latitude());
        note.setLongitude(request.longitude());
        note.setNotedAt(request.notedAt());
        note.setStatus(request.status());
        note.setUpdatedAt(now);
        note.setClientUpdatedAt(now);

        return NoteResponse.from(noteRepository.save(note));
    }

    /** Soft delete so other devices learn about it on their next sync. */
    @Transactional
    public void delete(Long userId, String id) {
        FieldNote note = noteRepository.findOwned(id, userId)
                .orElseThrow(() -> notFound("Note not found"));

        if (note.getDeletedAt() != null) {
            return; // already deleted, idempotent
        }

        Instant now = Instant.now();
        note.setDeletedAt(now);
        note.setUpdatedAt(now);
        note.setClientUpdatedAt(now);
    }

    private static void validateUuid(String id) {
        try {
            UUID.fromString(id);
        } catch (IllegalArgumentException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "id must be a valid UUID");
        }
    }

    private static ResponseStatusException notFound(String message) {
        return new ResponseStatusException(HttpStatus.NOT_FOUND, message);
    }


    /** Saves (or replaces) the photo of a note. The note itself must already exist on the server. */
    @Transactional
    public NoteResponse uploadPhoto(Long userId, String id, MultipartFile file) {
        FieldNote note = findActiveOwned(userId, id);

        String oldFile = note.getPhotoPath();
        note.setPhotoPath(photoStorage.store(file));
        // Server time only: other devices must pull the new photoPath. clientUpdatedAt stays untouched
        // so the last-write-wins comparison for the text fields is not disturbed.
        note.setUpdatedAt(Instant.now());

        deleteFileAfterCommit(oldFile);
        return NoteResponse.from(note);
    }

    @Transactional(readOnly = true)
    public Resource getPhoto(Long userId, String id) {
        FieldNote note = findActiveOwned(userId, id);
        if (note.getPhotoPath() == null) {
            throw notFound("This note has no photo");
        }
        return photoStorage.load(note.getPhotoPath());
    }

    @Transactional
    public void deletePhoto(Long userId, String id) {
        FieldNote note = findActiveOwned(userId, id);
        String oldFile = note.getPhotoPath();
        if (oldFile == null) return;   // nothing to do, idempotent

        note.setPhotoPath(null);
        note.setUpdatedAt(Instant.now());
        deleteFileAfterCommit(oldFile);
    }

    private FieldNote findActiveOwned(Long userId, String id) {
        return noteRepository.findOwned(id, userId)
                .filter(n -> n.getDeletedAt() == null)
                .orElseThrow(() -> notFound("Note not found"));
    }

    // If the DB transaction rolls back, the old photo must still exist.
    private void deleteFileAfterCommit(String filename) {
        if (filename == null) return;
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                photoStorage.deleteQuietly(filename);
            }
        });
    }
}