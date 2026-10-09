package com.fieldnotes.backend.sync.dto;

import java.util.List;

/** Any list may be null or empty. */
public record SyncPushRequest(
        List<SyncCustomer> customers,
        List<SyncSite> sites,
        List<SyncNote> notes
) {}