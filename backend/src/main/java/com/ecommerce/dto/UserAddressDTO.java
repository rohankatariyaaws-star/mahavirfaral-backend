package com.ecommerce.dto;

import lombok.Data;

@Data
public class UserAddressDTO {
    private Long id;
    private Long userId;
    private String addressLine1;
    private String addressLine2;
    private String city;
    private String state;
    private String zipCode;
    private String phone;
    private String label;
}