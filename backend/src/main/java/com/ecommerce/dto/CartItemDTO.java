package com.ecommerce.dto;

import com.ecommerce.model.CartItem;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CartItemDTO {
    private Long id;
    private Long userId;
    private ProductDTO product;
    private Integer quantity;
    private String size;
    private BigDecimal price;

    public static CartItemDTO fromCartItem(CartItem cartItem) {
        CartItemDTO dto = new CartItemDTO();
        dto.setId(cartItem.getId());
        dto.setUserId(cartItem.getUser().getId());
        dto.setProduct(ProductDTO.fromProduct(cartItem.getProduct()));
        dto.setQuantity(cartItem.getQuantity());
        dto.setSize(cartItem.getSize());
        dto.setPrice(cartItem.getPrice());
        return dto;
    }
}