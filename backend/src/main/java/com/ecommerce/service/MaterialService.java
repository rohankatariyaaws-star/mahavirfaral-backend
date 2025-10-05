package com.ecommerce.service;

import com.ecommerce.model.Material;
import com.ecommerce.model.User;
import com.ecommerce.repository.MaterialRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class MaterialService {
    
    @Autowired
    private MaterialRepository materialRepository;
    
    public Material addMaterial(Material material) {
        return materialRepository.save(material);
    }
    
    public List<Material> getAllMaterials() {
        return materialRepository.findAll();
    }
    
    public List<Material> getMaterialsBySupervisor(User supervisor) {
        return materialRepository.findBySupervisor(supervisor);
    }
    
    public void deleteMaterial(Long id) {
        materialRepository.deleteById(id);
    }
    
    public Material getMaterialById(Long id) {
        return materialRepository.findById(id).orElseThrow();
    }
    
    public Material updateMaterial(Material material) {
        return materialRepository.save(material);
    }
}