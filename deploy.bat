@echo off
echo Deploying Ecommerce Database...
echo.

REM Check if PostgreSQL is running
pg_isready -h localhost -p 5433
if %errorlevel% neq 0 (
    echo PostgreSQL is not running. Please start PostgreSQL service first.
    pause
    exit /b 1
)

REM Create database if it doesn't exist
createdb -U postgres ecommerce_db 2>nul
if %errorlevel% equ 0 (
    echo Database 'ecommerce_db' created successfully.
) else (
    echo Database 'ecommerce_db' already exists or creation failed.
)

echo.
echo Running deployment script...
psql -U postgres -d ecommerce_db -f deploy-database.sql

echo.
echo Running order tracking migration...
psql -U postgres -d ecommerce_db -f update-orders-schema.sql

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo Database deployment completed successfully!
    echo ========================================
    echo Admin credentials:
    echo Username: admin
    echo Password: admin123
    echo ========================================
) else (
    echo.
    echo Database deployment failed!
    echo Please check the error messages above.
)

echo.
pause