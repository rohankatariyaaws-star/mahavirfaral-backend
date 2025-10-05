-- Add missing columns to existing users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS name VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_number VARCHAR(20);

-- Update existing admin user with missing data
UPDATE users SET 
    name = 'Administrator',
    phone_number = '1234567890'
WHERE username = 'admin' AND name IS NULL;