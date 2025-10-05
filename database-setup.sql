CREATE DATABASE ecommerce_db;

\c ecommerce_db;

CREATE TABLE users (
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


DROP VIEW IF EXISTS available_products;

CREATE TABLE products (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price NUMERIC(38,2),
    quantity INTEGER,
    image_url VARCHAR(500),
    size VARCHAR(100),
    category VARCHAR(100)
);

CREATE TABLE product_variants (
    id BIGSERIAL PRIMARY KEY,
    product_id BIGINT NOT NULL,
    size VARCHAR(100) NOT NULL,
    price NUMERIC(38,2) NOT NULL,
    quantity INTEGER NOT NULL,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);
CREATE VIEW available_products AS
SELECT p.*, v.size AS variant_size, v.price AS variant_price, v.quantity AS variant_quantity
FROM products p
LEFT JOIN product_variants v ON v.product_id = p.id
WHERE p.quantity > 0 OR v.quantity > 0;

CREATE TABLE cart_items (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity INTEGER NOT NULL,
    size VARCHAR(100),
    price DECIMAL(10,2),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

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

CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    address_id BIGINT,
    total NUMERIC(19,2),
    -- User details at time of order (frozen)
    user_full_name VARCHAR(255),
    user_email VARCHAR(255),
    user_phone VARCHAR(20),
    -- Address details at time of order (frozen)
    shipping_address_line1 VARCHAR(255),
    shipping_address_line2 VARCHAR(255),
    shipping_city VARCHAR(100),
    shipping_state VARCHAR(100),
    shipping_zip_code VARCHAR(20),
    shipping_phone VARCHAR(20),
    -- Order totals
    subtotal DECIMAL(10,2),
    tax DECIMAL(10,2),
    shipping_cost DECIMAL(10,2),
    total_amount DECIMAL(10,2),
    status VARCHAR(20) DEFAULT 'PENDING',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    order_number VARCHAR(50) UNIQUE,
    payment_method VARCHAR(50),
    notes TEXT,
    FOREIGN KEY (address_id) REFERENCES user_addresses(id) ON DELETE SET NULL
);

CREATE TABLE order_items (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    product_description TEXT,
    product_image_url VARCHAR(500),
    product_size VARCHAR(50),
    product_category VARCHAR(100),
    unit_price DECIMAL(10,2) NOT NULL,
    quantity INTEGER NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

CREATE TABLE materials (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    quantity_ordered VARCHAR(255) NOT NULL,
    cost DECIMAL(10,2) NOT NULL,
    ordered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    supervisor_id BIGINT,
    FOREIGN KEY (supervisor_id) REFERENCES users(id) ON DELETE SET NULL
);

INSERT INTO users (name, username, email, phone_number, password, role) VALUES 
('Administrator', 'admin', 'admin@example.com', '1234567890', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'ADMIN');

INSERT INTO products (name, description, category, image_url) VALUES 
('Premium Coffee', 'High-quality arabica coffee beans', 'Beverages', 'https://via.placeholder.com/300x200'),
('Organic Rice', 'Premium organic basmati rice', 'Food', 'https://via.placeholder.com/300x200'),
('Olive Oil', 'Extra virgin olive oil', 'Food', 'https://via.placeholder.com/300x200');

INSERT INTO product_variants (product_id, size, price, quantity) VALUES 
(1, '250g', 12.99, 50),
(1, '500g', 22.99, 30),
(1, '1kg', 39.99, 20),
(2, '1kg', 8.99, 100),
(2, '5kg', 39.99, 25),
(2, '10kg', 75.99, 15),
(3, '250ml', 15.99, 40),
(3, '500ml', 28.99, 25),
(3, '1L', 52.99, 15);

INSERT INTO products (name, description, price, quantity, size, category, image_url) VALUES 
('Laptop', 'High-performance laptop for work and gaming', 999.99, 10, 'Standard', 'Electronics', 'https://via.placeholder.com/300x200'),
('Smartphone', 'Latest smartphone with advanced features', 699.99, 25, 'Standard', 'Electronics', 'https://via.placeholder.com/300x200');

INSERT INTO stores (name, address, city, state, zip_code, phone, hours, is_active) VALUES 
('Downtown Store', '123 Main Street', 'New York', 'NY', '10001', '(555) 123-4567', '9:00 AM - 9:00 PM', true),
('Mall Location', '456 Shopping Center Blvd', 'Los Angeles', 'CA', '90210', '(555) 987-6543', '10:00 AM - 10:00 PM', true),
('Suburban Branch', '789 Oak Avenue', 'Chicago', 'IL', '60601', '(555) 456-7890', '8:00 AM - 8:00 PM', true);

INSERT INTO user_addresses (username, address_line1, address_line2, city, state, zip_code, phone, label) VALUES 
('admin', '123 Admin Street', 'Apt 1', 'New York', 'NY', '10001', '(555) 123-4567', 'Home');

CREATE INDEX idx_products_quantity ON products(quantity) WHERE quantity > 0;
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_product_variants_quantity ON product_variants(quantity) WHERE quantity > 0;
CREATE INDEX idx_product_variants_product_id ON product_variants(product_id);
CREATE INDEX idx_cart_items_user_id ON cart_items(user_id);
CREATE INDEX idx_cart_items_product_id ON cart_items(product_id);
CREATE INDEX idx_cart_items_user_product ON cart_items(user_id, product_id);
CREATE INDEX idx_materials_supervisor_id ON materials(supervisor_id);
CREATE INDEX idx_materials_ordered_at ON materials(ordered_at DESC);

CREATE TABLE wishlist (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    product_id BIGINT NOT NULL,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    UNIQUE(username, product_id)
);

CREATE TABLE user_preferences (
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

CREATE INDEX idx_orders_username ON orders(username);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_order_date ON orders(order_date);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_wishlist_username ON wishlist(username);
CREATE INDEX idx_wishlist_product_id ON wishlist(product_id);
CREATE INDEX idx_user_preferences_username ON user_preferences(username);

-- Update order status constraint to include PAID status
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE orders ADD CONSTRAINT orders_status_check 
CHECK (status IN ('PENDING', 'CONFIRMED', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'PAID', 'CANCELLED'));


ALTER TABLE materials ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE materials ALTER COLUMN quantity_ordered TYPE VARCHAR(255);
