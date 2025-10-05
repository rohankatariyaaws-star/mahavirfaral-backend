-- Connect to ecommerce_db and run this script
\c ecommerce_db;

-- Update orders table to include comprehensive tracking
ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS user_full_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS user_email VARCHAR(255),
ADD COLUMN IF NOT EXISTS user_phone VARCHAR(20),
ADD COLUMN IF NOT EXISTS shipping_address_line1 VARCHAR(255),
ADD COLUMN IF NOT EXISTS shipping_address_line2 VARCHAR(255),
ADD COLUMN IF NOT EXISTS shipping_city VARCHAR(100),
ADD COLUMN IF NOT EXISTS shipping_state VARCHAR(100),
ADD COLUMN IF NOT EXISTS shipping_zip_code VARCHAR(20),
ADD COLUMN IF NOT EXISTS shipping_phone VARCHAR(20),
ADD COLUMN IF NOT EXISTS subtotal DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS tax DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS shipping_cost DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS total_amount DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'PENDING',
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN IF NOT EXISTS order_number VARCHAR(50) UNIQUE,
ADD COLUMN IF NOT EXISTS payment_method VARCHAR(50),
ADD COLUMN IF NOT EXISTS notes TEXT;

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
    unit_price DECIMAL(10,2) NOT NULL,
    quantity INTEGER NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_orders_username ON orders(username);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_order_date ON orders(order_date);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);

-- Update existing orders with default values if needed
UPDATE orders 
SET 
    status = 'PENDING' WHERE status IS NULL,
    updated_at = order_date WHERE updated_at IS NULL,
    subtotal = 0 WHERE subtotal IS NULL,
    tax = 0 WHERE tax IS NULL,
    shipping_cost = 0 WHERE shipping_cost IS NULL,
    total_amount = 0 WHERE total_amount IS NULL;