package com.ecommerce.dto;

import com.ecommerce.model.Wishlist;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class WishlistDTO {
    private Long id;
    private Long userId;
    private ProductDTO product;
    private LocalDateTime addedAt;

    public static WishlistDTO fromWishlist(Wishlist wishlist) {
        WishlistDTO dto = new WishlistDTO();
        dto.setId(wishlist.getId());
        dto.setUserId(wishlist.getUser().getId());
        dto.setProduct(ProductDTO.fromProduct(wishlist.getProduct()));
        dto.setAddedAt(wishlist.getAddedAt());
        return dto;
    }
}