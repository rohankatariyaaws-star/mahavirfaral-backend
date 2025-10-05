package com.ecommerce.controller;

import com.ecommerce.dto.UserDTO;
import com.ecommerce.model.User;
import com.ecommerce.service.UserService;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;

import org.springframework.web.bind.annotation.*;


import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminController {
    
    private final UserService userService;
    
    @GetMapping("/users")
    public ResponseEntity<List<UserDTO>> getAllUsers() {
        List<UserDTO> users = userService.findAll().stream()
            .map(UserDTO::fromUser)
            .collect(Collectors.toList());
        return ResponseEntity.ok(users);
    }
    
    @DeleteMapping("/users/{id}")
    public ResponseEntity<Void> deleteUser(@PathVariable Long id) {
        userService.deleteUser(id);
        return ResponseEntity.noContent().build();
    }
    
    @PutMapping("/users/{id}/role")
    public ResponseEntity<UserDTO> updateUserRole(@PathVariable Long id, 
            @RequestBody UpdateRoleRequest request) {
        User.Role role = User.Role.valueOf(request.getRole());
        User updatedUser = userService.updateUserRole(id, role);
        return ResponseEntity.ok(UserDTO.fromUser(updatedUser));
    }
    
    @Data
    public static class UpdateRoleRequest {
        private String role;
    }
}