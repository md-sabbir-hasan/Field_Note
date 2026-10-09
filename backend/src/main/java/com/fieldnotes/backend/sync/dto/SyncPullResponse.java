package com.fieldnotes.backend.sync.dto;

import java.time.Instant;
import java.util.List;

public record SyncPullResponse(
        Instant serverTime,         // the client stores this and sends it as `since` next time
        List<SyncCustomer> customers,
        List<SyncSite> sites,
        List<SyncNote> notes
) {}