package com.fieldnotes.backend.sync.dto;

import com.fieldnotes.backend.customer.Customer;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.Instant;

/** Same shape is used for push (client -> server) and pull (server -> client). */
public record SyncCustomer(
        @NotBlank @Size(min = 36, max = 36) String id,
        @NotBlank @Size(max = 150) String name,
        @Size(max = 2000) String contactInfo,
        @NotNull Instant clientUpdatedAt,
        Instant deletedAt,
        Instant updatedAt          // server save time, ignored on push
) {
    public static SyncCustomer from(Customer c) {
        return new SyncCustomer(c.getId(), c.getName(), c.getContactInfo(),
                c.getClientUpdatedAt(), c.getDeletedAt(), c.getUpdatedAt());
    }
}