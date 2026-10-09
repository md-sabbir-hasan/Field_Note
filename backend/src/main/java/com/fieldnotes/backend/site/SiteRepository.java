package com.fieldnotes.backend.site;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface SiteRepository extends JpaRepository<Site, String> {

    // Active sites of a user. The user filter goes through the customer (JOIN).
    @Query("""
            SELECT s FROM Site s JOIN FETCH s.customer c
            WHERE c.userId = :userId
              AND s.deletedAt IS NULL
              AND c.deletedAt IS NULL
              AND (:customerId IS NULL OR c.id = :customerId)
            ORDER BY s.siteName ASC
            """)
    List<Site> findActive(@Param("userId") Long userId,
                          @Param("customerId") String customerId);

    // Ownership check: the site is only returned if its customer belongs to the user.
    @Query("""
            SELECT s FROM Site s JOIN FETCH s.customer c
            WHERE s.id = :id AND c.userId = :userId
            """)
    Optional<Site> findOwned(@Param("id") String id, @Param("userId") Long userId);

    // Cascade for customer soft delete. Only touches rows that are still active.
    @Modifying
    @Query("""
            UPDATE Site s SET s.deletedAt = :now, s.updatedAt = :now
            WHERE s.customer.id = :customerId AND s.deletedAt IS NULL
            """)
    int softDeleteByCustomer(@Param("customerId") String customerId, @Param("now") Instant now);
}