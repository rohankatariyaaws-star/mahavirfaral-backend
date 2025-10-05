@echo off
echo ========================================
echo DATABASE MIGRATION REQUIRED
echo ========================================
echo.
echo The backend failed to start because the 'order_items' table is missing.
echo.
echo Please run the following SQL script in your PostgreSQL database:
echo File: run-migration.sql
echo.
echo You can run it using:
echo 1. pgAdmin (copy and paste the SQL)
echo 2. Command line: psql -U postgres -d ecommerce_db -f run-migration.sql
echo 3. Any PostgreSQL client tool
echo.
echo After running the migration, restart the backend server.
echo.
pause