package com.ecommerce.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.util.List;

@Data
public class BatchCartRequest {
    private List<CartOperation> operations;
    
    @Data
    public static class CartOperation {
        private String action; // "add", "update", "remove"
        private Long productId;
        private Integer quantity;
        private String size;
        private BigDecimal price;
    }
}