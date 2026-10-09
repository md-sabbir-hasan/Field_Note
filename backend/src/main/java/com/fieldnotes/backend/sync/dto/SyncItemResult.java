package com.fieldnotes.backend.sync.dto;

public record SyncItemResult(
        String entity,      // "customer" | "site" | "note"
        String id,
        PushStatus status,
        String message      // only set when REJECTED
) {}