package com.ecommerce.util;

import com.ecommerce.model.User;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

@Component
public class JWTTokenDetails {
    public Long getUserId() {
        User user = (User) SecurityContextHolder.getContext().getAuthentication().getDetails();
        return user.getId();
    }

    public User.Role getUserRole() {
        User user = (User) SecurityContextHolder.getContext().getAuthentication().getDetails();
        return user.getRole();
    }
}
