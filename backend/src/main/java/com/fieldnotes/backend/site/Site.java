package com.fieldnotes.backend.site;

import com.fieldnotes.backend.customer.Customer;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "sites")
@Getter
@Setter
@NoArgsConstructor
public class Site {

    // Client generated UUID, same idea as Customer.
    @Id
    @Column(length = 36)
    private String id;

    // Lazy: the customer is only loaded when we really need it (e.g. JOIN FETCH in queries).
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "customer_id", nullable = false)
    private Customer customer;

    @Column(name = "site_name", nullable = false, length = 150)
    private String siteName;

    @Column(columnDefinition = "TEXT")
    private String address;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    // Non-null means soft deleted.
    @Column(name = "deleted_at")
    private Instant deletedAt;
}