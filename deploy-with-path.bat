@echo off
set PGPATH="C:\Program Files\PostgreSQL\17\bin"
set PATH=%PGPATH%;%PATH%

echo Deploying Ecommerce Database...
echo.

REM Create database if it doesn't exist
%PGPATH%\createdb.exe -U postgres ecommerce_db 2>nul
if %errorlevel% equ 0 (
    echo Database 'ecommerce_db' created successfully.
) else (
    echo Database 'ecommerce_db' already exists or creation failed.
)

echo.
echo Running deployment script...
%PGPATH%\psql.exe -U postgres -d ecommerce_db -f deploy-database.sql

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo Database deployment completed successfully!
    echo ========================================
    echo IMPORTANT: After starting the backend, run:
    echo curl -X POST http://localhost:8080/api/auth/create-admin
    echo.
    echo This will create admin user with:
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