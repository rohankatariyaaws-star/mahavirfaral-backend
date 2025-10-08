-- Ensure orders table has auto-increment ID (should already exist)
-- This is just for verification/documentation

-- Check current structure
DESCRIBE orders;

-- The orders table should already have:
-- id BIGINT AUTO_INCREMENT PRIMARY KEY
-- orderNumber VARCHAR(255) (for generated order numbers like "ORD-2024-001234")

-- If for some reason the auto-increment is missing, uncomment below:
-- ALTER TABLE orders MODIFY COLUMN id BIGINT AUTO_INCREMENT;

-- Verify the structure
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT,
    EXTRA
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'orders' 
AND TABLE_SCHEMA = DATABASE()
ORDER BY ORDINAL_POSITION;