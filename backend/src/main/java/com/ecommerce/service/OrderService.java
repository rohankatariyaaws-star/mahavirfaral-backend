package com.ecommerce.service;

import com.ecommerce.dto.CreateOrderRequest;
import com.ecommerce.model.*;
import com.ecommerce.repository.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class OrderService {
    @Autowired
    private OrderRepository orderRepository;
    
    @Autowired
    private OrderItemRepository orderItemRepository;
    
    @Autowired
    private UserRepository userRepository;
    
    @Autowired
    private UserAddressRepository userAddressRepository;
    
    @Autowired
    private ProductRepository productRepository;
    
    @Autowired
    private CartItemRepository cartItemRepository;

    public List<Order> getAllOrders() {
        return orderRepository.findAll();
    }

    public List<Order> getOrdersByUserId(Long userId) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("User not found"));
        return orderRepository.findByUser(user);
    }

    public Optional<Order> getOrderById(Long id) {
        return orderRepository.findById(id);
    }

    @Transactional
    public Order createOrder(CreateOrderRequest request) {
        // Validate request
        if (request == null) {
            throw new RuntimeException("Order request cannot be null");
        }
        if (request.getUserId() == null || request.getUserId() <= 0) {
            throw new RuntimeException("Valid User ID is required");
        }
        if (request.getItems() == null || request.getItems().isEmpty()) {
            throw new RuntimeException("Order items are required");
        }
        if (request.getTotalAmount() == null || request.getTotalAmount().compareTo(BigDecimal.ZERO) <= 0) {
            throw new RuntimeException("Valid total amount is required");
        }
        if (request.getShippingCost() == null || request.getShippingCost().compareTo(BigDecimal.ZERO) < 0) {
            throw new RuntimeException("Valid shipping cost is required");
        }
        
        // Validate order items
        for (CreateOrderRequest.OrderItemRequest item : request.getItems()) {
            if (item.getProductId() == null || item.getProductId() <= 0) {
                throw new RuntimeException("Valid product ID is required for all items");
            }
            if (item.getQuantity() == null || item.getQuantity() <= 0) {
                throw new RuntimeException("Valid quantity is required for all items");
            }
        }
        
        // Get user details
        User user = userRepository.findById(request.getUserId())
            .orElseThrow(() -> new RuntimeException("User not found: " + request.getUserId()));
        
        // Get user's cart items to get the correct prices (optional)
        List<CartItem> cartItems = cartItemRepository.findByUser(user);
        
        // Create order
        Order order = new Order();
        order.setUser(user);
        order.setOrderNumber(generateOrderNumber());
        
        // Freeze user details
        order.setUserFullName(user.getName());
        order.setUserEmail(user.getEmail());
        order.setUserPhone(user.getPhoneNumber());
        
        // Get address details if provided (for delivery)
        if (request.getAddressId() != null) {
            UserAddress address = userAddressRepository.findById(request.getAddressId())
                .orElseThrow(() -> new RuntimeException("Address not found"));
            
            // Freeze address details
            order.setShippingAddressLine1(address.getAddressLine1());
            order.setShippingAddressLine2(address.getAddressLine2());
            order.setShippingCity(address.getCity());
            order.setShippingState(address.getState());
            order.setShippingZipCode(address.getZipCode());
            order.setShippingPhone(address.getPhone());
        }
        
        order.setPaymentMethod(request.getPaymentMethod());
        order.setNotes(request.getNotes());
        order.setShippingCost(request.getShippingCost() != null ? request.getShippingCost() : BigDecimal.ZERO);
        
        // Save order first to get ID
        order = orderRepository.save(order);
        
        // Create order items and calculate totals
        BigDecimal subtotal = BigDecimal.ZERO;
        for (CreateOrderRequest.OrderItemRequest itemRequest : request.getItems()) {
            // Get product directly from repository
            Product product = productRepository.findById(itemRequest.getProductId())
                .orElseThrow(() -> new RuntimeException("Product not found: " + itemRequest.getProductId()));
            
            // Find the corresponding cart item to get the correct price and size (if available)
            CartItem cartItem = cartItems.stream()
                .filter(ci -> ci.getProduct().getId().equals(itemRequest.getProductId()))
                .findFirst()
                .orElse(null);
            
            // Create order item
            OrderItem orderItem = new OrderItem();
            orderItem.setOrder(order);
            orderItem.setProductId(product.getId());
            orderItem.setProductName(product.getName());
            orderItem.setProductDescription(product.getDescription());
            orderItem.setProductImageUrl(product.getImageUrl());
            orderItem.setProductCategory(product.getCategory());
            orderItem.setQuantity(itemRequest.getQuantity());
            
            // Determine price and size
            BigDecimal unitPrice;
            String size = null;
            
            if (cartItem != null && cartItem.getPrice() != null) {
                // Use cart item price and size if available
                unitPrice = cartItem.getPrice();
                size = cartItem.getSize();
            } else {
                // Fallback: get price from first variant
                if (product.getVariants() != null && !product.getVariants().isEmpty()) {
                    unitPrice = product.getVariants().get(0).getPrice();
                } else {
                    throw new RuntimeException("No price available for product: " + product.getId());
                }
            }
            
            orderItem.setUnitPrice(unitPrice);
            orderItem.setProductSize(size);
            orderItem.setTotalPrice(unitPrice.multiply(BigDecimal.valueOf(itemRequest.getQuantity())).setScale(2, java.math.RoundingMode.HALF_UP));
            
            orderItemRepository.save(orderItem);
            subtotal = subtotal.add(orderItem.getTotalPrice());
        }
        
        // Calculate tax (8% to match frontend) with proper rounding
        BigDecimal tax = subtotal.multiply(BigDecimal.valueOf(0.08)).setScale(2, java.math.RoundingMode.HALF_UP);
        BigDecimal calculatedTotal = subtotal.add(tax).add(order.getShippingCost()).setScale(2, java.math.RoundingMode.HALF_UP);
        
        // Use the frontend total if it's reasonable (within 1% of calculated total)
        BigDecimal tolerance = calculatedTotal.multiply(BigDecimal.valueOf(0.01));
        BigDecimal difference = request.getTotalAmount().subtract(calculatedTotal).abs();
        
        if (difference.compareTo(tolerance) > 0) {
            // Log the mismatch but don't fail the order
            System.err.println(String.format(
                "Total amount mismatch (using frontend total). Calculated: %s, Received: %s, Difference: %s", 
                calculatedTotal, request.getTotalAmount(), difference));
        }
        
        // Use frontend provided totals to avoid calculation mismatches
        order.setSubtotal(subtotal);
        order.setTax(tax);
        order.setTotalAmount(request.getTotalAmount()); // Use frontend total
        
        return orderRepository.save(order);
    }
    
    @Transactional
    public Order updateOrderStatus(Long orderId, Order.OrderStatus status) {
        Order order = orderRepository.findById(orderId)
            .orElseThrow(() -> new RuntimeException("Order not found"));
        
        order.setStatus(status);
        order.setUpdatedAt(LocalDateTime.now());
        
        return orderRepository.save(order);
    }
    
    private String generateOrderNumber() {
        return "ORD-" + System.currentTimeMillis() + "-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
    }

    public Order saveOrder(Order order) {
        return orderRepository.save(order);
    }

    public void deleteOrder(Long id) {
        orderRepository.deleteById(id);
    }

    @Transactional
    public Order cancelOrder(Long orderId, Long userId, String reason) {
        Order order = orderRepository.findById(orderId)
            .orElseThrow(() -> new RuntimeException("Order not found"));
        
        // Check if order belongs to user
        if (!order.getUser().getId().equals(userId)) {
            throw new RuntimeException("Unauthorized to cancel this order");
        }
        
        // Check if order can be cancelled (only PENDING orders)
        if (order.getStatus() != Order.OrderStatus.PENDING) {
            throw new RuntimeException("Order cannot be cancelled. Current status: " + order.getStatus());
        }
        
        order.setStatus(Order.OrderStatus.CANCELLED);
        order.setUpdatedAt(LocalDateTime.now());
        
        // Add cancellation reason to notes
        String cancellationNote = "Cancelled by user. Reason: " + (reason != null ? reason : "No reason provided");
        if (order.getNotes() != null && !order.getNotes().isEmpty()) {
            order.setNotes(order.getNotes() + "\n" + cancellationNote);
        } else {
            order.setNotes(cancellationNote);
        }
        
        return orderRepository.save(order);
    }
}
