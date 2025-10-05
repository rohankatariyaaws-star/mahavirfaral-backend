-- Sample Data Script
-- Run this after the main database script

-- Insert admin user
INSERT INTO users (name, username, email, phone_number, password, role) 
VALUES ('Administrator', 'admin', 'admin@example.com', '1234567890', '$2a$10$N.zmdr9k7uOCQb07Dvo/9eUiLrMzodDr7P7aP6kevkKBTyiTzV2Iq', 'ADMIN')
ON CONFLICT (username) DO NOTHING;

-- Insert supervisor user
INSERT INTO users (name, username, email, phone_number, password, role) 
VALUES ('Supervisor User', 'supervisor', 'supervisor@example.com', '1234567891', '$2a$10$N.zmdr9k7uOCQb07Dvo/9eUiLrMzodDr7P7aP6kevkKBTyiTzV2Iq', 'SUPERVISOR')
ON CONFLICT (username) DO NOTHING;

-- Insert regular user
INSERT INTO users (name, username, email, phone_number, password, role) 
VALUES ('Regular User', 'user', 'user@example.com', '1234567892', '$2a$10$N.zmdr9k7uOCQb07Dvo/9eUiLrMzodDr7P7aP6kevkKBTyiTzV2Iq', 'USER')
ON CONFLICT (username) DO NOTHING;

-- Insert sample products
INSERT INTO products (name, description, category, image_url) 
VALUES 
('Premium Coffee', 'High-quality arabica coffee beans', 'Beverages', 'https://via.placeholder.com/300x200'),
('Organic Rice', 'Premium organic basmati rice', 'Food', 'https://via.placeholder.com/300x200'),
('Olive Oil', 'Extra virgin olive oil', 'Food', 'https://via.placeholder.com/300x200'),
('Laptop', 'High-performance laptop for work and gaming', 'Electronics', 'https://via.placeholder.com/300x200'),
('Smartphone', 'Latest smartphone with advanced features', 'Electronics', 'https://via.placeholder.com/300x200')
ON CONFLICT DO NOTHING;

-- Update products with prices and quantities
UPDATE products SET price = 75999.99, quantity = 10, size = 'Standard' WHERE name = 'Laptop';
UPDATE products SET price = 49999.99, quantity = 25, size = 'Standard' WHERE name = 'Smartphone';

-- Insert product variants
INSERT INTO product_variants (product_id, size, price, quantity) 
VALUES 
(1, '250g', 299.99, 50),
(1, '500g', 549.99, 30),
(1, '1kg', 999.99, 20),
(2, '1kg', 199.99, 100),
(2, '5kg', 899.99, 25),
(2, '10kg', 1699.99, 15),
(3, '250ml', 349.99, 40),
(3, '500ml', 649.99, 25),
(3, '1L', 1199.99, 15)
ON CONFLICT DO NOTHING;

-- Insert sample stores
INSERT INTO stores (name, address, city, state, zip_code, phone, hours, is_active) 
VALUES 
('Downtown Store', '123 Main Street', 'New York', 'NY', '10001', '(555) 123-4567', '9:00 AM - 9:00 PM', true),
('Mall Location', '456 Shopping Center Blvd', 'Los Angeles', 'CA', '90210', '(555) 987-6543', '10:00 AM - 10:00 PM', true),
('Suburban Branch', '789 Oak Avenue', 'Chicago', 'IL', '60601', '(555) 456-7890', '8:00 AM - 8:00 PM', true)
ON CONFLICT DO NOTHING;

-- Insert sample address
INSERT INTO user_addresses (username, address_line1, address_line2, city, state, zip_code, phone, label) 
VALUES ('admin', '123 Admin Street', 'Apt 1', 'New York', 'NY', '10001', '(555) 123-4567', 'Home')
ON CONFLICT DO NOTHING;