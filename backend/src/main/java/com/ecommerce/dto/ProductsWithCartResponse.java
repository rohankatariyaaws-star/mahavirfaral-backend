package com.ecommerce.dto;

import lombok.Data;
import java.util.List;

@Data
public class ProductsWithCartResponse {
    private List<ProductDTO> products;
    private List<CartItemDTO> cartItems;
    private Integer cartCount;
    
    public ProductsWithCartResponse(List<ProductDTO> products, List<CartItemDTO> cartItems) {
        this.products = products;
        this.cartItems = cartItems;
        this.cartCount = cartItems.size();
    }
}