package com.fieldnotes.backend.note;

import com.fieldnotes.backend.note.dto.NoteRequest;
import com.fieldnotes.backend.note.dto.NoteResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import com.fieldnotes.backend.storage.PhotoStorage;
import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/notes")
@RequiredArgsConstructor
public class FieldNoteController {

    private final FieldNoteService noteService;

    // /api/notes?q=pump&status=OPEN&siteId=...  (all params optional)
    @GetMapping
    public List<NoteResponse> search(@AuthenticationPrincipal Long userId,
                                     @RequestParam(required = false) String q,
                                     @RequestParam(required = false) NoteStatus status,
                                     @RequestParam(required = false) String siteId) {
        return noteService.search(userId, q, status, siteId);
    }

    @GetMapping("/{id}")
    public NoteResponse get(@AuthenticationPrincipal Long userId, @PathVariable String id) {
        return noteService.get(userId, id);
    }

    @PutMapping("/{id}")
    public NoteResponse upsert(@AuthenticationPrincipal Long userId,
                               @PathVariable String id,
                               @Valid @RequestBody NoteRequest request) {
        return noteService.upsert(userId, id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal Long userId, @PathVariable String id) {
        noteService.delete(userId, id);
    }


    @PostMapping(value = "/{id}/photo", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public NoteResponse uploadPhoto(@AuthenticationPrincipal Long userId,
                                    @PathVariable String id,
                                    @RequestParam("file") MultipartFile file) {
        return noteService.uploadPhoto(userId, id, file);
    }

    @GetMapping("/{id}/photo")
    public ResponseEntity<Resource> getPhoto(@AuthenticationPrincipal Long userId,
                                             @PathVariable String id) {
        Resource photo = noteService.getPhoto(userId, id);
        return ResponseEntity.ok()
                .contentType(PhotoStorage.mediaTypeOf(photo.getFilename()))
                // Private: it is user data, and a new upload gets a new file name anyway.
                .cacheControl(CacheControl.noCache().cachePrivate())
                .body(photo);
    }

    @DeleteMapping("/{id}/photo")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deletePhoto(@AuthenticationPrincipal Long userId, @PathVariable String id) {
        noteService.deletePhoto(userId, id);
    }
}