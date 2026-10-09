package com.fieldnotes.backend.sync;

import com.fieldnotes.backend.customer.Customer;
import com.fieldnotes.backend.customer.CustomerRepository;
import com.fieldnotes.backend.note.FieldNote;
import com.fieldnotes.backend.note.FieldNoteRepository;
import com.fieldnotes.backend.site.Site;
import com.fieldnotes.backend.site.SiteRepository;
import com.fieldnotes.backend.sync.dto.*;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validator;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.function.Supplier;

@Service
@RequiredArgsConstructor
public class SyncService {

    // serverTime is moved slightly into the past. A write that is still committing while we
    // read could otherwise fall between two pulls. Re-sending a few rows is harmless
    // because the client merges by id.
    private static final Duration PULL_OVERLAP = Duration.ofSeconds(2);

    private final CustomerRepository customerRepository;
    private final SiteRepository siteRepository;
    private final FieldNoteRepository noteRepository;
    private final Validator validator;

    // ---------------------------------------------------------------- PULL

    /** Everything of this user that changed after `since`, deleted rows included. */
    @Transactional(readOnly = true)
    public SyncPullResponse pull(Long userId, Instant since) {
        Instant serverTime = Instant.now().minus(PULL_OVERLAP);
        Instant from = (since == null) ? Instant.EPOCH : since;   // no `since` = full restore

        List<SyncCustomer> customers = customerRepository
                .findByUserIdAndUpdatedAtGreaterThan(userId, from)
                .stream().map(SyncCustomer::from).toList();

        List<SyncSite> sites = siteRepository.findChangedSince(userId, from)
                .stream().map(SyncSite::from).toList();

        List<SyncNote> notes = noteRepository.findChangedSince(userId, from)
                .stream().map(SyncNote::from).toList();

        return new SyncPullResponse(serverTime, customers, sites, notes);
    }

    // ---------------------------------------------------------------- PUSH

    /**
     * Applies client changes in FK order (customers -> sites -> notes).
     * Each record is handled on its own: one bad record never blocks the others.
     */
    @Transactional
    public SyncPushResponse push(Long userId, SyncPushRequest request) {
        List<SyncItemResult> results = new ArrayList<>();

        for (SyncCustomer c : orEmpty(request.customers())) {
            results.add(process("customer", c.id(), c, () -> pushCustomer(userId, c)));
        }
        for (SyncSite s : orEmpty(request.sites())) {
            results.add(process("site", s.id(), s, () -> pushSite(userId, s)));
        }
        for (SyncNote n : orEmpty(request.notes())) {
            results.add(process("note", n.id(), n, () -> pushNote(userId, n)));
        }
        return new SyncPushResponse(results);
    }

    private PushStatus pushCustomer(Long userId, SyncCustomer in) {
        Instant now = Instant.now();
        Customer customer = customerRepository.findById(in.id()).orElse(null);

        if (customer == null) {
            customer = new Customer();
            customer.setId(in.id());
            customer.setUserId(userId);
            customer.setCreatedAt(now);
        } else {
            // An id owned by someone else looks exactly like "not found".
            if (!customer.getUserId().equals(userId)) throw reject("Customer not found");
            if (isNotNewer(in.clientUpdatedAt(), customer.getClientUpdatedAt())) return PushStatus.SKIPPED;
        }

        customer.setName(in.name().trim());
        customer.setContactInfo(in.contactInfo());
        customer.setClientUpdatedAt(in.clientUpdatedAt());
        customer.setDeletedAt(in.deletedAt());
        customer.setUpdatedAt(now);
        customerRepository.save(customer);

        // Deleting a customer deletes everything below it.
        if (in.deletedAt() != null) {
            noteRepository.softDeleteByCustomer(customer.getId(), now);
            siteRepository.softDeleteByCustomer(customer.getId(), now);
        }
        return PushStatus.ACCEPTED;
    }

