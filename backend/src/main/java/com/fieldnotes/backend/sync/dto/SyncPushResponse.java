package com.fieldnotes.backend.sync.dto;

import java.util.List;

public record SyncPushResponse(List<SyncItemResult> results) {}