package com.ecommerce.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.ToString;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "users")
@Data
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(nullable = false)
    private String name;
    
    @Column(unique = true, nullable = true)
    private String email;
    
    @Column(unique = true, nullable = false)
    private String phoneNumber;
    
    @Column(nullable = false)
    private String password;
    
    @Enumerated(EnumType.STRING)
    private Role role = Role.USER;

    @OneToMany(fetch = FetchType.LAZY, cascade = CascadeType.ALL, orphanRemoval = true, mappedBy = "user")
    @ToString.Exclude
    private List<UserAddress> userAddresses = new ArrayList<>();
    
    @OneToMany(fetch = FetchType.LAZY, cascade = CascadeType.ALL, orphanRemoval = true, mappedBy = "user")
    @ToString.Exclude
    private List<CartItem> cartItems = new ArrayList<>();
    
    @OneToMany(fetch = FetchType.LAZY, cascade = CascadeType.ALL, orphanRemoval = true, mappedBy = "user")
    @ToString.Exclude
    private List<Order> orders = new ArrayList<>();
    
    @OneToMany(fetch = FetchType.LAZY, cascade = CascadeType.ALL, orphanRemoval = true, mappedBy = "supervisor")
    @ToString.Exclude
    private List<Material> supervisedMaterials = new ArrayList<>();
    
    @OneToMany(fetch = FetchType.LAZY, cascade = CascadeType.ALL, orphanRemoval = true, mappedBy = "approvedBy")
    @ToString.Exclude
    private List<Material> approvedMaterials = new ArrayList<>();
    
    @OneToMany(fetch = FetchType.LAZY, cascade = CascadeType.ALL, orphanRemoval = true, mappedBy = "user")
    @ToString.Exclude
    private List<Wishlist> wishlistItems = new ArrayList<>();
    
    @OneToOne(fetch = FetchType.LAZY, cascade = CascadeType.ALL, orphanRemoval = true, mappedBy = "user")
    @ToString.Exclude
    private UserPreferences preferences;

    private LocalDateTime createdAt = LocalDateTime.ofInstant(Instant.now(), ZoneId.systemDefault());

    public User(String name, String userPhoneNumber, String email, String password) {
        this.name = name;
        this.email = email;
        this.phoneNumber = userPhoneNumber;
        this.password = password;
    }

    public void addWhichListToUser(Wishlist wishlist){
        this.getWishlistItems().add(wishlist);
        wishlist.setUser(this);
    }

    public void removeWhichListFromUser(Wishlist wishlist){
        this.getWishlistItems().remove(wishlist);
        wishlist.setUser(null);
    }

    public User() {

    }

    public enum Role {
        ADMIN, USER, SUPERVISOR
    }

    public void addToUserAddresses(UserAddress userAddress) {
        userAddresses.add(userAddress);
        userAddress.setUser(this);
    }

    public void removeFromUserAddresses(UserAddress userAddress) {
        userAddresses.remove(userAddress);
        userAddress.setUser(null);
    }
    
    public void addCartItem(CartItem cartItem) {
        cartItems.add(cartItem);
        cartItem.setUser(this);
    }
    
    public void removeCartItem(CartItem cartItem) {
        cartItems.remove(cartItem);
        cartItem.setUser(null);
    }
    
    public void addOrder(Order order) {
        orders.add(order);
        order.setUser(this);
    }
    
    public void removeOrder(Order order) {
        orders.remove(order);
        order.setUser(null);
    }


}