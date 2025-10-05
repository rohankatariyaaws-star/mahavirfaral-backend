package com.ecommerce.controller;

import com.ecommerce.dto.UserAddressDTO;
import com.ecommerce.model.User;
import com.ecommerce.model.UserAddress;
import com.ecommerce.service.UserAddressService;
import com.ecommerce.service.UserService;
import com.ecommerce.util.JWTTokenDetails;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;

import org.springframework.web.bind.annotation.*;


import java.util.List;

@RestController
@RequestMapping("/api/addresses")
@RequiredArgsConstructor
@PreAuthorize("hasRole('USER') or hasRole('ADMIN') or hasRole('SUPERVISOR')")
public class UserAddressController {
    private final UserAddressService userAddressService;
    private final UserService userService;
    private final JWTTokenDetails jwtTokenDetails;

    @GetMapping("/user")
    public ResponseEntity<List<UserAddressDTO>> getMyAddresses() {
        Long userId = jwtTokenDetails.getUserId();
        List<UserAddressDTO> addresses = userAddressService.getAddressesByUserId(userId);
        return ResponseEntity.ok(addresses);
    }

    @GetMapping("/user/{userId}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<List<UserAddressDTO>> getAddressesByUserId(@PathVariable Long userId) {
        List<UserAddressDTO> addresses = userAddressService.getAddressesByUserId(userId);
        return ResponseEntity.ok(addresses);
    }

    @GetMapping("/{id}")
    public ResponseEntity<UserAddressDTO> getAddressById(@PathVariable Long id) {
        return userAddressService.getAddressById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<UserAddressDTO> createAddress(@RequestBody UserAddress address) {
        Long userId = jwtTokenDetails.getUserId();
        User user = userService.findById(userId)
            .orElseThrow(() -> new RuntimeException("User not found"));
        address.setUser(user);
        UserAddressDTO savedAddress = userAddressService.saveAddress(address);
        return ResponseEntity.ok(savedAddress);
    }

    @PutMapping("/{id}")
    public ResponseEntity<UserAddressDTO> updateAddress(@PathVariable Long id, 
            @RequestBody UserAddress address) {
        if (userAddressService.getAddressById(id).isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        address.setId(id);
        Long userId = jwtTokenDetails.getUserId();
        User user = userService.findById(userId)
            .orElseThrow(() -> new RuntimeException("User not found"));
        address.setUser(user);
        return ResponseEntity.ok(userAddressService.saveAddress(address));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteAddress(@PathVariable Long id) {
        userAddressService.deleteAddress(id);
        return ResponseEntity.noContent().build();
    }
}
