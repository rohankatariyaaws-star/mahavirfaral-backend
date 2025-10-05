@echo off
cd backend
echo Cleaning and rebuilding backend...
mvn clean install -DskipTests
echo Backend rebuild complete!
pause