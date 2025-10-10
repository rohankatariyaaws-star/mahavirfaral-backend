package com.ecommerce.dto;


import lombok.Data;
import java.math.BigDecimal;
import java.util.List;

@Data
public class CreateOrderRequest {
    private Long userId;
    private Long addressId;
    private List<OrderItemRequest> items;
    private String paymentMethod;
    private String notes;
    private BigDecimal shippingCost;
    private BigDecimal totalAmount;
    private String deliveryDate;

    @Data
    public static class OrderItemRequest {
        private Long productId;
        private Integer quantity;
        private String size;
        private BigDecimal price;
    }
}