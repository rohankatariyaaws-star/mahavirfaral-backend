package com.ecommerce.repository;

import com.ecommerce.model.CartItem;
import com.ecommerce.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface CartItemRepository extends JpaRepository<CartItem, Long> {
    List<CartItem> findByUser(User user);
//    Optional<CartItem> findByUserAndProduct_IdAndSizeAndPrice(User user, Long productId, String size, java.math.BigDecimal price);


    @Query(
            value = "SELECT * FROM cart_items c " +
                    "WHERE c.user_id = :userId " +
                    "AND c.product_id = :productId " +
                    "AND c.size = :size " +
                    "AND c.price = :price",
            nativeQuery = true
    )
    Optional<CartItem> findByUserAndProduct_IdAndSizeAndPrice(
            @Param("userId") Long userId,
            @Param("productId") Long productId,
            @Param("size") String size,
            @Param("price") BigDecimal price
    );

    void deleteByUser(User user);
    
    @Modifying
    @Query("DELETE FROM CartItem c WHERE c.createdAt < :cutoffDate")
    int deleteByCreatedAtBefore(LocalDateTime cutoffDate);
}