package com.fieldnotes.backend.sync.dto;

import com.fieldnotes.backend.note.FieldNote;
import com.fieldnotes.backend.note.NoteStatus;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.Instant;

public record SyncNote(
        @NotBlank @Size(min = 36, max = 36) String id,
        @NotBlank @Size(min = 36, max = 36) String siteId,
        @NotBlank @Size(max = 200) String title,
        @Size(max = 10000) String description,
        @DecimalMin("-90") @DecimalMax("90") BigDecimal latitude,
        @DecimalMin("-180") @DecimalMax("180") BigDecimal longitude,
        @NotNull Instant notedAt,
        @NotNull NoteStatus status,
        String photoPath,          // server owned (photo upload endpoint), ignored on push
        @NotNull Instant clientUpdatedAt,
        Instant deletedAt,
        Instant updatedAt
) {
    // Expects the site to be fetched already (JOIN FETCH).
    public static SyncNote from(FieldNote n) {
        return new SyncNote(n.getId(), n.getSite().getId(), n.getTitle(), n.getDescription(),
                n.getLatitude(), n.getLongitude(), n.getNotedAt(), n.getStatus(), n.getPhotoPath(),
                n.getClientUpdatedAt(), n.getDeletedAt(), n.getUpdatedAt());
    }
}