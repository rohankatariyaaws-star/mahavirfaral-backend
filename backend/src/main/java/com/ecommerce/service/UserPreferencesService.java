package com.ecommerce.service;

import com.ecommerce.dto.UserPreferencesDTO;
import com.ecommerce.model.User;
import com.ecommerce.model.UserPreferences;
import com.ecommerce.repository.UserPreferencesRepository;
import com.ecommerce.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

@Service
public class UserPreferencesService {
    @Autowired
    private UserPreferencesRepository userPreferencesRepository;
    
    @Autowired
    private UserRepository userRepository;

    public UserPreferencesDTO getPreferences(Long userId) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("User not found"));
            
        UserPreferences preferences = userPreferencesRepository.findByUser(user)
            .orElseGet(() -> {
                UserPreferences newPreferences = new UserPreferences();
                newPreferences.setUser(user);
                return userPreferencesRepository.save(newPreferences);
            });
            
        return UserPreferencesDTO.fromUserPreferences(preferences);
    }

    public UserPreferencesDTO updatePreferences(Long userId, UserPreferencesDTO updatedPreferencesDTO) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("User not found"));
            
        UserPreferences preferences = userPreferencesRepository.findByUser(user)
            .orElse(new UserPreferences());
        
        preferences.setUser(user);
        preferences.setLanguage(updatedPreferencesDTO.getLanguage());
        preferences.setCurrency(updatedPreferencesDTO.getCurrency());
        preferences.setTheme(updatedPreferencesDTO.getTheme());
        preferences.setEmailNotifications(updatedPreferencesDTO.getEmailNotifications());
        preferences.setSmsNotifications(updatedPreferencesDTO.getSmsNotifications());
        preferences.setUpdatedAt(LocalDateTime.now());
        
        UserPreferences saved = userPreferencesRepository.save(preferences);
        return UserPreferencesDTO.fromUserPreferences(saved);
    }
}