-- Ecommerce Database Deployment Script
-- This script creates all necessary tables, indexes, and sample data

-- Drop existing tables if they exist (for clean deployment)
DROP TABLE IF EXISTS materials CASCADE;
DROP TABLE IF EXISTS cart_items CASCADE;
DROP TABLE IF EXISTS product_variants CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS user_addresses CASCADE;
DROP TABLE IF EXISTS stores CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS users CASCADE;
-- Create stores table
CREATE TABLE stores (
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
CREATE TABLE user_addresses (
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
CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    address_id BIGINT,
    total NUMERIC(19,2),
    status VARCHAR(50),
    FOREIGN KEY (address_id) REFERENCES user_addresses(id) ON DELETE SET NULL
);

-- Create users table
CREATE TABLE users (
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
CREATE TABLE products (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2),
    quantity INTEGER,
    image_url VARCHAR(500),
    size VARCHAR(100),
    category VARCHAR(100)
);

-- Create product_variants table for multiple sizes
CREATE TABLE product_variants (
    id BIGSERIAL PRIMARY KEY,
    product_id BIGINT NOT NULL,
    size VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    quantity INTEGER NOT NULL,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

-- Create cart_items table
CREATE TABLE cart_items (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity INTEGER NOT NULL,
    size VARCHAR(100),
    price NUMERIC(19,2),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

-- Create materials table
CREATE TABLE materials (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    quantity_ordered INTEGER NOT NULL,
    cost DECIMAL(10,2) NOT NULL,
    ordered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    supervisor_id BIGINT,
    FOREIGN KEY (supervisor_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Performance Indexes
CREATE INDEX idx_products_quantity ON products(quantity) WHERE quantity > 0;
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_product_variants_quantity ON product_variants(quantity) WHERE quantity > 0;
CREATE INDEX idx_product_variants_product_id ON product_variants(product_id);
CREATE INDEX idx_cart_items_user_id ON cart_items(user_id);
CREATE INDEX idx_cart_items_product_id ON cart_items(product_id);
CREATE INDEX idx_cart_items_user_product ON cart_items(user_id, product_id);
CREATE INDEX idx_materials_supervisor_id ON materials(supervisor_id);
CREATE INDEX idx_materials_ordered_at ON materials(ordered_at DESC);

-- Note: Admin user will be created via API endpoint for proper password encoding
-- After starting backend, run: curl -X POST http://localhost:8080/api/auth/create-admin

-- Insert sample products with multiple sizes
INSERT INTO products (name, description, category, image_url) VALUES 
('Premium Coffee', 'High-quality arabica coffee beans', 'Beverages', 'https://via.placeholder.com/300x200'),
('Organic Rice', 'Premium organic basmati rice', 'Food', 'https://via.placeholder.com/300x200'),
('Olive Oil', 'Extra virgin olive oil', 'Food', 'https://via.placeholder.com/300x200');

-- Insert product variants (multiple sizes for each product)
INSERT INTO product_variants (product_id, size, price, quantity) VALUES 
(1, '250g', 299.99, 50),
(1, '500g', 549.99, 30),
(1, '1kg', 999.99, 20),
(2, '1kg', 199.99, 100),
(2, '5kg', 899.99, 25),
(2, '10kg', 1699.99, 15),
(3, '250ml', 349.99, 40),
(3, '500ml', 649.99, 25),
(3, '1L', 1199.99, 15);

-- Insert some backward compatible products (single size)
INSERT INTO products (name, description, price, quantity, size, category, image_url) VALUES 
('Laptop', 'High-performance laptop for work and gaming', 75999.99, 10, 'Standard', 'Electronics', 'https://via.placeholder.com/300x200'),
('Smartphone', 'Latest smartphone with advanced features', 49999.99, 25, 'Standard', 'Electronics', 'https://via.placeholder.com/300x200');

-- Create useful views
CREATE VIEW available_products AS
SELECT p.*, pv.size as variant_size, pv.price as variant_price, pv.quantity as variant_quantity
FROM products p
LEFT JOIN product_variants pv ON p.id = pv.product_id
WHERE (p.quantity > 0 AND p.price IS NOT NULL) OR (pv.quantity > 0);

CREATE VIEW user_cart_summary AS
SELECT 
    u.username,
    COUNT(ci.id) as total_items,
    SUM(ci.quantity) as total_quantity,
    SUM(ci.quantity * COALESCE(p.price, 0)) as estimated_total
FROM users u
LEFT JOIN cart_items ci ON u.id = ci.user_id
LEFT JOIN products p ON ci.product_id = p.id
GROUP BY u.id, u.username;

-- Grant permissions (adjust as needed)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;

-- Display deployment summary
SELECT 'Database deployment completed successfully!' as status;
SELECT 'Tables created: ' || count(*) as tables_count FROM information_schema.tables WHERE table_schema = 'public';

-- Display created users
SELECT 'Created users:' as info;
SELECT username, role, 'Password: admin123, supervisor123, or user123' as credentials FROM users;

SELECT 'Login credentials:' as login_info;
SELECT 'Admin - Username: admin, Password: admin123' as admin_creds;
SELECT 'Supervisor - Username: supervisor, Password: supervisor123' as supervisor_creds;
SELECT 'User - Username: user, Password: user123' as user_creds;