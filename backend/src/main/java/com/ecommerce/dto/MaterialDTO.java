package com.ecommerce.dto;

import com.ecommerce.model.Material;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class MaterialDTO {
    private Long id;
    
    private String name;
    private String description;
    private String quantityOrdered;
    private BigDecimal cost;
    
    private String status;
    private Long supervisorId;
    private String supervisorName;
    private Long approvedById;
    private String approvedByName;
    private LocalDateTime orderedAt;
    private LocalDateTime approvedAt;

    public static MaterialDTO fromMaterial(Material material) {
        MaterialDTO dto = new MaterialDTO();
        dto.setId(material.getId());
        dto.setName(material.getName());
        dto.setDescription(material.getDescription());
        dto.setQuantityOrdered(material.getQuantityOrdered());
        dto.setCost(material.getCost());
        dto.setStatus(material.getStatus().toString());
        dto.setSupervisorId(material.getSupervisor().getId());
        dto.setSupervisorName(material.getSupervisor().getName());
        if (material.getApprovedBy() != null) {
            dto.setApprovedById(material.getApprovedBy().getId());
            dto.setApprovedByName(material.getApprovedBy().getName());
        }
        dto.setOrderedAt(material.getOrderedAt());
        dto.setApprovedAt(material.getApprovedAt());
        return dto;
    }
}
