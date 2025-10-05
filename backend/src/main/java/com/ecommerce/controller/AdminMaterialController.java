package com.ecommerce.controller;

import com.ecommerce.model.Material;
import com.ecommerce.model.User;
import com.ecommerce.service.MaterialService;
import com.ecommerce.service.UserService;
import com.ecommerce.util.JWTTokenDetails;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.time.LocalDateTime;

@RestController
@RequestMapping("/api/admin")
public class AdminMaterialController {

    @Autowired
    private MaterialService materialService;

    @Autowired
    private UserService userService;

    @Autowired
    private JWTTokenDetails jwtTokenDetails;

    @GetMapping("/materials")
    public List<Material> getAllMaterials() {
        return materialService.getAllMaterials();
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PutMapping("/materials/{id}/approve/{approved}")
    public ResponseEntity<Material> approveMaterial(@PathVariable Long id, @PathVariable Boolean approved) {
        Long adminId = jwtTokenDetails.getUserId();
        User admin = userService.findById(adminId).orElseThrow();

        Material material = materialService.getMaterialById(id);
        material.setStatus(approved ? Material.ApprovalStatus.APPROVED : Material.ApprovalStatus.REJECTED);
        material.setApprovedBy(admin);
        material.setApprovedAt(LocalDateTime.now());

        Material updatedMaterial = materialService.updateMaterial(material);
        return ResponseEntity.ok(updatedMaterial);
    }

//    @PutMapping("/materials/{id}/reject")
//    public ResponseEntity<Material> rejectMaterial(@PathVariable Long id, @RequestBody Map<String, Object> request) {
//        Long adminId = Long.valueOf(request.get("adminId").toString());
//        User admin = userService.findById(adminId).orElseThrow();
//
//        Material material = materialService.getMaterialById(id);
//        material.setStatus(Material.ApprovalStatus.REJECTED);
//        material.setApprovedBy(admin);
//        material.setApprovedAt(LocalDateTime.now());
//
//        Material updatedMaterial = materialService.updateMaterial(material);
//        return ResponseEntity.ok(updatedMaterial);
//    }
}