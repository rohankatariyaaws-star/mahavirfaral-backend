package com.ecommerce.service;

import com.ecommerce.repository.CartItemRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
public class CartCleanupService {

    private final CartItemRepository cartItemRepository;

    @Scheduled(cron = "0 0 2 * * ?") // Run daily at 2 AM
    @Transactional
    public void cleanupAbandonedCarts() {
        LocalDateTime cutoffDate = LocalDateTime.now().minusDays(30);
        int deletedCount = cartItemRepository.deleteByCreatedAtBefore(cutoffDate);
        System.out.println("Cleaned up " + deletedCount + " abandoned cart items");
    }
}