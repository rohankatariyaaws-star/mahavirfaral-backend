package com.ecommerce.dto;

import com.ecommerce.model.Product;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.math.BigDecimal;
import java.util.List;
import java.util.stream.Collectors;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ProductDTO {
    private Long id;
    private String name;
    private String description;
    private String imageUrl;
    private String category;
    private List<ProductVariantDTO> sizes;
    
    // For backward compatibility
    private BigDecimal price;
    private Integer quantity;
    private String size;
    
    public static ProductDTO fromProduct(Product product) {
        ProductDTO dto = new ProductDTO();
        dto.setId(product.getId());
        dto.setName(product.getName());
        dto.setDescription(product.getDescription());
        dto.setImageUrl(product.getImageUrl());
        dto.setCategory(product.getCategory());
        // Product no longer has direct price/quantity/size - set to null
        dto.setPrice(null);
        dto.setQuantity(null);
        dto.setSize(null);
        
        if (product.getVariants() != null) {
            dto.setSizes(product.getVariants().stream()
                .map(ProductVariantDTO::fromProductVariant)
                .collect(Collectors.toList()));
        }
        
        return dto;
    }
}