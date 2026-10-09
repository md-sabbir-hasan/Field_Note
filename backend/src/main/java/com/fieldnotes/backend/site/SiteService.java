package com.fieldnotes.backend.site;

import com.fieldnotes.backend.customer.Customer;
import com.fieldnotes.backend.customer.CustomerRepository;
import com.fieldnotes.backend.site.dto.SiteRequest;
import com.fieldnotes.backend.site.dto.SiteResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class SiteService {

    private final SiteRepository siteRepository;
    private final CustomerRepository customerRepository;

    @Transactional(readOnly = true)
    public List<SiteResponse> list(Long userId, String customerId) {
        return siteRepository.findActive(userId, customerId)
                .stream()
                .map(SiteResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public SiteResponse get(Long userId, String id) {
        Site site = siteRepository.findOwned(id, userId)
                .filter(s -> s.getDeletedAt() == null)
                .orElseThrow(() -> notFound("Site not found"));
        return SiteResponse.from(site);
    }

    /** Create-or-update by client generated id (idempotent, safe to retry). */
    @Transactional
    public SiteResponse upsert(Long userId, String id, SiteRequest request) {
        validateUuid(id);
        Instant now = Instant.now();

        // The parent customer must belong to this user and still be active.
        Customer customer = customerRepository.findByIdAndUserId(request.customerId(), userId)
                .filter(c -> c.getDeletedAt() == null)
                .orElseThrow(() -> notFound("Customer not found"));

        Site site = siteRepository.findById(id).orElse(null);

        if (site == null) {
            site = new Site();
            site.setId(id);
            site.setCreatedAt(now);
        } else if (!site.getCustomer().getUserId().equals(userId) || site.getDeletedAt() != null) {
            // Same 404 for "not yours" and "deleted", nothing is leaked.
            throw notFound("Site not found");
        }

        site.setCustomer(customer);
        site.setSiteName(request.siteName().trim());
        site.setAddress(request.address());
        site.setUpdatedAt(now);

        return SiteResponse.from(siteRepository.save(site));
    }

    /** Soft delete so other devices learn about it on their next sync. */
    @Transactional
    public void delete(Long userId, String id) {
        Site site = siteRepository.findOwned(id, userId)
                .orElseThrow(() -> notFound("Site not found"));

        if (site.getDeletedAt() != null) {
            return; // already deleted, idempotent
        }

        Instant now = Instant.now();
        site.setDeletedAt(now);
        site.setUpdatedAt(now);

        // TODO: once FieldNote exists, soft delete this site's notes here too.
    }

    private static void validateUuid(String id) {
        try {
            UUID.fromString(id);
        } catch (IllegalArgumentException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "id must be a valid UUID");
        }
    }

    private static ResponseStatusException notFound(String message) {
        return new ResponseStatusException(HttpStatus.NOT_FOUND, message);
    }
}