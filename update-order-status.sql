-- Update order status constraint to include PAID status
-- First, drop the existing constraint if it exists
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check;

-- Add the new constraint with PAID status included
ALTER TABLE orders ADD CONSTRAINT orders_status_check 
CHECK (status IN ('PENDING', 'CONFIRMED', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'PAID', 'CANCELLED'));