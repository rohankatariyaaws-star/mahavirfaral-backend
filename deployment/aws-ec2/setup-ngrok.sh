#!/bin/bash
# Install ngrok for HTTPS tunnel
curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo yum install -y ngrok

echo "1. Sign up at https://ngrok.com"
echo "2. Get your auth token"
echo "3. Run: ngrok config add-authtoken YOUR_TOKEN"
echo "4. Run: ngrok http 8080"
echo "5. Use the https://xxx.ngrok.io URL in your frontend"