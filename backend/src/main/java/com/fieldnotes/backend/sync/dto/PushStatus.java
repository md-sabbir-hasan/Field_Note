package com.fieldnotes.backend.sync.dto;

public enum PushStatus {
    ACCEPTED,   // change applied
    SKIPPED,    // server already has an equal or newer edit (last-write-wins), nothing to retry
    REJECTED    // invalid or not allowed, see message
}