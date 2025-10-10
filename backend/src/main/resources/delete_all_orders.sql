-- Delete all order related data
-- Run this script to clean up all orders and related data

-- Delete order items first (foreign key constraint)
DELETE FROM order_items;

-- Delete orders
DELETE FROM orders;

-- Reset auto-increment counters (optional)
-- ALTER TABLE orders AUTO_INCREMENT = 1;
-- ALTER TABLE order_items AUTO_INCREMENT = 1;