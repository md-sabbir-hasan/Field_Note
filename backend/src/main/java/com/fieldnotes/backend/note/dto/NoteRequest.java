package com.fieldnotes.backend.note.dto;

import com.fieldnotes.backend.note.NoteStatus;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.Instant;

public record NoteRequest(
        @NotBlank @Size(min = 36, max = 36) String siteId,
        @NotBlank @Size(max = 200) String title,
        @Size(max = 10000) String description,
        @DecimalMin("-90") @DecimalMax("90") BigDecimal latitude,
        @DecimalMin("-180") @DecimalMax("180") BigDecimal longitude,
        @NotNull Instant notedAt,
        @NotNull NoteStatus status
) {}