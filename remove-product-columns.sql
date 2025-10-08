-- Migration script to remove price, quantity, size columns from products table
-- Run this on your database after deploying the updated code

-- Remove columns from products table
ALTER TABLE products DROP COLUMN IF EXISTS price;
ALTER TABLE products DROP COLUMN IF EXISTS quantity;
ALTER TABLE products DROP COLUMN IF EXISTS size;

-- Verify the table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'products' 
ORDER BY ordinal_position;