    private PushStatus pushSite(Long userId, SyncSite in) {
        Instant now = Instant.now();

        Customer parent = customerRepository.findByIdAndUserId(in.customerId(), userId)
                .orElseThrow(() -> reject("Customer not found"));
        // A live record cannot hang under a deleted parent; the next pull tells the client why.
        if (parent.getDeletedAt() != null && in.deletedAt() == null) {
            throw reject("Customer was deleted");
        }

        Site site = siteRepository.findById(in.id()).orElse(null);

        if (site == null) {
            site = new Site();
            site.setId(in.id());
            site.setCreatedAt(now);
        } else {
            if (!site.getCustomer().getUserId().equals(userId)) throw reject("Site not found");
            if (isNotNewer(in.clientUpdatedAt(), site.getClientUpdatedAt())) return PushStatus.SKIPPED;
        }

        site.setCustomer(parent);
        site.setSiteName(in.siteName().trim());
        site.setAddress(in.address());
        site.setClientUpdatedAt(in.clientUpdatedAt());
        site.setDeletedAt(in.deletedAt());
        site.setUpdatedAt(now);
        siteRepository.save(site);

        if (in.deletedAt() != null) {
            noteRepository.softDeleteBySite(site.getId(), now);
        }
        return PushStatus.ACCEPTED;
    }

    private PushStatus pushNote(Long userId, SyncNote in) {
        Instant now = Instant.now();

        // findOwned joins site -> customer and checks the user in the same query.
        Site parent = siteRepository.findOwned(in.siteId(), userId)
                .orElseThrow(() -> reject("Site not found"));
        boolean parentDeleted = parent.getDeletedAt() != null || parent.getCustomer().getDeletedAt() != null;
        if (parentDeleted && in.deletedAt() == null) {
            throw reject("Site was deleted");
        }

        FieldNote note = noteRepository.findById(in.id()).orElse(null);

        if (note == null) {
            note = new FieldNote();
            note.setId(in.id());
            note.setCreatedAt(now);
        } else {
            if (!note.getSite().getCustomer().getUserId().equals(userId)) throw reject("Note not found");
            if (isNotNewer(in.clientUpdatedAt(), note.getClientUpdatedAt())) return PushStatus.SKIPPED;
        }

        note.setSite(parent);
        note.setTitle(in.title().trim());
        note.setDescription(in.description());
        note.setLatitude(in.latitude());
        note.setLongitude(in.longitude());
        note.setNotedAt(in.notedAt());
        note.setStatus(in.status());
        // photoPath is intentionally untouched: only the photo endpoint writes it.
        note.setClientUpdatedAt(in.clientUpdatedAt());
        note.setDeletedAt(in.deletedAt());
        note.setUpdatedAt(now);
        noteRepository.save(note);

        return PushStatus.ACCEPTED;
    }

    // ------------------------------------------------------------- helpers

    /** Validates one record, runs the action, and turns failures into a per-record result. */
    private SyncItemResult process(String entity, String id, Object item, Supplier<PushStatus> action) {
        try {
            if (!isValidUuid(id)) {
                return new SyncItemResult(entity, id, PushStatus.REJECTED, "id must be a valid UUID");
            }
            Set<ConstraintViolation<Object>> violations = validator.validate(item);
            if (!violations.isEmpty()) {
                ConstraintViolation<Object> first = violations.iterator().next();
                String message = first.getPropertyPath() + " " + first.getMessage();
                return new SyncItemResult(entity, id, PushStatus.REJECTED, message);
            }
            return new SyncItemResult(entity, id, action.get(), null);
        } catch (ResponseStatusException e) {
            return new SyncItemResult(entity, id, PushStatus.REJECTED, e.getReason());
        }
    }

    // Last-write-wins. Equal timestamps count as "not newer", so a retried push is a no-op.
    private static boolean isNotNewer(Instant incoming, Instant existing) {
        return !incoming.isAfter(existing);
    }

    private static boolean isValidUuid(String id) {
        if (id == null) return false;
        try {
            UUID.fromString(id);
            return true;
        } catch (IllegalArgumentException e) {
            return false;
        }
    }

    private static ResponseStatusException reject(String message) {
        return new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY, message);
    }

    private static <T> List<T> orEmpty(List<T> list) {
        return list == null ? List.of() : list;
    }
}