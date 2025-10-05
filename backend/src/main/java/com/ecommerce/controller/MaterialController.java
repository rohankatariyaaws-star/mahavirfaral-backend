package com.ecommerce.controller;

import com.ecommerce.dto.MaterialDTO;
import com.ecommerce.model.Material;
import com.ecommerce.model.User;
import com.ecommerce.service.MaterialService;
import com.ecommerce.service.UserService;
import com.ecommerce.util.JWTTokenDetails;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;

import org.springframework.web.bind.annotation.*;


import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/supervisor")
@RequiredArgsConstructor
@PreAuthorize("hasRole('SUPERVISOR') or hasRole('ADMIN')")
public class MaterialController {
    
    private final MaterialService materialService;
    private final UserService userService;
    private final JWTTokenDetails jwtTokenDetails;
    
    @PostMapping("/materials")
    public ResponseEntity<MaterialDTO> addMaterial(@RequestBody MaterialDTO materialInput) {
        Long userId = jwtTokenDetails.getUserId();
        User supervisor = userService.findById(userId)
            .orElseThrow(() -> new RuntimeException("Supervisor not found"));
        
        Material material = new Material();
        material.setName(materialInput.getName());
        material.setDescription(materialInput.getDescription());
        material.setQuantityOrdered(materialInput.getQuantityOrdered());
        material.setCost(materialInput.getCost());
        material.setSupervisor(supervisor);
        
        Material savedMaterial = materialService.addMaterial(material);
        return ResponseEntity.ok(MaterialDTO.fromMaterial(savedMaterial));
    }
    
    @GetMapping("/materials")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<List<MaterialDTO>> getAllMaterials() {
        List<MaterialDTO> materials = materialService.getAllMaterials().stream()
            .map(MaterialDTO::fromMaterial)
            .collect(Collectors.toList());
        return ResponseEntity.ok(materials);
    }
    
    @GetMapping("/materials/my")
    public ResponseEntity<List<MaterialDTO>> getMyMaterials() {
        Long userId = jwtTokenDetails.getUserId();
        User supervisor = userService.findById(userId)
            .orElseThrow(() -> new RuntimeException("Supervisor not found"));
        List<MaterialDTO> materials = materialService.getMaterialsBySupervisor(supervisor).stream()
            .map(MaterialDTO::fromMaterial)
            .collect(Collectors.toList());
        return ResponseEntity.ok(materials);
    }
    
    @DeleteMapping("/materials/{id}")
    public ResponseEntity<Void> deleteMaterial(@PathVariable Long id) {
        materialService.deleteMaterial(id);
        return ResponseEntity.noContent().build();
    }
    
    @PutMapping("/materials/{id}")
    public ResponseEntity<MaterialDTO> updateMaterial(@PathVariable Long id, 
            @RequestBody MaterialDTO materialInput) {
        Material material = materialService.getMaterialById(id);
        if (material.getStatus() != Material.ApprovalStatus.PENDING) {
            return ResponseEntity.badRequest().build();
        }

        material.setName(materialInput.getName());
        material.setDescription(materialInput.getDescription());
        material.setQuantityOrdered(materialInput.getQuantityOrdered());
        material.setCost(materialInput.getCost());
        
        Material updatedMaterial = materialService.updateMaterial(material);
        return ResponseEntity.ok(MaterialDTO.fromMaterial(updatedMaterial));
    }
}