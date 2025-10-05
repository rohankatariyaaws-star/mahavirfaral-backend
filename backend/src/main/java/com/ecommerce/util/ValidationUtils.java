package com.ecommerce.util;

import com.ecommerce.exception.BadRequestException;

import java.util.regex.Pattern;

public class ValidationUtils {
    
    private static final Pattern EMAIL_PATTERN = 
        Pattern.compile("^[A-Za-z0-9+_.-]+@([A-Za-z0-9.-]+\\.[A-Za-z]{2,})$");
    
    private static final Pattern PHONE_PATTERN = 
        Pattern.compile("^[+]?[0-9]{10,15}$");

    public static void validateEmail(String email) {
        if (email != null && !EMAIL_PATTERN.matcher(email).matches()) {
            throw new BadRequestException("Invalid email format");
        }
    }

    public static void validatePhoneNumber(String phoneNumber) {
        if (phoneNumber == null || !PHONE_PATTERN.matcher(phoneNumber).matches()) {
            throw new BadRequestException("Invalid phone number format");
        }
    }

    public static void validatePassword(String password) {
        if (password == null || password.length() < 6) {
            throw new BadRequestException("Password must be at least 6 characters long");
        }
    }

    public static void validateNotEmpty(String value, String fieldName) {
        if (value == null || value.trim().isEmpty()) {
            throw new BadRequestException(fieldName + " cannot be empty");
        }
    }

    public static void validatePositive(Number value, String fieldName) {
        if (value == null || value.doubleValue() <= 0) {
            throw new BadRequestException(fieldName + " must be positive");
        }
    }

    public static void validateRange(Number value, Number min, Number max, String fieldName) {
        if (value == null || value.doubleValue() < min.doubleValue() || value.doubleValue() > max.doubleValue()) {
            throw new BadRequestException(fieldName + " must be between " + min + " and " + max);
        }
    }
}