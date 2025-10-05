package com.ecommerce.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.ToString;
import java.math.BigDecimal;

@Entity
@Table(name = "order_items")
@Data
@NoArgsConstructor
public class OrderItem {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "order_id")
    @ToString.Exclude
    private Order order;

    // Product details at time of order (frozen)
    private Long productId;
    private String productName;
    private String productDescription;
    private String productImageUrl;
    private String productSize;
    private String productCategory;
    
    // Price at time of order (frozen)
    private BigDecimal unitPrice;
    private Integer quantity;
    private BigDecimal totalPrice;

    public OrderItem(Product product, Integer quantity) {
        this.productId = product.getId();
        this.productName = product.getName();
        this.productDescription = product.getDescription();
        this.productImageUrl = product.getImageUrl();
        this.productSize = product.getSize();
        this.productCategory = product.getCategory();
        this.unitPrice = product.getPrice();
        this.quantity = quantity;
        this.totalPrice = product.getPrice().multiply(BigDecimal.valueOf(quantity)).setScale(2, java.math.RoundingMode.HALF_UP);
    }
}