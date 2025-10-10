package com.ecommerce.dto;

import lombok.Data;

@Data
public class SignupRequest {
    private String name;
    private String username;
    private String email;
    private String city;
    private String phoneNumber;
    private String password;
    private String phoneEmailUrl;

    public SignupRequest() {
    }

    public SignupRequest(String name, String username, String email, String city, String phoneNumber, String password,
                         String countryCode) {
        this.name = name;
        this.username = username;
        this.email = email;
        this.city = city;
        this.phoneNumber = phoneNumber;
        this.password = password;
    }
}