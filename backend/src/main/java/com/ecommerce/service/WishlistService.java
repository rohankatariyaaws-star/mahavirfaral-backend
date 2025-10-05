package com.ecommerce.service;

import com.ecommerce.dto.WishlistDTO;
import com.ecommerce.model.Product;
import com.ecommerce.model.User;
import com.ecommerce.model.Wishlist;
import com.ecommerce.repository.ProductRepository;
import com.ecommerce.repository.UserRepository;
import com.ecommerce.repository.WishlistRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class WishlistService {
    @Autowired
    private WishlistRepository wishlistRepository;
    
    @Autowired
    private ProductRepository productRepository;
    
    @Autowired
    private UserRepository userRepository;

    public List<WishlistDTO> getWishlistByUserId(Long userId) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("User not found"));
        return wishlistRepository.findByUser(user).stream()
            .map(WishlistDTO::fromWishlist)
            .collect(Collectors.toList());
    }

    @Transactional
    public WishlistDTO addToWishlist(Long userId, Long productId) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("User not found"));
            
        // Check if already exists
        if (wishlistRepository.findByUserAndProduct_Id(user, productId).isPresent()) {
            throw new RuntimeException("Product already in wishlist");
        }
        
        Product product = productRepository.findById(productId)
            .orElseThrow(() -> new RuntimeException("Product not found"));
        
        Wishlist wishlist = new Wishlist();
        wishlist.setUser(user);
        wishlist.setProduct(product);
        Wishlist saved = wishlistRepository.save(wishlist);
        return WishlistDTO.fromWishlist(saved);
    }

    @Transactional
    public void removeFromWishlist(Long userId, Long productId) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("User not found"));
        wishlistRepository.deleteByUserAndProduct_Id(user, productId);
    }
}