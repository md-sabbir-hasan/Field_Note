package com.fieldnotes.backend.note;

import com.fieldnotes.backend.note.dto.NoteRequest;
import com.fieldnotes.backend.note.dto.NoteResponse;
import com.fieldnotes.backend.site.Site;
import com.fieldnotes.backend.site.SiteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class FieldNoteService {

    private final FieldNoteRepository noteRepository;
    private final SiteRepository siteRepository;

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
}