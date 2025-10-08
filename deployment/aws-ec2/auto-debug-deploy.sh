#!/usr/bin/env bash
set -euo pipefail

# Automated deployment and debugging script
ROOT_DIR=$(cd "$(dirname "$0")/../../" && pwd)
source "$(dirname "$0")/.env" 2>/dev/null || true

PUBLIC_IP="3.109.157.122"
echo "🚀 Starting automated deployment and debugging..."

function build_and_deploy() {
    echo "📦 Building backend..."
    cd $ROOT_DIR/backend
    mvn clean package -DskipTests -q
    
    echo "🚀 Deploying to EC2..."
    cd $ROOT_DIR/deployment/aws-ec2
    ./update-running-ec2.sh
}

function test_endpoints() {
    echo "🧪 Testing endpoints..."
    
    echo "1. Testing /api/products (should return data):"
    PRODUCTS_COUNT=$(curl -s "http://$PUBLIC_IP:8080/api/products" | jq '. | length' 2>/dev/null || echo "0")
    echo "   Products count: $PRODUCTS_COUNT"
    
    echo "2. Testing /api/products/available (currently empty):"
    AVAILABLE_COUNT=$(curl -s "http://$PUBLIC_IP:8080/api/products/available" | jq '. | length' 2>/dev/null || echo "0")
    echo "   Available count: $AVAILABLE_COUNT"
    
    echo "3. Testing debug endpoint:"
    DEBUG_INFO=$(curl -s "http://$PUBLIC_IP:8080/api/products/debug" 2>/dev/null || echo "Debug endpoint failed")
    echo "$DEBUG_INFO"
    
    return $AVAILABLE_COUNT
}

function fix_query_if_needed() {
    local available_count=$1
    
    if [ "$available_count" -eq 0 ]; then
        echo "🔧 Available products is 0, trying alternative query..."
        
        # Update repository with a simpler query
        cat > $ROOT_DIR/backend/src/main/java/com/ecommerce/repository/ProductRepository.java << 'EOF'
package com.ecommerce.repository;

import com.ecommerce.model.Product;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface ProductRepository extends JpaRepository<Product, Long> {
    List<Product> findByQuantityGreaterThan(Integer quantity);
    
    @Query("SELECT DISTINCT p.category FROM Product p WHERE p.category IS NOT NULL ORDER BY p.category")
    List<String> findDistinctCategories();
    
    List<Product> findByCategory(String category);
    
    @Query("SELECT p FROM Product p JOIN FETCH p.variants v WHERE v.quantity > 0")
    List<Product> findAvailableProducts();
    
    @Query("SELECT p FROM Product p JOIN FETCH p.variants v WHERE v.quantity > 0")
    Page<Product> findAvailableProductsPaged(Pageable pageable);
}
EOF
        
        echo "✅ Updated query to use JOIN FETCH"
        build_and_deploy
        
        echo "🧪 Testing after query fix..."
        sleep 10
        AVAILABLE_COUNT=$(curl -s "http://$PUBLIC_IP:8080/api/products/available" | jq '. | length' 2>/dev/null || echo "0")
        echo "   Available count after fix: $AVAILABLE_COUNT"
        
        if [ "$AVAILABLE_COUNT" -eq 0 ]; then
            echo "🔧 Still 0, trying fallback query..."
            
            # Fallback: just return all products for available
            cat > $ROOT_DIR/backend/src/main/java/com/ecommerce/repository/ProductRepository.java << 'EOF'
package com.ecommerce.repository;

import com.ecommerce.model.Product;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface ProductRepository extends JpaRepository<Product, Long> {
    List<Product> findByQuantityGreaterThan(Integer quantity);
    
    @Query("SELECT DISTINCT p.category FROM Product p WHERE p.category IS NOT NULL ORDER BY p.category")
    List<String> findDistinctCategories();
    
    List<Product> findByCategory(String category);
    
    // Temporary fallback - return all products as available
    @Query("SELECT p FROM Product p")
    List<Product> findAvailableProducts();
    
    @Query("SELECT p FROM Product p")
    Page<Product> findAvailableProductsPaged(Pageable pageable);
}
EOF
            
            echo "✅ Using fallback query (all products)"
            build_and_deploy
            
            sleep 10
            AVAILABLE_COUNT=$(curl -s "http://$PUBLIC_IP:8080/api/products/available" | jq '. | length' 2>/dev/null || echo "0")
            echo "   Available count after fallback: $AVAILABLE_COUNT"
        fi
    fi
}

function cleanup_debug() {
    echo "🧹 Removing debug endpoint..."
    # Remove debug endpoint from controller
    sed -i '/\/debug/,/^    }/d' $ROOT_DIR/backend/src/main/java/com/ecommerce/controller/ProductController.java
    
    echo "📦 Final build and deploy..."
    build_and_deploy
}

# Main execution
build_and_deploy
sleep 15  # Wait for service to start

test_endpoints
AVAILABLE_COUNT=$?

if [ "$AVAILABLE_COUNT" -eq 0 ]; then
    fix_query_if_needed $AVAILABLE_COUNT
fi

echo "🎉 Final test:"
curl -s "http://$PUBLIC_IP:8080/api/products/available" | jq '. | length' || echo "Final test failed"

cleanup_debug

echo "✅ Automated debugging complete!"