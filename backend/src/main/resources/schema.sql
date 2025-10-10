-- Ensure delivery_date and user_city columns exist in orders table
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_date TIMESTAMP;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS user_city VARCHAR(255);