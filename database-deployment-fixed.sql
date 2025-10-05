-- Complete Database Deployment Script for Ecommerce Platform
-- This script can be used for fresh installations or updates to existing databases

-- Drop problematic view temporarily to allow column modifications
DROP VIEW IF EXISTS available_products;

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'USER',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create products table
CREATE TABLE IF NOT EXISTS products (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price NUMERIC(38,2),
    quantity INTEGER,
    image_url VARCHAR(500),
    size VARCHAR(100),
    category VARCHAR(100)
);

-- Create product_variants table
CREATE TABLE IF NOT EXISTS product_variants (
    id BIGSERIAL PRIMARY KEY,
    product_id BIGINT NOT NULL,
    size VARCHAR(100) NOT NULL,
    price NUMERIC(38,2) NOT NULL,
    quantity INTEGER NOT NULL,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

-- Create cart_items table with all required columns
CREATE TABLE IF NOT EXISTS cart_items (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity INTEGER NOT NULL,
    size VARCHAR(100),
    price NUMERIC(38,2),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

-- Add missing columns to existing cart_items table
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cart_items' AND column_name = 'size') THEN
        ALTER TABLE cart_items ADD COLUMN size VARCHAR(100);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cart_items' AND column_name = 'price') THEN
        ALTER TABLE cart_items ADD COLUMN price NUMERIC(38,2);
    END IF;
END $$;

-- Create stores table
CREATE TABLE IF NOT EXISTS stores (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    zip_code VARCHAR(20) NOT NULL,
    phone VARCHAR(30),
    hours VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE
);

-- Create user_addresses table
CREATE TABLE IF NOT EXISTS user_addresses (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    address_line1 VARCHAR(255) NOT NULL,
    address_line2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    zip_code VARCHAR(20) NOT NULL,
    phone VARCHAR(30),
    label VARCHAR(50)
);

-- Create orders table
CREATE TABLE IF NOT EXISTS orders (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    address_id BIGINT,
    total NUMERIC(38,2),
    user_full_name VARCHAR(255),
    user_email VARCHAR(255),
    user_phone VARCHAR(20),
    shipping_address_line1 VARCHAR(255),
    shipping_address_line2 VARCHAR(255),
    shipping_city VARCHAR(100),
    shipping_state VARCHAR(100),
    shipping_zip_code VARCHAR(20),
    shipping_phone VARCHAR(20),
    subtotal NUMERIC(38,2),
    tax NUMERIC(38,2),
    shipping_cost NUMERIC(38,2),
    total_amount NUMERIC(38,2),
    status VARCHAR(20) DEFAULT 'PENDING',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    order_number VARCHAR(50) UNIQUE,
    payment_method VARCHAR(50),
    notes TEXT,
    FOREIGN KEY (address_id) REFERENCES user_addresses(id) ON DELETE SET NULL
);

-- Create order_items table
CREATE TABLE IF NOT EXISTS order_items (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    product_description TEXT,
    product_image_url VARCHAR(500),
    product_size VARCHAR(50),
    product_category VARCHAR(100),
    unit_price NUMERIC(38,2) NOT NULL,
    quantity INTEGER NOT NULL,
    total_price NUMERIC(38,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

-- Create materials table
CREATE TABLE IF NOT EXISTS materials (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    quantity_ordered INTEGER NOT NULL,
    cost NUMERIC(38,2) NOT NULL,
    ordered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    supervisor_id BIGINT,
    FOREIGN KEY (supervisor_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Create wishlist table
CREATE TABLE IF NOT EXISTS wishlist (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    product_id BIGINT NOT NULL,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    UNIQUE(username, product_id)
);

-- Create user_preferences table
CREATE TABLE IF NOT EXISTS user_preferences (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    language VARCHAR(10) DEFAULT 'en',
    currency VARCHAR(10) DEFAULT 'INR',
    theme VARCHAR(20) DEFAULT 'light',
    email_notifications BOOLEAN DEFAULT TRUE,
    sms_notifications BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Recreate the available_products view
CREATE VIEW available_products AS
SELECT p.*, v.size AS variant_size, v.price AS variant_price, v.quantity AS variant_quantity
FROM products p
LEFT JOIN product_variants v ON v.product_id = p.id
WHERE p.quantity > 0 OR v.quantity > 0;

-- Insert default admin user with correct BCrypt hash (only if not exists)
INSERT INTO users (name, username, email, phone_number, password, role) 
SELECT 'Administrator', 'admin', 'admin@example.com', '1234567890', '$2a$10$N.zmdr9k7uOCQb07Dvo/9eUiLrMzodDr7P7aP6kevkKBTyiTzV2Iq', 'ADMIN'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'admin');

-- Insert sample supervisor user (only if not exists)
INSERT INTO users (name, username, email, phone_number, password, role) 
SELECT 'Supervisor User', 'supervisor', 'supervisor@example.com', '1234567891', '$2a$10$N.zmdr9k7uOCQb07Dvo/9eUiLrMzodDr7P7aP6kevkKBTyiTzV2Iq', 'SUPERVISOR'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'supervisor');

-- Insert sample regular user (only if not exists)
INSERT INTO users (name, username, email, phone_number, password, role) 
SELECT 'Regular User', 'user', 'user@example.com', '1234567892', '$2a$10$N.zmdr9k7uOCQb07Dvo/9eUiLrMzodDr7P7aP6kevkKBTyiTzV2Iq', 'USER'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'user');

-- Insert sample products (only if not exists)
INSERT INTO products (name, description, category, image_url) 
SELECT 'Premium Coffee', 'High-quality arabica coffee beans', 'Beverages', 'https://via.placeholder.com/300x200'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Premium Coffee');

INSERT INTO products (name, description, category, image_url) 
SELECT 'Organic Rice', 'Premium organic basmati rice', 'Food', 'https://via.placeholder.com/300x200'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Organic Rice');

INSERT INTO products (name, description, category, image_url) 
SELECT 'Olive Oil', 'Extra virgin olive oil', 'Food', 'https://via.placeholder.com/300x200'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Olive Oil');

-- Insert product variants with Indian pricing (only if not exists)
INSERT INTO product_variants (product_id, size, price, quantity) 
SELECT 1, '250g', 299.99, 50
WHERE NOT EXISTS (SELECT 1 FROM product_variants WHERE product_id = 1 AND size = '250g');

INSERT INTO product_variants (product_id, size, price, quantity) 
SELECT 1, '500g', 549.99, 30
WHERE NOT EXISTS (SELECT 1 FROM product_variants WHERE product_id = 1 AND size = '500g');

INSERT INTO product_variants (product_id, size, price, quantity) 
SELECT 1, '1kg', 999.99, 20
WHERE NOT EXISTS (SELECT 1 FROM product_variants WHERE product_id = 1 AND size = '1kg');

INSERT INTO product_variants (product_id, size, price, quantity) 
SELECT 2, '1kg', 199.99, 100
WHERE NOT EXISTS (SELECT 1 FROM product_variants WHERE product_id = 2 AND size = '1kg');

INSERT INTO product_variants (product_id, size, price, quantity) 
SELECT 2, '5kg', 899.99, 25
WHERE NOT EXISTS (SELECT 1 FROM product_variants WHERE product_id = 2 AND size = '5kg');

INSERT INTO product_variants (product_id, size, price, quantity) 
SELECT 2, '10kg', 1699.99, 15
WHERE NOT EXISTS (SELECT 1 FROM product_variants WHERE product_id = 2 AND size = '10kg');

INSERT INTO product_variants (product_id, size, price, quantity) 
SELECT 3, '250ml', 349.99, 40
WHERE NOT EXISTS (SELECT 1 FROM product_variants WHERE product_id = 3 AND size = '250ml');

INSERT INTO product_variants (product_id, size, price, quantity) 
SELECT 3, '500ml', 649.99, 25
WHERE NOT EXISTS (SELECT 1 FROM product_variants WHERE product_id = 3 AND size = '500ml');

INSERT INTO product_variants (product_id, size, price, quantity) 
SELECT 3, '1L', 1199.99, 15
WHERE NOT EXISTS (SELECT 1 FROM product_variants WHERE product_id = 3 AND size = '1L');

-- Insert backward compatible products with Indian pricing
INSERT INTO products (name, description, price, quantity, size, category, image_url) 
SELECT 'Laptop', 'High-performance laptop for work and gaming', 75999.99, 10, 'Standard', 'Electronics', 'https://via.placeholder.com/300x200'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Laptop');

INSERT INTO products (name, description, price, quantity, size, category, image_url) 
SELECT 'Smartphone', 'Latest smartphone with advanced features', 49999.99, 25, 'Standard', 'Electronics', 'https://via.placeholder.com/300x200'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Smartphone');

-- Insert sample stores
INSERT INTO stores (name, address, city, state, zip_code, phone, hours, is_active) 
SELECT 'Downtown Store', '123 Main Street', 'New York', 'NY', '10001', '(555) 123-4567', '9:00 AM - 9:00 PM', true
WHERE NOT EXISTS (SELECT 1 FROM stores WHERE name = 'Downtown Store');

INSERT INTO stores (name, address, city, state, zip_code, phone, hours, is_active) 
SELECT 'Mall Location', '456 Shopping Center Blvd', 'Los Angeles', 'CA', '90210', '(555) 987-6543', '10:00 AM - 10:00 PM', true
WHERE NOT EXISTS (SELECT 1 FROM stores WHERE name = 'Mall Location');

INSERT INTO stores (name, address, city, state, zip_code, phone, hours, is_active) 
SELECT 'Suburban Branch', '789 Oak Avenue', 'Chicago', 'IL', '60601', '(555) 456-7890', '8:00 AM - 8:00 PM', true
WHERE NOT EXISTS (SELECT 1 FROM stores WHERE name = 'Suburban Branch');

-- Insert sample address for admin user
INSERT INTO user_addresses (username, address_line1, address_line2, city, state, zip_code, phone, label) 
SELECT 'admin', '123 Admin Street', 'Apt 1', 'New York', 'NY', '10001', '(555) 123-4567', 'Home'
WHERE NOT EXISTS (SELECT 1 FROM user_addresses WHERE username = 'admin');

-- Create all indexes
CREATE INDEX IF NOT EXISTS idx_products_quantity ON products(quantity) WHERE quantity > 0;
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_product_variants_quantity ON product_variants(quantity) WHERE quantity > 0;
CREATE INDEX IF NOT EXISTS idx_product_variants_product_id ON product_variants(product_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_user_id ON cart_items(user_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_product_id ON cart_items(product_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_user_product ON cart_items(user_id, product_id);
CREATE INDEX IF NOT EXISTS idx_materials_supervisor_id ON materials(supervisor_id);
CREATE INDEX IF NOT EXISTS idx_materials_ordered_at ON materials(ordered_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_username ON orders(username);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_order_date ON orders(order_date);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_wishlist_username ON wishlist(username);
CREATE INDEX IF NOT EXISTS idx_wishlist_product_id ON wishlist(product_id);
CREATE INDEX IF NOT EXISTS idx_user_preferences_username ON user_preferences(username);

-- Create useful views
CREATE OR REPLACE VIEW user_cart_summary AS
SELECT 
    u.username,
    COUNT(ci.id) as total_items,
    SUM(ci.quantity) as total_quantity,
    SUM(ci.quantity * COALESCE(ci.price, p.price, 0)) as estimated_total
FROM users u
LEFT JOIN cart_items ci ON u.id = ci.user_id
LEFT JOIN products p ON ci.product_id = p.id
GROUP BY u.id, u.username;

-- Update existing cart items to have default values for new columns
UPDATE cart_items SET 
    size = 'Standard',
    price = (SELECT price FROM products WHERE products.id = cart_items.product_id)
WHERE size IS NULL OR price IS NULL;

-- Update existing orders with default values if needed
UPDATE orders 
SET 
    status = 'PENDING' WHERE status IS NULL,
    updated_at = order_date WHERE updated_at IS NULL,
    subtotal = 0 WHERE subtotal IS NULL,
    tax = 0 WHERE tax IS NULL,
    shipping_cost = 0 WHERE shipping_cost IS NULL,
    total_amount = COALESCE(total, 0) WHERE total_amount IS NULL;

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;

-- Display deployment summary
SELECT 'Database deployment completed successfully!' as status;
SELECT 'Login credentials:' as info;
SELECT 'Admin - Username: admin, Password: admin123' as admin_login;
SELECT 'Supervisor - Username: supervisor, Password: admin123' as supervisor_login;
SELECT 'User - Username: user, Password: admin123' as user_login;