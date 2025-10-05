package com.ecommerce.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import lombok.ToString;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "materials")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Material {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(nullable = false)
    private String name;
    
    private String description;
    
    @Column(nullable = false)
    private String quantityOrdered;
    
    @Column(nullable = false)
    private BigDecimal cost;
    
    private LocalDateTime orderedAt = LocalDateTime.now();
    
    @Enumerated(EnumType.STRING)
    private ApprovalStatus status = ApprovalStatus.PENDING;
    
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "supervisor_id")
    @ToString.Exclude
    private User supervisor;
    
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "approved_by")
    @ToString.Exclude
    private User approvedBy;
    
    private LocalDateTime approvedAt;
    
    public enum ApprovalStatus {
        PENDING, APPROVED, REJECTED
    }
    
    public Material(String name, String description, String quantityOrdered, BigDecimal cost, User supervisor) {
        this.name = name;
        this.description = description;
        this.quantityOrdered = quantityOrdered;
        this.cost = cost;
        this.supervisor = supervisor;
        this.status = ApprovalStatus.PENDING;
    }
}