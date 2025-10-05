-- Drop the view temporarily
DROP VIEW IF EXISTS available_products;

-- Create the missing tables
CREATE TABLE IF NOT EXISTS wishlist (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    product_id BIGINT NOT NULL,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    UNIQUE(username, product_id)
);

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

-- Add missing columns to cart_items if they don't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cart_items' AND column_name = 'size') THEN
        ALTER TABLE cart_items ADD COLUMN size VARCHAR(100);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cart_items' AND column_name = 'price') THEN
        ALTER TABLE cart_items ADD COLUMN price DECIMAL(10,2);
    END IF;
END $$;

-- Recreate the view
CREATE VIEW available_products AS
SELECT p.*, v.size AS variant_size, v.price AS variant_price, v.quantity AS variant_quantity
FROM products p
LEFT JOIN product_variants v ON v.product_id = p.id
WHERE p.quantity > 0 OR v.quantity > 0;