package com.fieldnotes.backend.site.dto;

import com.fieldnotes.backend.site.Site;

import java.time.Instant;

public record SiteResponse(
        String id,
        String customerId,
        String customerName,   // read from the customer row, never stored on the site
        String siteName,
        String address,
        Instant createdAt,
        Instant updatedAt
) {
    // Expects the customer to be fetched already (JOIN FETCH), so no extra query happens.
    public static SiteResponse from(Site s) {
        return new SiteResponse(
                s.getId(),
                s.getCustomer().getId(),
                s.getCustomer().getName(),
                s.getSiteName(),
                s.getAddress(),
                s.getCreatedAt(),
                s.getUpdatedAt());
    }
}