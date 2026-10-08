package com.fieldnotes.backend.customer;

import com.fieldnotes.backend.customer.dto.CustomerRequest;
import com.fieldnotes.backend.customer.dto.CustomerResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/customers")
@RequiredArgsConstructor
public class CustomerController {

    private final CustomerService customerService;

    // The principal is the user id that JwtAuthFilter put into the security context.
    @GetMapping
    public List<CustomerResponse> list(@AuthenticationPrincipal Long userId) {
        return customerService.list(userId);
    }

    @GetMapping("/{id}")
    public CustomerResponse get(@AuthenticationPrincipal Long userId, @PathVariable String id) {
        return customerService.get(userId, id);
    }

    @PutMapping("/{id}")
    public CustomerResponse upsert(@AuthenticationPrincipal Long userId,
                                   @PathVariable String id,
                                   @Valid @RequestBody CustomerRequest request) {
        return customerService.upsert(userId, id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal Long userId, @PathVariable String id) {
        customerService.delete(userId, id);
    }
}