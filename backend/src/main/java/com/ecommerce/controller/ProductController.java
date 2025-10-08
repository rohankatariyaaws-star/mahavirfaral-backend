package com.ecommerce.controller;

import com.ecommerce.dto.ProductsWithCartResponse;
import com.ecommerce.model.Product;
import com.ecommerce.model.ProductVariant;
import com.ecommerce.dto.ProductDTO;
import com.ecommerce.dto.ProductVariantDTO;
import com.ecommerce.dto.CartItemDTO;
import com.ecommerce.service.ProductService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import java.util.ArrayList;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;

import org.springframework.web.bind.annotation.*;


import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/products")
@RequiredArgsConstructor
public class ProductController {

    private final ProductService productService;

    @GetMapping
    public List<ProductDTO> getAllProducts() {
        return productService.getAllProducts().stream()
            .map(ProductDTO::fromProduct)
            .collect(Collectors.toList());
    }

    @GetMapping("/available")
    public List<ProductDTO> getAvailableProducts() {
        return productService.getAvailableProducts().stream()
            .map(ProductDTO::fromProduct)
            .collect(Collectors.toList());
    }
    
    @GetMapping("/debug")
    public ResponseEntity<String> debugProducts() {
        List<Product> allProducts = productService.getAllProducts();
        List<Product> availableProducts = productService.getAvailableProducts();
        
        StringBuilder debug = new StringBuilder();
        debug.append("Total products: ").append(allProducts.size()).append("\n");
        debug.append("Available products: ").append(availableProducts.size()).append("\n");
        
        if (!allProducts.isEmpty()) {
            Product first = allProducts.get(0);
            debug.append("First product variants: ").append(first.getVariants() != null ? first.getVariants().size() : 0).append("\n");
            if (first.getVariants() != null && !first.getVariants().isEmpty()) {
                ProductVariant firstVariant = first.getVariants().get(0);
                debug.append("First variant quantity: ").append(firstVariant.getQuantity()).append("\n");
            }
        }
        
        return ResponseEntity.ok(debug.toString());
    }

    @GetMapping("/available/paged")
    public ResponseEntity<Page<ProductDTO>> getAvailableProductsPaged(Pageable pageable) {
        Page<Product> products = productService.getAvailableProductsPaged(pageable);
        Page<ProductDTO> productDTOs = products.map(ProductDTO::fromProduct);
        return ResponseEntity.ok(productDTOs);
    }

    @GetMapping("/with-cart")
    public ResponseEntity<ProductsWithCartResponse> getProductsWithCart() {
        List<ProductDTO> products = productService.getAvailableProducts().stream()
            .map(ProductDTO::fromProduct)
            .collect(Collectors.toList());
        
        // Get cart items if user is authenticated
        List<CartItemDTO> cartItems = new ArrayList<>();
        try {
            Authentication auth = SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && auth.isAuthenticated() && !"anonymousUser".equals(auth.getPrincipal())) {
                // User is authenticated, get cart items
                // This would need CartService injection
            }
        } catch (Exception e) {
            // User not authenticated, return empty cart
        }
        
        return ResponseEntity.ok(new ProductsWithCartResponse(products, cartItems));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ProductDTO> getProductById(@PathVariable Long id) {
        return productService.getProductById(id)
                .map(ProductDTO::fromProduct)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ProductDTO> createProduct(@RequestBody ProductDTO productDTO) {
        Product product = convertDTOToEntity(productDTO);
        Product savedProduct = productService.createProduct(product);
        return ResponseEntity.ok(ProductDTO.fromProduct(savedProduct));
    }

    private ProductDTO convertEntityToDTO(Product product) {
        ProductDTO dto = new ProductDTO();
        dto.setId(product.getId());
        dto.setName(product.getName());
        dto.setDescription(product.getDescription());
        dto.setImageUrl(product.getImageUrl());
        dto.setCategory(product.getCategory());
        if (product.getVariants() != null && !product.getVariants().isEmpty()) {
            List<ProductVariantDTO> variantDTOs = product.getVariants().stream()
                    .map(ProductVariantDTO::fromProductVariant)
                    .collect(Collectors.toList());
            dto.setSizes(variantDTOs);
        }
        return dto;
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ProductDTO> updateProduct(@PathVariable Long id, 
            @RequestBody ProductDTO productDTO) {
        try {
            Product productDetails = convertDTOToEntity(productDTO);
            Product updatedProduct = productService.updateProduct(id, productDetails);
            return ResponseEntity.ok(ProductDTO.fromProduct(updatedProduct));
        } catch (RuntimeException e) {
            return ResponseEntity.notFound().build();
        }
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Void> deleteProduct(@PathVariable Long id) {
        productService.deleteProduct(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/categories")
    public List<String> getAllCategories() {
        return productService.getAllCategories();
    }

    @PostMapping("/categories")
    public ResponseEntity<String> addCategory(@RequestBody String category) {
        productService.addCategory(category.replace("\"", ""));
        return ResponseEntity.ok("Category added successfully");
    }

    @DeleteMapping("/categories/{category}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<String> deleteCategory(@PathVariable String category) {
        productService.deleteCategory(category);
        return ResponseEntity.ok("Category deleted successfully");
    }

    private Product convertDTOToEntity(ProductDTO dto) {
        Product product = new Product();
        product.setId(dto.getId());
        product.setName(dto.getName());
        product.setDescription(dto.getDescription());
        product.setImageUrl(dto.getImageUrl());
        product.setCategory(dto.getCategory());

        // Handle variants
        if (dto.getSizes() != null && !dto.getSizes().isEmpty()) {
            List<ProductVariant> variants = dto.getSizes().stream()
                    .map(sizeDTO -> {
                        ProductVariant variant = new ProductVariant();
                        if (sizeDTO.getId() != null) {
                            variant.setId(sizeDTO.getId());
                        }
                        variant.setProduct(product);
                        variant.setSize(sizeDTO.getSize());
                        variant.setPrice(sizeDTO.getPrice());
                        variant.setQuantity(sizeDTO.getQuantity());
                        return variant;
                    })
                    .collect(Collectors.toList());
            product.setVariants(variants);
        }

        return product;
    }
}