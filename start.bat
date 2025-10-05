@echo off

echo Checking prerequisites...
java -version >nul 2>&1 || (echo Java not found & exit /b 1)
node --version >nul 2>&1 || (echo Node.js not found & exit /b 1)
mvn --version >nul 2>&1 || (echo Maven not found & exit /b 1)

echo Starting Backend...
cd backend
start "Backend" cmd /k "mvn spring-boot:run"
cd ..

echo Starting Frontend...
cd frontend
start "Frontend" cmd /k "npm start"
cd ..

echo Both servers starting in separate windows
echo Backend: http://localhost:8080
echo Frontend: http://localhost:3000