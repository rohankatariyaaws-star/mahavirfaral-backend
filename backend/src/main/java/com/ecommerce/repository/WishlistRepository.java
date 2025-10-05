package com.ecommerce.repository;

import com.ecommerce.model.User;
import com.ecommerce.model.Wishlist;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface WishlistRepository extends JpaRepository<Wishlist, Long> {
    List<Wishlist> findByUser(User user);
    Optional<Wishlist> findByUserAndProduct_Id(User user, Long productId);
    void deleteByUserAndProduct_Id(User user, Long productId);
}