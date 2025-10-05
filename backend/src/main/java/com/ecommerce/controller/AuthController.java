package com.ecommerce.controller;

import com.ecommerce.config.JwtUtils;
import com.ecommerce.dto.JwtResponse;
import com.ecommerce.dto.LoginRequest;
import com.ecommerce.dto.PhoneEmailResponse;
import com.ecommerce.dto.SignupRequest;
import com.ecommerce.model.User;
import com.ecommerce.service.UserService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.util.StringUtils;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.*;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;

import java.util.Collections;

@RestController
@RequestMapping("/api/auth")
@Slf4j
public class AuthController {

    @Autowired
    private UserService userService;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtUtils jwtUtils;

    @Autowired
    private RestTemplate restTemplate;

    @Autowired
    private ObjectMapper objectMapper;

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest loginRequest) {
        User user = userService.findByPhoneNumber(loginRequest.getUsername())
                .orElse(null);

        if (user != null && passwordEncoder.matches(loginRequest.getPassword(), user.getPassword())) {
            String jwt = jwtUtils.generateJwtToken(user);
            return ResponseEntity.ok(new JwtResponse(jwt, user.getId(), user.getName(), user.getPhoneNumber(), user.getEmail(), user.getRole()));
        }

        return ResponseEntity.badRequest().body("Invalid credentials");
    }

    @PostMapping("/signup")
    public ResponseEntity<?> signup(@RequestBody SignupRequest signupRequest) {
        if (StringUtils.hasText(signupRequest.getPhoneEmailUrl())) {
            // Handle Phone Email verification signup
            try {
                HttpHeaders headers = new HttpHeaders();
                headers.setAccept(Collections.singletonList(MediaType.APPLICATION_JSON));
                HttpEntity<Void> entity = new HttpEntity<>(headers);

                ResponseEntity<String> response = restTemplate.exchange(
                        signupRequest.getPhoneEmailUrl(),
                        HttpMethod.GET,
                        entity,
                        String.class
                );

                if (response.getStatusCode() == HttpStatus.OK) {
                    PhoneEmailResponse phoneEmailResponse = objectMapper.readValue(response.getBody(), PhoneEmailResponse.class);
                    
                    // Verify phone numbers match
                    if (!phoneEmailResponse.getUserPhoneNumber().equals(signupRequest.getPhoneNumber())) {
                        return ResponseEntity.badRequest().body("Verified number doesn't match.");
                    }
                    
                    // Check if verified phone number already exists
                    if (userService.existsByPhoneNumber(phoneEmailResponse.getUserPhoneNumber())) {
                        return ResponseEntity.badRequest().body("Number already registered. Please log in.");
                    }
                    
                    // Create user after successful verification
                    User user = new User(signupRequest.getName(), phoneEmailResponse.getUserPhoneNumber(),
                            signupRequest.getEmail(), signupRequest.getPassword());
                    User savedUser = userService.createUser(user);
                    
                    String jwt = jwtUtils.generateJwtToken(savedUser);
                    return ResponseEntity.ok(new JwtResponse(jwt, savedUser.getId(), savedUser.getName(), savedUser.getPhoneNumber(), savedUser.getEmail(), savedUser.getRole()));
                } else {
                    return ResponseEntity.badRequest().body("Verification failed");
                }
            } catch (Exception e) {
                log.debug("Error fetching JSON: " + e.getMessage());
                return ResponseEntity.badRequest().body("Verification failed");
            }
        } else {
            // Initial check - no database insertion
            if (userService.existsByPhoneNumber(signupRequest.getPhoneNumber())) {
                return ResponseEntity.badRequest().body("Number already registered. Please log in.");
            }
            
            // Return success without database insertion
            return ResponseEntity.ok("PROCEED_WITH_VERIFICATION");
        }
    }

    @PostMapping("/test")
    public ResponseEntity<?> test() {
        return ResponseEntity.ok("Test endpoint working");
    }

    @PostMapping("/create-admin")
    public ResponseEntity<?> createAdmin() {
        if (userService.existsByPhoneNumber("+1234567890")) {
            userService.findByPhoneNumber("+1234567890").ifPresent(user -> userService.deleteUser(user.getId()));
        }

        User admin = new User("Administrator", "+1234567890", "admin@example.com", "admin123");
        admin.setRole(User.Role.ADMIN);
        userService.createUser(admin);

        return ResponseEntity.ok("Admin user created with password: admin123");
    }

    @PostMapping("/change-password")
    public ResponseEntity<?> changePassword(@RequestBody ChangePasswordRequest request) {
        try {
            User user = userService.findByPhoneNumber(request.getPhoneNumber())
                .orElseThrow(() -> new RuntimeException("User not found"));
            
            if (!passwordEncoder.matches(request.getCurrentPassword(), user.getPassword())) {
                return ResponseEntity.badRequest().body("Current password is incorrect");
            }
            
            user.setPassword(passwordEncoder.encode(request.getNewPassword()));
            userService.saveUser(user);
            
            return ResponseEntity.ok("Password changed successfully");
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Failed to change password");
        }
    }

    @PostMapping("/verify-reset")
    public ResponseEntity<?> verifyReset(@RequestBody VerifyResetRequest request) {
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setAccept(Collections.singletonList(MediaType.APPLICATION_JSON));
            HttpEntity<Void> entity = new HttpEntity<>(headers);

            ResponseEntity<String> response = restTemplate.exchange(
                    request.getPhoneEmailUrl(),
                    HttpMethod.GET,
                    entity,
                    String.class
            );

            if (response.getStatusCode() == HttpStatus.OK) {
                PhoneEmailResponse phoneEmailResponse = objectMapper.readValue(response.getBody(), PhoneEmailResponse.class);
                
                // Verify phone numbers match
                if (!phoneEmailResponse.getUserPhoneNumber().equals(request.getPhoneNumber())) {
                    return ResponseEntity.badRequest().body("Verified number doesn't match.");
                }
                
                // Check if user exists for password reset
                if (!userService.existsByPhoneNumber(phoneEmailResponse.getUserPhoneNumber())) {
                    return ResponseEntity.badRequest().body("Phone number not registered");
                }
                
                return ResponseEntity.ok("Verification successful");
            } else {
                return ResponseEntity.badRequest().body("Verification failed");
            }
        } catch (Exception e) {
            log.debug("Error fetching JSON: " + e.getMessage());
            return ResponseEntity.badRequest().body("Verification failed");
        }
    }

    @PostMapping("/reset-password")
    public ResponseEntity<?> resetPassword(@RequestBody ResetPasswordRequest request) {
        if (StringUtils.hasText(request.getNewPassword())) {
            // Direct password reset with new password
            try {
                User user = userService.findByPhoneNumber(request.getPhoneNumber())
                    .orElseThrow(() -> new RuntimeException("User not found"));
                
                user.setPassword(passwordEncoder.encode(request.getNewPassword()));
                userService.saveUser(user);
                
                return ResponseEntity.ok("Password reset successfully");
            } catch (Exception e) {
                return ResponseEntity.badRequest().body("Failed to reset password");
            }
        } else {
            // Initial check - verify user exists
            if (!userService.existsByPhoneNumber(request.getPhoneNumber())) {
                return ResponseEntity.badRequest().body("Phone number not registered");
            }
            
            return ResponseEntity.ok("PROCEED_WITH_VERIFICATION");
        }
    }

    public static class ChangePasswordRequest {
        private String phoneNumber;
        private String currentPassword;
        private String newPassword;
        
        public String getPhoneNumber() { return phoneNumber; }
        public void setPhoneNumber(String phoneNumber) { this.phoneNumber = phoneNumber; }
        public String getCurrentPassword() { return currentPassword; }
        public void setCurrentPassword(String currentPassword) { this.currentPassword = currentPassword; }
        public String getNewPassword() { return newPassword; }
        public void setNewPassword(String newPassword) { this.newPassword = newPassword; }
    }

    public static class VerifyResetRequest {
        private String phoneNumber;
        private String phoneEmailUrl;
        
        public String getPhoneNumber() { return phoneNumber; }
        public void setPhoneNumber(String phoneNumber) { this.phoneNumber = phoneNumber; }
        public String getPhoneEmailUrl() { return phoneEmailUrl; }
        public void setPhoneEmailUrl(String phoneEmailUrl) { this.phoneEmailUrl = phoneEmailUrl; }
    }

    public static class ResetPasswordRequest {
        private String phoneNumber;
        private String newPassword;
        
        public String getPhoneNumber() { return phoneNumber; }
        public void setPhoneNumber(String phoneNumber) { this.phoneNumber = phoneNumber; }
        public String getNewPassword() { return newPassword; }
        public void setNewPassword(String newPassword) { this.newPassword = newPassword; }
    }
}
