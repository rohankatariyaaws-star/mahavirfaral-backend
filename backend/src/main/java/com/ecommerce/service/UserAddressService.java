package com.ecommerce.service;

import com.ecommerce.dto.UserAddressDTO;
import com.ecommerce.model.User;
import com.ecommerce.model.UserAddress;
import com.ecommerce.repository.UserAddressRepository;
import com.ecommerce.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
public class UserAddressService {
    @Autowired
    private UserAddressRepository userAddressRepository;

    @Autowired
    private UserRepository userRepository;

    public List<UserAddressDTO> getAddressesByUserId(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        List<UserAddress> addresses = userAddressRepository.findByUser(user);
        return addresses.stream()
                .map(this::convertToDTO)
                .collect(Collectors.toList());
    }

    public Optional<UserAddressDTO> getAddressById(Long id) {
        return userAddressRepository.findById(id)
                .map(this::convertToDTO);
    }

    public UserAddressDTO saveAddress(UserAddress address) {
        UserAddress savedAddress = userAddressRepository.save(address);
        return convertToDTO(savedAddress);
    }

    public void deleteAddress(Long id) {
        userAddressRepository.deleteById(id);
    }

    private UserAddressDTO convertToDTO(UserAddress address) {
        UserAddressDTO dto = new UserAddressDTO();
        dto.setId(address.getId());
        dto.setUserId(address.getUser().getId());
        dto.setAddressLine1(address.getAddressLine1());
        dto.setAddressLine2(address.getAddressLine2());
        dto.setCity(address.getCity());
        dto.setState(address.getState());
        dto.setZipCode(address.getZipCode());
        dto.setPhone(address.getPhone());
        dto.setLabel(address.getLabel());
        return dto;
    }
}