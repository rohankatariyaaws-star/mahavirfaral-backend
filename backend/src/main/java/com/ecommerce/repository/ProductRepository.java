package com.ecommerce.repository;

import com.ecommerce.model.Product;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface ProductRepository extends JpaRepository<Product, Long> {
    // Removed findByQuantityGreaterThan - quantity field no longer exists
    
    @Query("SELECT DISTINCT p.category FROM Product p WHERE p.category IS NOT NULL ORDER BY p.category")
    List<String> findDistinctCategories();
    
    List<Product> findByCategory(String category);
    
    @Query("SELECT DISTINCT p FROM Product p WHERE EXISTS (SELECT 1 FROM ProductVariant v WHERE v.product = p AND v.quantity > 0)")
    List<Product> findAvailableProducts();
    
    @Query("SELECT DISTINCT p FROM Product p WHERE EXISTS (SELECT 1 FROM ProductVariant v WHERE v.product = p AND v.quantity > 0)")
    Page<Product> findAvailableProductsPaged(Pageable pageable);
}