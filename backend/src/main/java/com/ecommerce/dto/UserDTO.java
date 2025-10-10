package com.ecommerce.dto;

import com.ecommerce.model.User;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class UserDTO {
    private Long id;
    private String name;
    private String email;
    private String city;
    private String phoneNumber;
    private User.Role role;
    private LocalDateTime createdAt;
    private List<UserAddressDTO> addresses;

    public static UserDTO fromUser(User user) {
        UserDTO dto = new UserDTO();
        dto.setId(user.getId());
        dto.setName(user.getName());
        dto.setEmail(user.getEmail());
        dto.setCity(user.getCity());
        dto.setPhoneNumber(user.getPhoneNumber());
        dto.setRole(user.getRole());
        dto.setCreatedAt(user.getCreatedAt());
        if (user.getUserAddresses() != null) {
            dto.setAddresses(user.getUserAddresses().stream()
                .map(address -> {
                    UserAddressDTO addressDTO = new UserAddressDTO();
                    addressDTO.setId(address.getId());
                    addressDTO.setUserId(address.getUser().getId());
                    addressDTO.setAddressLine1(address.getAddressLine1());
                    addressDTO.setAddressLine2(address.getAddressLine2());
                    addressDTO.setCity(address.getCity());
                    addressDTO.setState(address.getState());
                    addressDTO.setZipCode(address.getZipCode());
                    addressDTO.setPhone(address.getPhone());
                    addressDTO.setLabel(address.getLabel());
                    return addressDTO;
                })
                .collect(Collectors.toList()));
        }
        return dto;
    }
}