package com.ecommerce.controller;

import com.ecommerce.dto.BatchCartRequest;
import com.ecommerce.dto.CartItemDTO;
import com.ecommerce.model.CartItem;
import com.ecommerce.model.User;
import com.ecommerce.service.CartService;
import com.ecommerce.service.UserService;
import com.ecommerce.util.JWTTokenDetails;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;

import org.springframework.web.bind.annotation.*;


import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/cart")
@RequiredArgsConstructor
@PreAuthorize("hasRole('USER') or hasRole('ADMIN') or hasRole('SUPERVISOR')")
public class CartController {
    
    private final CartService cartService;
    private final UserService userService;
    private final JWTTokenDetails jwtTokenDetails;
    
    @PostMapping("/add")
    public ResponseEntity<CartItemDTO> addToCart(@RequestBody AddToCartRequest request) {
        Long userId = jwtTokenDetails.getUserId();
        User user = userService.findById(userId)
            .orElseThrow(() -> new RuntimeException("User not found"));

        CartItem cartItem = cartService.addToCart(user, request.getProductId(), 
            request.getQuantity(), request.getSize(), request.getPrice());
        return ResponseEntity.ok(CartItemDTO.fromCartItem(cartItem));
    }
    
    @GetMapping
    public ResponseEntity<List<CartItemDTO>> getCartItems() {
        Long userId = jwtTokenDetails.getUserId();
        User user = userService.findById(userId)
            .orElseThrow(() -> new RuntimeException("User not found"));
        
        List<CartItem> cartItems = cartService.getCartItems(user);
        List<CartItemDTO> cartItemDTOs = cartItems.stream()
            .map(CartItemDTO::fromCartItem)
            .collect(Collectors.toList());
        return ResponseEntity.ok(cartItemDTOs);
    }
    
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> removeFromCart(@PathVariable Long id) {
        cartService.removeFromCart(id);
        return ResponseEntity.noContent().build();
    }
    
    @DeleteMapping("/clear")
    public ResponseEntity<Void> clearCart() {
        Long userId = jwtTokenDetails.getUserId();
        User user = userService.findById(userId)
            .orElseThrow(() -> new RuntimeException("User not found"));
        cartService.clearCart(user);
        return ResponseEntity.noContent().build();
    }
    
    @PutMapping("/{id}")
    public ResponseEntity<CartItemDTO> updateQuantity(@PathVariable Long id, 
            @RequestBody UpdateQuantityRequest request) {
        CartItem updatedItem = cartService.updateQuantity(id, request.getQuantity());
        return ResponseEntity.ok(CartItemDTO.fromCartItem(updatedItem));
    }

    @PostMapping("/batch")
    public ResponseEntity<List<CartItemDTO>> batchUpdate(@RequestBody BatchCartRequest request) {
        Long userId = jwtTokenDetails.getUserId();
        List<CartItem> updatedItems = cartService.batchUpdate(userId, request.getOperations());
        List<CartItemDTO> cartItemDTOs = updatedItems.stream()
            .map(CartItemDTO::fromCartItem)
            .collect(Collectors.toList());
        return ResponseEntity.ok(cartItemDTOs);
    }
    
    @Data
    public static class AddToCartRequest {
        private Long productId;
        private Integer quantity;
        private String size;
        private BigDecimal price;
    }
    
    @Data
    public static class UpdateQuantityRequest {
        private Integer quantity;
    }
}