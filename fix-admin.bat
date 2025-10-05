@echo off
set PGPATH="C:\Program Files\PostgreSQL\17\bin"

echo Fixing admin password...
%PGPATH%\psql.exe -U postgres -d ecommerce_db -f fix-admin-password.sql

echo.
echo Admin credentials:
echo Username: admin
echo Password: admin123
echo.
pause