package com.fieldnotes.backend.site;

import com.fieldnotes.backend.site.dto.SiteRequest;
import com.fieldnotes.backend.site.dto.SiteResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/sites")
@RequiredArgsConstructor
public class SiteController {

    private final SiteService siteService;

    // Optional filter: /api/sites?customerId=...
    @GetMapping
    public List<SiteResponse> list(@AuthenticationPrincipal Long userId,
                                   @RequestParam(required = false) String customerId) {
        return siteService.list(userId, customerId);
    }

    @GetMapping("/{id}")
    public SiteResponse get(@AuthenticationPrincipal Long userId, @PathVariable String id) {
        return siteService.get(userId, id);
    }

    @PutMapping("/{id}")
    public SiteResponse upsert(@AuthenticationPrincipal Long userId,
                               @PathVariable String id,
                               @Valid @RequestBody SiteRequest request) {
        return siteService.upsert(userId, id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal Long userId, @PathVariable String id) {
        siteService.delete(userId, id);
    }
}