package com.ecommerce.service;

import com.ecommerce.exception.BadRequestException;
import com.ecommerce.model.User;
import com.ecommerce.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
public class UserService extends BaseService<User, Long> {
    
    @Autowired
    private UserRepository userRepository;
    
    @Autowired
    private PasswordEncoder passwordEncoder;

    @Override
    protected JpaRepository<User, Long> getRepository() {
        return userRepository;
    }

    @Override
    protected String getEntityName() {
        return "User";
    }
    
    public User createUser(User user) {
        if (existsByPhoneNumber(user.getPhoneNumber())) {
            throw new BadRequestException("Phone number already exists");
        }
        user.setPassword(passwordEncoder.encode(user.getPassword()));
        return save(user);
    }
    
    public Optional<User> findByPhoneNumber(String phoneNumber) {
        return userRepository.findByPhoneNumber(phoneNumber);
    }
    
    public void deleteUser(Long id) {
        userRepository.deleteById(id);
    }

    public boolean existsByPhoneNumber(String phoneNumber) {
        return userRepository.existsByPhoneNumber(phoneNumber);
    }
    
    public boolean existsByEmail(String email) {
        return userRepository.existsByEmail(email);
    }
    
    public User updateUserRole(Long id, User.Role role) {
        User user = getById(id);
        user.setRole(role);
        return save(user);
    }

    public User updateProfile(Long id, User updatedUser) {
        User user = getById(id);
        user.setName(updatedUser.getName());
        user.setEmail(updatedUser.getEmail());
        return save(user);
    }

    public void changePassword(Long id, String oldPassword, String newPassword) {
        User user = getById(id);
        if (!passwordEncoder.matches(oldPassword, user.getPassword())) {
            throw new BadRequestException("Current password is incorrect");
        }
        user.setPassword(passwordEncoder.encode(newPassword));
        save(user);
    }

    public User saveUser(User user) {
        return save(user);
    }
}