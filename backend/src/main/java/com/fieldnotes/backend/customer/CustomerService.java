package com.fieldnotes.backend.customer;

import com.fieldnotes.backend.customer.dto.CustomerRequest;
import com.fieldnotes.backend.customer.dto.CustomerResponse;
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
public class CustomerService {

    private final CustomerRepository customerRepository;

    @Transactional(readOnly = true)
    public List<CustomerResponse> list(Long userId) {
        return customerRepository.findByUserIdAndDeletedAtIsNullOrderByNameAsc(userId)
                .stream()
                .map(CustomerResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public CustomerResponse get(Long userId, String id) {
        return CustomerResponse.from(findActiveOrThrow(userId, id));
    }

    /**
     * Create-or-update by client generated id. Calling it twice with the same
     * payload gives the same result, so a retried sync request is harmless.
     */
    @Transactional
    public CustomerResponse upsert(Long userId, String id, CustomerRequest request) {
        validateUuid(id);
        Instant now = Instant.now();

        // If the id exists but belongs to someone else, this lookup returns empty -> we would
        // try to insert and hit the primary key. Check ownership of the id explicitly.
        Customer customer = customerRepository.findById(id).orElse(null);

        if (customer == null) {
            customer = new Customer();
            customer.setId(id);
            customer.setUserId(userId);
            customer.setCreatedAt(now);
        } else if (!customer.getUserId().equals(userId) || customer.getDeletedAt() != null) {
            // Same 404 for "not yours" and "deleted" so we never reveal other users' data.
            throw notFound();
        }

        customer.setName(request.name().trim());
        customer.setContactInfo(request.contactInfo());
        customer.setUpdatedAt(now);

        return CustomerResponse.from(customerRepository.save(customer));
    }

    /**
     * Soft delete: keep the row and mark it, so other devices learn about the
     * deletion during their next sync.
     */
    @Transactional
    public void delete(Long userId, String id) {
        Customer customer = customerRepository.findByIdAndUserId(id, userId)
                .orElseThrow(CustomerService::notFound);

        // Deleting twice is fine (idempotent), nothing more to do.
        if (customer.getDeletedAt() != null) {
            return;
        }

        Instant now = Instant.now();
        customer.setDeletedAt(now);
        customer.setUpdatedAt(now);

        // TODO: once Site exists, soft delete this customer's sites (and their notes) here too.
    }

    private Customer findActiveOrThrow(Long userId, String id) {
        return customerRepository.findByIdAndUserId(id, userId)
                .filter(c -> c.getDeletedAt() == null)
                .orElseThrow(CustomerService::notFound);
    }

    private static void validateUuid(String id) {
        try {
            UUID.fromString(id);
        } catch (IllegalArgumentException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "id must be a valid UUID");
        }
    }

    private static ResponseStatusException notFound() {
        return new ResponseStatusException(HttpStatus.NOT_FOUND, "Customer not found");
    }
}