package com.fieldnotes.backend.customer.dto;

import com.fieldnotes.backend.customer.Customer;

import java.time.Instant;

public record CustomerResponse(
        String id,
        String name,
        String contactInfo,
        Instant createdAt,
        Instant updatedAt
) {
    public static CustomerResponse from(Customer c) {
        return new CustomerResponse(
                c.getId(), c.getName(), c.getContactInfo(), c.getCreatedAt(), c.getUpdatedAt());
    }
}