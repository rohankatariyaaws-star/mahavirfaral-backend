@echo off
echo Updating backend on EC2...

set EC2_IP=65.2.74.13
set KEY_FILE=mahavirfaral-ec2-key.pem
set JAR_FILE=..\..\backend\target\ecommerce-backend-1.0.0.jar

echo Copying new JAR to EC2...
scp -i %KEY_FILE% -o StrictHostKeyChecking=no %JAR_FILE% ec2-user@%EC2_IP%:/home/ec2-user/app-new.jar

echo Stopping backend service...
ssh -i %KEY_FILE% -o StrictHostKeyChecking=no ec2-user@%EC2_IP% "sudo pkill -f 'java -jar'"

echo Backing up current JAR...
ssh -i %KEY_FILE% -o StrictHostKeyChecking=no ec2-user@%EC2_IP% "cp /home/ec2-user/app.jar /home/ec2-user/app-backup.jar"

echo Replacing JAR...
ssh -i %KEY_FILE% -o StrictHostKeyChecking=no ec2-user@%EC2_IP% "mv /home/ec2-user/app-new.jar /home/ec2-user/app.jar"

echo Starting backend service...
ssh -i %KEY_FILE% -o StrictHostKeyChecking=no ec2-user@%EC2_IP% "nohup java -jar /home/ec2-user/app.jar > /home/ec2-user/backend.log 2>&1 &"

echo Waiting 15 seconds for service to start...
timeout /t 15

echo Testing API...
curl http://%EC2_IP%:8080/api/health

echo.
echo Backend updated! Testing order API...
echo.