package com.ecommerce.controller;

import com.ecommerce.dto.UserPreferencesDTO;
import com.ecommerce.service.UserPreferencesService;
import com.ecommerce.util.JWTTokenDetails;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;

import org.springframework.web.bind.annotation.*;



@RestController
@RequestMapping("/api/preferences")
@RequiredArgsConstructor
@PreAuthorize("hasRole('USER') or hasRole('ADMIN') or hasRole('SUPERVISOR')")
public class UserPreferencesController {
    
    private final UserPreferencesService userPreferencesService;
    private final JWTTokenDetails jwtTokenDetails;

    @GetMapping
    public ResponseEntity<UserPreferencesDTO> getPreferences() {
        Long userId = jwtTokenDetails.getUserId();
        UserPreferencesDTO preferences = userPreferencesService.getPreferences(userId);
        return ResponseEntity.ok(preferences);
    }

    @PutMapping
    public ResponseEntity<UserPreferencesDTO> updatePreferences(@RequestBody UserPreferencesDTO preferences) {
        Long userId = jwtTokenDetails.getUserId();
        UserPreferencesDTO updated = userPreferencesService.updatePreferences(userId, preferences);
        return ResponseEntity.ok(updated);
    }
}