@echo off
setlocal enabledelayedexpansion

set "ACTION=%1"
if "%ACTION%"=="" set "ACTION=start"

if "%ACTION%"=="start" goto start_servers
if "%ACTION%"=="stop" goto stop_servers
if "%ACTION%"=="restart" goto restart_servers
if "%ACTION%"=="status" goto show_status
if "%ACTION%"=="backend" goto start_backend
if "%ACTION%"=="frontend" goto start_frontend
if "%ACTION%"=="restart-backend" goto restart_backend
if "%ACTION%"=="restart-frontend" goto restart_frontend
if "%ACTION%"=="stop-backend" goto stop_backend
if "%ACTION%"=="stop-frontend" goto stop_frontend
goto show_help

:start_servers
echo Starting Ecommerce Platform...
java -version >nul 2>&1 || (echo Java not found & exit /b 1)
node --version >nul 2>&1 || (echo Node.js not found & exit /b 1)
mvn --version >nul 2>&1 || (echo Maven not found & exit /b 1)

call :stop_backend
call :stop_frontend

echo Starting Backend...
cd backend
start /min "" cmd /c "mvn spring-boot:run > ../backend.log 2>&1"
cd ..

timeout /t 3 >nul

echo Starting Frontend...
cd frontend
if not exist node_modules npm install >nul 2>&1
start /min "" cmd /c "npm start > ../frontend.log 2>&1"
cd ..

echo Both servers starting in background
echo Backend: http://localhost:8080
echo Frontend: http://localhost:3000
goto end

:stop_servers
call :stop_backend
call :stop_frontend
echo All servers stopped
goto end

:restart_servers
call :stop_servers
timeout /t 2 >nul
goto start_servers

:start_backend
echo Starting Backend Server...
call :stop_backend
cd backend
start /min "" cmd /c "mvn spring-boot:run > ../backend.log 2>&1"
cd ..
echo Backend starting: http://localhost:8080
goto end

:start_frontend
echo Starting Frontend Server...
call :stop_frontend
cd frontend
if not exist node_modules npm install >nul 2>&1
start /min "" cmd /c "npm start > ../frontend.log 2>&1"
cd ..
echo Frontend starting: http://localhost:3000
goto end

:restart_backend
call :stop_backend
timeout /t 2 >nul
goto start_backend

:restart_frontend
call :stop_frontend
timeout /t 2 >nul
goto start_frontend

:stop_backend
for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":8080"') do taskkill /PID %%a /F >nul 2>&1
exit /b

:stop_frontend
for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":3000"') do taskkill /PID %%a /F >nul 2>&1
exit /b

:show_status
echo Server Status:
netstat -an 2>nul | findstr ":8080 " | findstr "LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo Backend:  RUNNING on http://localhost:8080
) else (
    echo Backend:  NOT RUNNING
)

netstat -an 2>nul | findstr ":3000 " | findstr "LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo Frontend: RUNNING on http://localhost:3000
) else (
    echo Frontend: NOT RUNNING
)
goto end

:show_help
echo Usage: %~nx0 [start^|stop^|restart^|status^|backend^|frontend^|restart-backend^|restart-frontend^|stop-backend^|stop-frontend]
echo   start            - Start both servers
echo   stop             - Stop both servers
echo   restart          - Restart both servers
echo   status           - Show server status
echo   backend          - Start only backend
echo   frontend         - Start only frontend
echo   restart-backend  - Restart only backend
echo   restart-frontend - Restart only frontend
echo   stop-backend     - Stop only backend
echo   stop-frontend    - Stop only frontend

:end