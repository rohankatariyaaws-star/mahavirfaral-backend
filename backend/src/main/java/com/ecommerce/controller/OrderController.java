package com.ecommerce.controller;

import com.ecommerce.dto.CreateOrderRequest;
import com.ecommerce.dto.OrderResponse;
import com.ecommerce.model.Order;
import com.ecommerce.model.User;
import com.ecommerce.service.OrderService;
import com.ecommerce.util.JWTTokenDetails;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;

import org.springframework.web.bind.annotation.*;


import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
@PreAuthorize("hasRole('USER') or hasRole('ADMIN') or hasRole('SUPERVISOR')")
public class OrderController {
    private final OrderService orderService;
    private final JWTTokenDetails jwtTokenDetails;

    @GetMapping
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPERVISOR')")
    public ResponseEntity<List<OrderResponse>> getAllOrders() {
        List<OrderResponse> orders = orderService.getAllOrders().stream()
            .map(OrderResponse::fromOrder)
            .collect(Collectors.toList());
        return ResponseEntity.ok(orders);
    }

    @GetMapping("/my")
    public ResponseEntity<List<OrderResponse>> getMyOrders() {
        Long userId = jwtTokenDetails.getUserId();
        List<OrderResponse> orders = orderService.getOrdersByUserId(userId).stream()
            .map(OrderResponse::fromOrder)
            .collect(Collectors.toList());
        return ResponseEntity.ok(orders);
    }

    @GetMapping("/user")
    public ResponseEntity<List<OrderResponse>> getOrdersByUserId() {
        List<OrderResponse> orders = orderService.getOrdersByUserId(jwtTokenDetails.getUserId()).stream()
            .map(OrderResponse::fromOrder)
            .collect(Collectors.toList());
        return ResponseEntity.ok(orders);
    }

    @GetMapping("/{id}")
    public ResponseEntity<OrderResponse> getOrderById(@PathVariable Long id) {
        return orderService.getOrderById(id)
            .map(order -> ResponseEntity.ok(OrderResponse.fromOrder(order)))
            .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<OrderResponse> createOrder(@RequestBody CreateOrderRequest request) {
        Order order = orderService.createOrder(request);
        return ResponseEntity.ok(OrderResponse.fromOrder(order));
    }

    @PostMapping("/create")
    public ResponseEntity<OrderResponse> createOrderAlternate(@RequestBody CreateOrderRequest request) {
        Order order = orderService.createOrder(request);
        return ResponseEntity.ok(OrderResponse.fromOrder(order));
    }

    @PutMapping("/{id}/status")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPERVISOR')")
    public ResponseEntity<OrderResponse> updateOrderStatus(@PathVariable Long id, 
            @RequestBody StatusUpdateRequest request) {
        try {
            Order.OrderStatus status = Order.OrderStatus.valueOf(request.getStatus());
            Order order = orderService.updateOrderStatus(id, status);
            return ResponseEntity.ok(OrderResponse.fromOrder(order));
        } catch (RuntimeException e) {
            return ResponseEntity.notFound().build();
        }
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Void> deleteOrder(@PathVariable Long id) {
        orderService.deleteOrder(id);
        return ResponseEntity.noContent().build();
    }

    @PutMapping("/{id}/cancel")
    public ResponseEntity<OrderResponse> cancelOrder(@PathVariable Long id, 
            @RequestBody CancelOrderRequest request) {
        try {
            Long userId = jwtTokenDetails.getUserId();
            Order order = orderService.cancelOrder(id, userId, request.getReason());
            return ResponseEntity.ok(OrderResponse.fromOrder(order));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().build();
        }
    }

    @Data
    public static class StatusUpdateRequest {
        private String status;
    }

    @Data
    public static class CancelOrderRequest {
        private String reason;
    }
}
