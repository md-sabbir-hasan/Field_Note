package com.fieldnotes.backend.note;

import com.fieldnotes.backend.site.Site;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "field_notes")
@Getter
@Setter
@NoArgsConstructor
public class FieldNote {

    // Client generated UUID.
    @Id
    @Column(length = 36)
    private String id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "site_id", nullable = false)
    private Site site;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(precision = 10, scale = 8)
    private BigDecimal latitude;

    @Column(precision = 11, scale = 8)
    private BigDecimal longitude;

    @Column(name = "noted_at", nullable = false)
    private Instant notedAt;

    // Stored as text so the DB column stays a plain VARCHAR.
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 50)
    private NoteStatus status;

    @Column(name = "photo_path", length = 255)
    private String photoPath;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    // Non-null means soft deleted.
    @Column(name = "deleted_at")
    private Instant deletedAt;

    @Column(name = "client_updated_at", nullable = false)
    private Instant clientUpdatedAt;
}