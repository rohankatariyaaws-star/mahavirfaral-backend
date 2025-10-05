#!/bin/bash

# Simple Container Test

PUBLIC_IP="13.200.221.156"

echo "🔍 Simple Container Tests for $PUBLIC_IP"

# Test if port 8080 is open
echo ""
echo "1. Testing if port 8080 is listening..."
timeout 5 bash -c "</dev/tcp/$PUBLIC_IP/8080" && echo "✅ Port 8080 is open" || echo "❌ Port 8080 is closed or filtered"

# Test with telnet-like connection
echo ""
echo "2. Testing raw TCP connection..."
nc -z -w5 $PUBLIC_IP 8080 && echo "✅ TCP connection successful" || echo "❌ TCP connection failed"

# Test with different HTTP methods
echo ""
echo "3. Testing HTTP methods..."

# Test with verbose curl
echo "GET request:"
curl -v --connect-timeout 10 --max-time 15 http://$PUBLIC_IP:8080/ 2>&1 | head -10

echo ""
echo "HEAD request:"
curl -I --connect-timeout 10 --max-time 15 http://$PUBLIC_IP:8080/ 2>&1 | head -5

# Test if it's a different port
echo ""
echo "4. Testing other common ports..."
for port in 80 443 8000 8081 9000; do
    timeout 3 bash -c "</dev/tcp/$PUBLIC_IP/$port" && echo "✅ Port $port is open" || echo "❌ Port $port is closed"
done

# Test with wget
echo ""
echo "5. Testing with wget..."
timeout 10 wget -O- http://$PUBLIC_IP:8080/ 2>&1 | head -5

echo ""
echo "💡 If all tests fail, the container might not be running Java properly"