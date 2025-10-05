package com.ecommerce.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.ToString;
import java.time.LocalDateTime;

@Entity
@Table(name = "user_preferences")
@Data
public class UserPreferences {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", unique = true)
    @ToString.Exclude
    private User user;

    private String language;
    private String currency;
    private String theme;
    private Boolean emailNotifications;
    private Boolean smsNotifications;

    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public UserPreferences() {
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
        this.language = "en";
        this.currency = "INR";
        this.theme = "light";
        this.emailNotifications = true;
        this.smsNotifications = false;
    }
}