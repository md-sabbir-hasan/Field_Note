package com.fieldnotes.backend.customer;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface CustomerRepository extends JpaRepository<Customer, String> {

    // Active (not deleted) customers of one user.
    List<Customer> findByUserIdAndDeletedAtIsNullOrderByNameAsc(Long userId);

    // Ownership check is part of the query, so another user's id simply returns empty.
    Optional<Customer> findByIdAndUserId(String id, Long userId);

    // Includes soft deleted rows on purpose: devices must learn about deletions.
    List<Customer> findByUserIdAndUpdatedAtGreaterThan(Long userId, Instant since);
}