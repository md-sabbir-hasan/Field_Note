package com.fieldnotes.backend.customer;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "customers")
@Getter
@Setter
@NoArgsConstructor
public class Customer {

    // Generated on the client (UUID) so records can be created offline without id clashes.
    @Id
    @Column(length = 36)
    private String id;

    // Owner of this record. Every query must filter by it (data isolation).
    @Column(name = "user_id", nullable = false, updatable = false)
    private Long userId;

    @Column(nullable = false, length = 150)
    private String name;

    @Column(name = "contact_info", columnDefinition = "TEXT")
    private String contactInfo;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    // Set by the service on every change; the sync endpoints rely on it.
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    // Soft delete marker: non-null means the record is deleted.
    @Column(name = "deleted_at")
    private Instant deletedAt;
}