package com.fieldnotes.backend.note.dto;

import com.fieldnotes.backend.note.FieldNote;
import com.fieldnotes.backend.note.NoteStatus;

import java.math.BigDecimal;
import java.time.Instant;

public record NoteResponse(
        String id,
        String siteId,
        String siteName,        // from the sites row
        String customerId,
        String customerName,    // from the customers row
        String title,
        String description,
        BigDecimal latitude,
        BigDecimal longitude,
        Instant notedAt,
        NoteStatus status,
        String photoPath,
        Instant createdAt,
        Instant updatedAt
) {
    // Expects site and customer to be fetched already (JOIN FETCH).
    public static NoteResponse from(FieldNote n) {
        return new NoteResponse(
                n.getId(),
                n.getSite().getId(),
                n.getSite().getSiteName(),
                n.getSite().getCustomer().getId(),
                n.getSite().getCustomer().getName(),
                n.getTitle(),
                n.getDescription(),
                n.getLatitude(),
                n.getLongitude(),
                n.getNotedAt(),
                n.getStatus(),
                n.getPhotoPath(),
                n.getCreatedAt(),
                n.getUpdatedAt());
    }
}