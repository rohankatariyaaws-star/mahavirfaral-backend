package com.ecommerce.dto;

import com.ecommerce.model.UserPreferences;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class UserPreferencesDTO {
    private Long id;
    private Long userId;
    private String language;
    private String currency;
    private String theme;
    private Boolean emailNotifications;
    private Boolean smsNotifications;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public static UserPreferencesDTO fromUserPreferences(UserPreferences preferences) {
        UserPreferencesDTO dto = new UserPreferencesDTO();
        dto.setId(preferences.getId());
        dto.setUserId(preferences.getUser().getId());
        dto.setLanguage(preferences.getLanguage());
        dto.setCurrency(preferences.getCurrency());
        dto.setTheme(preferences.getTheme());
        dto.setEmailNotifications(preferences.getEmailNotifications());
        dto.setSmsNotifications(preferences.getSmsNotifications());
        dto.setCreatedAt(preferences.getCreatedAt());
        dto.setUpdatedAt(preferences.getUpdatedAt());
        return dto;
    }
}