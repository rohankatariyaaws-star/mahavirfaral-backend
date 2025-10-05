package com.ecommerce.repository;

import com.ecommerce.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;
import java.util.List;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByPhoneNumber(String phoneNumber);
    Optional<User> findByEmail(String email);
    List<User> findByRole(User.Role role);
    List<User> findAll();
    void deleteById(Long id);
    boolean existsByPhoneNumber(String phoneNumber);
    boolean existsByEmail(String email);
}