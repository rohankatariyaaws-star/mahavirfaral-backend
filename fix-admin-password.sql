-- Fix admin password with correct BCrypt hash for 'admin123'
-- This hash was generated using BCrypt with strength 10

-- Delete existing admin user if exists
DELETE FROM users WHERE username = 'admin';

-- Insert admin user with correct BCrypt hash for password 'admin123'
INSERT INTO users (name, username, email, phone_number, password, role) VALUES 
('Administrator', 'admin', 'admin@example.com', '1234567890', '$2a$10$N.zmdr9k7uOCQb07Dvo/9eUiLrMzodDr7P7aP6kevkKBTyiTzV2Iq', 'ADMIN');

-- Verify the user was created
SELECT username, role, 'Password: admin123' as password_info FROM users WHERE username = 'admin';