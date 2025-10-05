package com.ecommerce.dto;

import com.ecommerce.model.ProductVariant;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ProductVariantDTO {
    private Long id;
    private String size;
    private BigDecimal price;
    private Integer quantity;

    public static ProductVariantDTO fromProductVariant(ProductVariant variant) {
        ProductVariantDTO dto = new ProductVariantDTO();
        dto.setId(variant.getId());
        dto.setSize(variant.getSize());
        dto.setPrice(variant.getPrice());
        dto.setQuantity(variant.getQuantity());
        return dto;
    }
}