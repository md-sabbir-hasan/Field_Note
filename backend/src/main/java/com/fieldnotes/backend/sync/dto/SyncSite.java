package com.fieldnotes.backend.sync.dto;

import com.fieldnotes.backend.site.Site;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.Instant;

public record SyncSite(
        @NotBlank @Size(min = 36, max = 36) String id,
        @NotBlank @Size(min = 36, max = 36) String customerId,
        @NotBlank @Size(max = 150) String siteName,
        @Size(max = 2000) String address,
        @NotNull Instant clientUpdatedAt,
        Instant deletedAt,
        Instant updatedAt
) {
    // Expects the customer to be fetched already (JOIN FETCH).
    public static SyncSite from(Site s) {
        return new SyncSite(s.getId(), s.getCustomer().getId(), s.getSiteName(), s.getAddress(),
                s.getClientUpdatedAt(), s.getDeletedAt(), s.getUpdatedAt());
    }
}