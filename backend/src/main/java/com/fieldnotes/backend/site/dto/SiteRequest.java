package com.fieldnotes.backend.site.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SiteRequest(
        @NotBlank @Size(min = 36, max = 36) String customerId,
        @NotBlank @Size(max = 150) String siteName,
        @Size(max = 2000) String address
) {}