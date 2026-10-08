package com.fieldnotes.backend.customer.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CustomerRequest(
        @NotBlank @Size(max = 150) String name,
        @Size(max = 2000) String contactInfo
) {}