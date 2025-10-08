package com.ecommerce.service;

import com.ecommerce.model.Order;
import com.ecommerce.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class ScheduledTaskService {

    private final OrderRepository orderRepository;

    /**
     * Deletes cancelled orders that are older than 2 days
     * Runs every day at 2:00 AM
     */
    @Scheduled(cron = "0 0 2 * * ?")
    @Transactional
    public void deleteCancelledOrders() {
        log.info("Starting scheduled task to delete old cancelled orders");
        
        try {
            LocalDateTime cutoffDate = LocalDateTime.now().minusDays(2);
            
            // Find cancelled orders older than 2 days
            List<Order> cancelledOrders = orderRepository.findByStatusAndOrderDateBefore(
                Order.OrderStatus.CANCELLED, cutoffDate);
            
            if (cancelledOrders.isEmpty()) {
                log.info("No cancelled orders found older than 2 days");
                return;
            }
            
            log.info("Found {} cancelled orders older than 2 days to delete", cancelledOrders.size());
            
            // Delete the orders (cascade will delete order items)
            orderRepository.deleteAll(cancelledOrders);
            
            log.info("Successfully deleted {} cancelled orders", cancelledOrders.size());
            
        } catch (Exception e) {
            log.error("Error occurred while deleting cancelled orders", e);
        }
    }

    /**
     * Manual method to trigger cleanup (for testing or admin use)
     */
    public int manualCleanupCancelledOrders() {
        log.info("Manual cleanup of cancelled orders triggered");
        
        LocalDateTime cutoffDate = LocalDateTime.now().minusDays(2);
        List<Order> cancelledOrders = orderRepository.findByStatusAndOrderDateBefore(
            Order.OrderStatus.CANCELLED, cutoffDate);
        
        if (cancelledOrders.isEmpty()) {
            log.info("No cancelled orders found for manual cleanup");
            return 0;
        }
        
        int count = cancelledOrders.size();
        orderRepository.deleteAll(cancelledOrders);
        
        log.info("Manual cleanup completed: deleted {} cancelled orders", count);
        return count;
    }
}