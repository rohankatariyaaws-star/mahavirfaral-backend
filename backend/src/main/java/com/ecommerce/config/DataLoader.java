package com.ecommerce.config;

import com.ecommerce.model.User;
import com.ecommerce.model.Product;
import com.ecommerce.repository.UserRepository;
import com.ecommerce.repository.ProductRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import java.math.BigDecimal;

@Component
public class DataLoader implements CommandLineRunner {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) throws Exception {
        // Create admin user if it doesn't exist
        if (userRepository.findByPhoneNumber("+1234567890").isEmpty()) {
            User admin = new User();
            admin.setName("Administrator");
            admin.setPassword(passwordEncoder.encode("admin123"));
            admin.setEmail("admin@ecommerce.com");
            admin.setPhoneNumber("+1234567890");
            admin.setRole(User.Role.ADMIN);
            userRepository.save(admin);
            System.out.println("Admin user created: +1234567890/admin123");
        }
        
        // Create sample products if none exist
        if (productRepository.count() == 0) {
            Product[] sampleProducts = {
                new Product("Organic Rice", "Premium quality organic basmati rice", "https://images.unsplash.com/photo-1586201375761-83865001e31c?w=400", "Food"),
                new Product("Fresh Milk", "Farm fresh whole milk", "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400", "Dairy"),
                new Product("Olive Oil", "Extra virgin olive oil", "https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=400", "Food"),
                new Product("Whole Wheat Bread", "Freshly baked whole wheat bread", "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400", "Bakery"),
                new Product("Green Tea", "Organic green tea bags", "https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=400", "Beverages")
            };
            
            for (Product product : sampleProducts) {
                productRepository.save(product);
            }
            System.out.println("Sample products created");
        }
    }
}