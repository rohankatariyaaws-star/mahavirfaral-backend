@echo off

echo Stopping servers...

for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8080"') do (
    taskkill /PID %%a /F >nul 2>&1
)

for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":3000"') do (
    taskkill /PID %%a /F >nul 2>&1
)

echo Servers stopped