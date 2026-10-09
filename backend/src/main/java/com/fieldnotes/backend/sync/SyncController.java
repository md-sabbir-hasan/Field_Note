package com.fieldnotes.backend.sync;

import com.fieldnotes.backend.sync.dto.SyncPullResponse;
import com.fieldnotes.backend.sync.dto.SyncPushRequest;
import com.fieldnotes.backend.sync.dto.SyncPushResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;

@RestController
@RequestMapping("/api/sync")
@RequiredArgsConstructor
public class SyncController {

    private final SyncService syncService;

    // /api/sync/pull?since=2026-10-09T10:00:00Z   (no `since` = full restore)
    @GetMapping("/pull")
    public SyncPullResponse pull(@AuthenticationPrincipal Long userId,
                                 @RequestParam(required = false)
                                 @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant since) {
        return syncService.pull(userId, since);
    }

    @PostMapping("/push")
    public SyncPushResponse push(@AuthenticationPrincipal Long userId,
                                 @RequestBody SyncPushRequest request) {
        return syncService.push(userId, request);
    }
}