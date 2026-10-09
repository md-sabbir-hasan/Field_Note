package com.fieldnotes.backend.note;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface FieldNoteRepository extends JpaRepository<FieldNote, String> {

    // One query does search + filters. Data isolation comes from c.userId (note -> site -> customer).
    // :q is a ready-made pattern like %text% (or null when there is no search text).
    @Query("""
            SELECT n FROM FieldNote n
              JOIN FETCH n.site s
              JOIN FETCH s.customer c
            WHERE c.userId = :userId
              AND n.deletedAt IS NULL
              AND s.deletedAt IS NULL
              AND c.deletedAt IS NULL
              AND (:status IS NULL OR n.status = :status)
              AND (:siteId IS NULL OR s.id = :siteId)
              AND (:q IS NULL
                   OR LOWER(n.title) LIKE :q
                   OR LOWER(n.description) LIKE :q
                   OR LOWER(s.siteName) LIKE :q
                   OR LOWER(c.name) LIKE :q)
            ORDER BY n.notedAt DESC
            """)
    List<FieldNote> search(@Param("userId") Long userId,
                           @Param("q") String q,
                           @Param("status") NoteStatus status,
                           @Param("siteId") String siteId);

    // Ownership check through both parents.
    @Query("""
            SELECT n FROM FieldNote n
              JOIN FETCH n.site s
              JOIN FETCH s.customer c
            WHERE n.id = :id AND c.userId = :userId
            """)
    Optional<FieldNote> findOwned(@Param("id") String id, @Param("userId") Long userId);

    // Cascade helpers for site / customer soft delete.
    @Modifying
    @Query("""
            UPDATE FieldNote n SET n.deletedAt = :now, n.updatedAt = :now
            WHERE n.site.id = :siteId AND n.deletedAt IS NULL
            """)
    int softDeleteBySite(@Param("siteId") String siteId, @Param("now") Instant now);

    @Modifying
    @Query("""
            UPDATE FieldNote n SET n.deletedAt = :now, n.updatedAt = :now
            WHERE n.deletedAt IS NULL
              AND n.site.id IN (SELECT s.id FROM Site s WHERE s.customer.id = :customerId)
            """)
    int softDeleteByCustomer(@Param("customerId") String customerId, @Param("now") Instant now);
}