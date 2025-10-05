package com.ecommerce.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.http.ResponseEntity;
import org.springframework.beans.factory.annotation.Autowired;
import javax.sql.DataSource;
import java.sql.Connection;

@RestController
public class HealthController {
    
    @Autowired
    private DataSource dataSource;
    
    @GetMapping("/health")
    public ResponseEntity<String> health() {
        try {
            // Test database connection
            try (Connection connection = dataSource.getConnection()) {
                return ResponseEntity.ok("OK - Database connected");
            }
        } catch (Exception e) {
            return ResponseEntity.status(503).body("Database connection failed: " + e.getMessage());
        }
    }
    
    @GetMapping("/")
    public ResponseEntity<String> root() {
        return ResponseEntity.ok("Ecommerce API is running");
    }
    
    @GetMapping("/api/health")
    public ResponseEntity<String> apiHealth() {
        return ResponseEntity.ok("API is healthy");
    }
}