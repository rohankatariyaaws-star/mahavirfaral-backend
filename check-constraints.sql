-- Check existing constraints on orders table
SELECT conname, contype, pg_get_constraintdef(oid) as definition
FROM pg_constraint 
WHERE conrelid = 'orders'::regclass;

-- Drop all check constraints on orders table
DO $$ 
DECLARE 
    constraint_name text;
BEGIN
    FOR constraint_name IN 
        SELECT conname 
        FROM pg_constraint 
        WHERE conrelid = 'orders'::regclass AND contype = 'c'
    LOOP
        EXECUTE 'ALTER TABLE orders DROP CONSTRAINT ' || constraint_name;
    END LOOP;
END $$;

-- Add the correct constraint
ALTER TABLE orders ADD CONSTRAINT orders_status_check 
CHECK (status IN ('PENDING', 'CONFIRMED', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'PAID', 'CANCELLED'));