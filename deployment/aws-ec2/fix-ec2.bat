@echo off
echo Starting backend service on EC2...

ssh -i mahavirfaral-ec2-key.pem -o StrictHostKeyChecking=no ec2-user@65.2.74.13 "nohup java -jar /home/ec2-user/app.jar > /home/ec2-user/backend.log 2>&1 &"

echo Waiting 10 seconds for service to start...
timeout /t 10

echo Testing connection...
curl http://65.2.74.13:8080/api/health

echo.
echo Backend should be accessible at:
echo http://65.2.74.13:8080
echo.
echo If still not working, check logs with:
echo ssh -i mahavirfaral-ec2-key.pem ec2-user@65.2.74.13 "tail -f /home/ec2-user/backend.log"