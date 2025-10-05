
package com.ecommerce.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import lombok.ToString;
import java.math.BigDecimal;

@Entity
@Table(name = "product_variants")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ProductVariant {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "product_id", nullable = false)
    @ToString.Exclude
    private Product product;
    
    @Column(nullable = false)
    private String size;
    
    @Column(nullable = false)
    private BigDecimal price;
    
    
    @Column(nullable = false)
    private Integer quantity;
    
    public ProductVariant(Product product, String size, BigDecimal price, Integer quantity) {
        this.product = product;
        this.size = size;
        this.price = price;
        this.quantity = quantity;
    }
}