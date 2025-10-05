-- Add the size column for product variants in cart_items
ALTER TABLE cart_items ADD COLUMN size VARCHAR(100);
-- Add the price column for product variants in cart_items
ALTER TABLE cart_items ADD COLUMN price NUMERIC(19,2);