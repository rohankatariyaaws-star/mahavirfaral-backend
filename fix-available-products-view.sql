-- Fix for schema migration error due to view dependency on price column
-- 1. Drop the view temporarily
DROP VIEW IF EXISTS available_products;

-- 2. (Re)create the view after Hibernate updates the schema
-- Adjust the SELECT statement as per your original view definition
CREATE VIEW available_products AS
SELECT p.*, v.size AS variant_size, v.price AS variant_price, v.quantity AS variant_quantity
FROM products p
LEFT JOIN product_variants v ON v.product_id = p.id
WHERE p.quantity > 0 OR v.quantity > 0;

-- Note: You may need to adjust the SELECT and WHERE clauses to match your business logic.
-- Run this script after backend migration completes, or include it in your deployment process.
