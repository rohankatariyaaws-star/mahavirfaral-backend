package com.ecommerce.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class PhoneEmailResponse {
    @JsonProperty("user_country_code")
    private String userCountryCode;

    @JsonProperty("user_phone_number")
    private String userPhoneNumber;

    @JsonProperty("user_first_name")
    private String userFirstName;

    @JsonProperty("user_last_name")
    private String userLastName;

}
