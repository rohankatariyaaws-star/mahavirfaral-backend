package com.ecommerce.controller;

import com.ecommerce.dto.WishlistDTO;
import com.ecommerce.model.Wishlist;
import com.ecommerce.service.WishlistService;
import com.ecommerce.util.JWTTokenDetails;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;

import org.springframework.web.bind.annotation.*;


import java.util.List;

@RestController
@RequestMapping("/api/wishlist")
@RequiredArgsConstructor
@PreAuthorize("hasRole('USER') or hasRole('ADMIN') or hasRole('SUPERVISOR')")
public class WishlistController {
    
    private final WishlistService wishlistService;
    private final JWTTokenDetails jwtTokenDetails;

    @GetMapping
    public ResponseEntity<List<WishlistDTO>> getWishlist() {
        Long userId = jwtTokenDetails.getUserId();
        List<WishlistDTO> wishlist = wishlistService.getWishlistByUserId(userId);
        return ResponseEntity.ok(wishlist);
    }

    @PostMapping
    public ResponseEntity<WishlistDTO> addToWishlist(@RequestBody WishlistRequest request) {
        Long userId = jwtTokenDetails.getUserId();
        WishlistDTO wishlist = wishlistService.addToWishlist(userId, request.getProductId());
        return ResponseEntity.ok(wishlist);
    }

    @DeleteMapping("/{productId}")
    public ResponseEntity<Void> removeFromWishlist(@PathVariable Long productId) {
        Long userId = jwtTokenDetails.getUserId();
        wishlistService.removeFromWishlist(userId, productId);
        return ResponseEntity.noContent().build();
    }

    @Data
    public static class WishlistRequest {
        private Long productId;
    }
}