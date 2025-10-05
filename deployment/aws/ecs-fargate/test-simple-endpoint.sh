#!/bin/bash

# Test Simple Endpoint Without Database

IP="13.232.216.165"

echo "🔍 Testing simple endpoints..."

# Test Spring Boot actuator health (if enabled)
echo "Testing /actuator/health:"
curl -m 5 "http://$IP:8080/actuator/health" 2>/dev/null || echo "Not available"

# Test error endpoint (should work without DB)
echo "Testing /error:"
curl -m 5 "http://$IP:8080/error" 2>/dev/null || echo "Not available"

# Test non-existent endpoint (should return 404)
echo "Testing /nonexistent:"
curl -m 5 "http://$IP:8080/nonexistent" 2>/dev/null || echo "Not available"

# Test with verbose output
echo "Testing with verbose output:"
curl -v -m 5 "http://$IP:8080/" 2>&1 | head -10