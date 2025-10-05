package com.ecommerce.service;

import com.ecommerce.dto.BatchCartRequest;
import com.ecommerce.model.CartItem;
import com.ecommerce.model.Product;
import com.ecommerce.model.User;
import com.ecommerce.repository.CartItemRepository;
import com.ecommerce.repository.ProductRepository;
import com.ecommerce.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;
import java.util.Optional;

@Service
public class CartService {
    
    @Autowired
    private CartItemRepository cartItemRepository;
    
    @Autowired
    private ProductRepository productRepository;
    
    @Autowired
    private UserRepository userRepository;
    
    public CartItem addToCart(User user, Long productId, Integer quantity, String size, java.math.BigDecimal price) {
        // Validate inputs
        if (user == null) {
            throw new RuntimeException("User is required");
        }
        if (productId == null || productId <= 0) {
            throw new RuntimeException("Valid product ID is required");
        }
        if (quantity == null || quantity <= 0) {
            throw new RuntimeException("Valid quantity is required");
        }
        
        Product product = productRepository.findById(productId)
            .orElseThrow(() -> new RuntimeException("Product not found"));
        Optional<CartItem> existingItem = cartItemRepository.findByUserAndProduct_IdAndSizeAndPrice(user, productId, size, price);
        if (existingItem.isPresent()) {
            CartItem item = existingItem.get();
            item.setQuantity(item.getQuantity() + quantity);
            return cartItemRepository.save(item);
        } else {
            CartItem newItem = new CartItem(user, product, quantity, size, price);
            return cartItemRepository.save(newItem);
        }
    }
    
    public List<CartItem> getCartItems(User user) {
        return cartItemRepository.findByUser(user);
    }
    
    public void removeFromCart(Long cartItemId) {
        cartItemRepository.deleteById(cartItemId);
    }
    
    @Transactional
    public void clearCart(User user) {
        cartItemRepository.deleteByUser(user);
    }

    @Transactional
    public List<CartItem> batchUpdate(Long userId, List<BatchCartRequest.CartOperation> operations) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("User not found"));
        
        for (BatchCartRequest.CartOperation op : operations) {
            switch (op.getAction()) {
                case "add":
                    addToCart(user, op.getProductId(), op.getQuantity(), op.getSize(), op.getPrice());
                    break;
                case "update":
                    Optional<CartItem> existingItem = cartItemRepository
                        .findByUserAndProduct_IdAndSizeAndPrice(user, op.getProductId(), op.getSize(), op.getPrice());
                    if (existingItem.isPresent()) {
                        updateQuantity(existingItem.get().getId(), op.getQuantity());
                    }
                    break;
                case "remove":
                    Optional<CartItem> itemToRemove = cartItemRepository
                        .findByUserAndProduct_IdAndSizeAndPrice(user, op.getProductId(), op.getSize(), op.getPrice());
                    if (itemToRemove.isPresent()) {
                        removeFromCart(itemToRemove.get().getId());
                    }
                    break;
            }
        }
        
        return getCartItems(user);
    }

    @Transactional
    public CartItem updateQuantity(Long cartItemId, Integer quantity) {
        if (cartItemId == null || cartItemId <= 0) {
            throw new RuntimeException("Valid cart item ID is required");
        }
        if (quantity == null || quantity <= 0) {
            throw new RuntimeException("Valid quantity is required");
        }
        
        CartItem item = cartItemRepository.findById(cartItemId)
            .orElseThrow(() -> new RuntimeException("Cart item not found"));
        item.setQuantity(quantity);
        return cartItemRepository.save(item);
    }
}