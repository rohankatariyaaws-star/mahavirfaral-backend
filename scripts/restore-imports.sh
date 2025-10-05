#!/bin/bash

echo "🔧 Restoring missing Spring Boot imports..."

# Navigate to backend directory
cd ../backend/src/main/java/com/ecommerce

# Add missing imports to controller files
for file in controller/*.java; do
    if ! grep -q "import org.springframework.web.bind.annotation" "$file"; then
        sed -i '2i import org.springframework.web.bind.annotation.*;' "$file"
    fi
    if ! grep -q "import org.springframework.http" "$file"; then
        sed -i '2i import org.springframework.http.*;' "$file"
    fi
done

# Add missing imports to model files
for file in model/*.java; do
    if ! grep -q "import javax.persistence" "$file"; then
        sed -i '2i import javax.persistence.*;' "$file"
    fi
done

echo "✅ Imports restored"