package com.ecommerce.service;

import com.ecommerce.model.Product;
import com.ecommerce.model.ProductVariant;
import com.ecommerce.repository.ProductRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;
 
@Service
public class ProductService {
    
    @Autowired
    private ProductRepository productRepository;
    
    @CacheEvict(value = "products", allEntries = true)
    public Product createProduct(Product product) {
        // Handle variants if provided
        if (product.getVariants() != null && !product.getVariants().isEmpty()) {
            for (ProductVariant variant : product.getVariants()) {
                variant.setProduct(product);
            }
        }
        
        return productRepository.save(product);
    }
    
    public List<Product> getAllProducts() {
        return productRepository.findAll();
    }
    
    @Cacheable("products")
    public List<Product> getAvailableProducts() {
        return productRepository.findAvailableProducts();
    }

    public Page<Product> getAvailableProductsPaged(Pageable pageable) {
        return productRepository.findAvailableProductsPaged(pageable);
    }
    
    public Optional<Product> getProductById(Long id) {
        return productRepository.findById(id);
    }
    
    @CacheEvict(value = "products", allEntries = true)
    public Product updateProduct(Long id, Product productDetails) {
        Product product = productRepository.findById(id).orElseThrow();
        product.setName(productDetails.getName());
        product.setDescription(productDetails.getDescription());
        product.setImageUrl(productDetails.getImageUrl());
        product.setCategory(productDetails.getCategory());
        
        // Handle backward compatibility for single size/price/quantity
        if (productDetails.getPrice() != null && productDetails.getQuantity() != null) {
            product.setPrice(productDetails.getPrice());
            product.setQuantity(productDetails.getQuantity());
            product.setSize(productDetails.getSize());
        }
        
        // Handle multiple variants if provided
        if (productDetails.getVariants() != null && !productDetails.getVariants().isEmpty()) {
            // Clear existing variants
            product.getVariants().clear();
            
            // Add new variants
            for (ProductVariant variant : productDetails.getVariants()) {
                variant.setProduct(product);
                product.getVariants().add(variant);
            }
        }
        
        return productRepository.save(product);
    }
    
    @CacheEvict(value = "products", allEntries = true)
    public void deleteProduct(Long id) {
        productRepository.deleteById(id);
    }
    
    public Product updateQuantity(Long id, Integer quantity) {
        Product product = productRepository.findById(id).orElseThrow();
        product.setQuantity(quantity);
        return productRepository.save(product);
    }
    
    public List<String> getAllCategories() {
        return productRepository.findDistinctCategories();
    }
    
    public void addCategory(String category) {
        // Since we don't have a separate Category table, we'll just validate the category exists
        // when products are created. Categories are dynamically created when products use them.
        // This method can be used for validation or future category management.
    }
    
    public void deleteCategory(String category) {
        // Update all products with this category to null or default category
        List<Product> productsWithCategory = productRepository.findByCategory(category);
        for (Product product : productsWithCategory) {
            product.setCategory("General");
            productRepository.save(product);
        }
    }
}