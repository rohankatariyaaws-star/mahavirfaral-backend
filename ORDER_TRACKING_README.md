# Order Tracking System

## Overview
This comprehensive order tracking system ensures all order details are properly captured and preserved, including user information, shipping addresses, product details with prices at the time of order, and complete order history.

## Key Features

### 1. Frozen Order Data
- **User Details**: Name, email, phone number captured at order time
- **Shipping Address**: Complete address details frozen at order time
- **Product Information**: Product name, description, price, size, category preserved
- **Pricing**: Unit prices and totals locked at order placement

### 2. Comprehensive Order Information
- Unique order number generation
- Order status tracking (PENDING, CONFIRMED, PROCESSING, SHIPPED, DELIVERED, CANCELLED)
- Subtotal, tax, shipping cost, and total amount calculation
- Payment method tracking
- Order notes and special instructions

### 3. Order History
- Complete order history with all details
- Expandable sections for items and shipping information
- Status-based color coding
- Detailed pricing breakdown

## Database Schema

### Orders Table
```sql
- id (Primary Key)
- username
- order_number (Unique)
- user_full_name, user_email, user_phone (Frozen user data)
- shipping_address_line1, shipping_address_line2, shipping_city, shipping_state, shipping_zip_code, shipping_phone
- subtotal, tax, shipping_cost, total_amount
- status (ENUM)
- order_date, updated_at
- payment_method, notes
```

### Order Items Table
```sql
- id (Primary Key)
- order_id (Foreign Key)
- product_id (Reference to original product)
- product_name, product_description, product_image_url, product_size, product_category (Frozen product data)
- unit_price, quantity, total_price (Frozen pricing)
```

## API Endpoints

### Create Order
```
POST /api/orders
{
  "username": "user123",
  "addressId": 1,
  "items": [
    {
      "productId": 1,
      "quantity": 2
    }
  ],
  "paymentMethod": "Cash on Delivery",
  "notes": "Leave at door",
  "shippingCost": 5.99
}
```

### Get User Orders
```
GET /api/orders/user/{username}
```

### Get Order Details
```
GET /api/orders/{orderId}
```

### Update Order Status
```
PUT /api/orders/{orderId}/status?status=SHIPPED
```

## Setup Instructions

### 1. Run Database Migration
```bash
# Windows
run-order-migration.bat

# Linux/Mac
psql -U postgres -d ecommerce_db -f update-orders-schema.sql
```

### 2. Backend Changes
- New models: `Order`, `OrderItem`
- Updated DTOs: `CreateOrderRequest`, `OrderResponse`
- Enhanced services: `OrderService`
- Updated controllers: `OrderController`

### 3. Frontend Changes
- Updated `OrderHistory.js` with comprehensive order display
- Updated `Cart.js` to use new order creation API
- Enhanced order details with expandable sections

## Benefits

1. **Price Protection**: Customers see the exact prices they paid, even if product prices change later
2. **Complete Audit Trail**: Full order history with all details preserved
3. **Customer Service**: Support team has access to complete order information
4. **Compliance**: Proper record keeping for business and tax purposes
5. **User Experience**: Customers can view detailed order history with all information

## Order Status Flow

1. **PENDING**: Order created, awaiting confirmation
2. **CONFIRMED**: Order confirmed, ready for processing
3. **PROCESSING**: Order being prepared
4. **SHIPPED**: Order dispatched for delivery
5. **DELIVERED**: Order successfully delivered
6. **CANCELLED**: Order cancelled

## Usage Examples

### Creating an Order
When a user places an order, the system:
1. Captures current user details from the User table
2. Captures selected shipping address details
3. Creates OrderItem records with current product details and prices
4. Calculates totals and generates unique order number
5. Saves complete order with all frozen data

### Viewing Order History
Users can view:
- Complete order list with status and totals
- Detailed order information including all items
- Original prices paid for each item
- Shipping address used for the order
- Order timeline and status updates

This system ensures complete order tracking and provides excellent customer service capabilities while protecting both the business and customers with accurate historical data.