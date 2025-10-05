# Ecommerce Platform - Complete Documentation

## Project Overview
A full-stack ecommerce platform built with React frontend and Spring Boot backend, featuring role-based access control for Admin, User, and Supervisor roles.

## Architecture

### Backend (Spring Boot)
- **Framework**: Spring Boot 3.2.0
- **Database**: PostgreSQL
- **Security**: JWT Authentication
- **Build Tool**: Maven

### Frontend (React)
- **Framework**: React 18
- **UI Library**: Material-UI (MUI)
- **Routing**: React Router
- **HTTP Client**: Axios
- **Charts**: Chart.js with react-chartjs-2

## User Roles & Permissions

### Admin
- Manage products (CRUD operations)
- Manage users and roles
- View analytics dashboard
- Approve/reject material orders
- Manage store locations

### User
- Browse and search products
- Add items to cart and wishlist
- Place orders and generate bills
- View order history
- Manage profile and addresses

### Supervisor
- Create orders for customers
- Manage material orders (with approval workflow)
- View and update order statuses
- Access supervisor-specific analytics

## Key Features

### Authentication & Authorization
- JWT-based authentication
- Role-based access control
- Protected routes
- Token expiration handling

### Product Management
- Product variants with different sizes and prices
- Category management
- Inventory tracking
- Image support

### Order Management
- Complete order lifecycle
- Status tracking (PENDING → CONFIRMED → PROCESSING → SHIPPED → DELIVERED)
- Order filtering and search
- Auto-refresh functionality (every 1 minute)

### Material Management (Supervisor → Admin Approval)
- Supervisors create material orders
- Admin approval workflow
- Edit capability (only for pending materials)
- Status tracking (PENDING → APPROVED/REJECTED)

### Analytics Dashboard
- Order statistics and trends
- Revenue analysis
- Material cost tracking
- Interactive charts and graphs
- Time-based filtering

### Shopping Cart & Checkout
- Add/remove items
- Quantity management
- Price calculations
- Bill generation with PDF export

## Database Schema

### Core Tables
- `users` - User accounts and roles
- `products` - Product catalog
- `product_variants` - Size/price variations
- `orders` - Order information
- `order_items` - Order line items
- `materials` - Material orders with approval status
- `cart_items` - Shopping cart
- `wishlist` - User wishlists
- `stores` - Store locations
- `user_addresses` - User addresses
- `user_preferences` - User settings

### Key Relationships
- Users → Orders (1:N)
- Orders → OrderItems (1:N)
- Products → ProductVariants (1:N)
- Users → Materials (Supervisor relationship)
- Users → CartItems (1:N)

## API Endpoints

### Authentication
- `POST /api/auth/login` - User login
- `POST /api/auth/signup` - User registration

### Products
- `GET /api/products/all` - Get all products
- `GET /api/products/available` - Get available products
- `POST /api/products` - Create product (Admin)
- `PUT /api/products/{id}` - Update product (Admin)
- `DELETE /api/products/{id}` - Delete product (Admin)

### Orders
- `GET /api/orders/all` - Get all orders
- `GET /api/orders/user/{username}` - Get user orders
- `POST /api/orders` - Create order
- `PUT /api/orders/{id}/status` - Update order status

### Materials
- `POST /api/supervisor/materials` - Create material order
- `GET /api/supervisor/materials` - Get all materials
- `PUT /api/supervisor/materials/{id}` - Update material (if pending)
- `PUT /api/admin/materials/{id}/approve` - Approve material
- `PUT /api/admin/materials/{id}/reject` - Reject material

### Cart
- `POST /api/cart/add` - Add to cart
- `GET /api/cart/{username}` - Get user cart
- `DELETE /api/cart/{id}` - Remove from cart
- `DELETE /api/cart/clear/{username}` - Clear cart

## Frontend Components Structure

### Pages
- `Login/Signup` - Authentication
- `AdminDashboard` - Admin overview
- `AdminProducts` - Product management
- `AdminUsers` - User management
- `AdminAnalytics` - Charts and insights
- `AdminMaterials` - Material approval
- `UserDashboard` - User home
- `SupervisorDashboard` - Supervisor overview
- `SupervisorProducts` - Customer order creation
- `SupervisorOrders` - Order management
- `Cart` - Shopping cart
- `OrderHistory` - Order tracking
- `Profile` - User settings

### Key Components
- `Navbar` - Navigation with role-based menus
- `ProtectedRoute` - Route protection
- `AuthChecker` - Token validation
- Various form components and dialogs

## Configuration

### Backend Configuration (application.yml)
```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/ecommerce_db
    username: postgres
    password: root
  jpa:
    hibernate:
      ddl-auto: update
    show-sql: true

jwt:
  secret: myVerySecureSecretKeyThatIsLongEnoughForJWTHMACSHA256Algorithm
  expiration: 86400000

server:
  port: 8080
```

### Frontend Configuration
- Base API URL: `http://localhost:8080/api`
- Development server: `http://localhost:3000`

## Setup Instructions

### Prerequisites
- Java 17+
- Node.js 16+
- PostgreSQL 12+
- Maven 3.6+

### Database Setup
1. Create PostgreSQL database: `ecommerce_db`
2. Run the database setup script: `database-setup.sql`
3. Update database credentials in `application.yml`

### Backend Setup
```bash
cd backend
mvn clean install
mvn spring-boot:run
```

### Frontend Setup
```bash
cd frontend
npm install
npm start
```

## Default Credentials
- **Admin**: username: `admin`, password: `admin123`

## Development Notes

### Code Organization
- Backend follows MVC pattern with clear separation
- Frontend uses functional components with hooks
- Context providers for global state management
- Custom hooks for API calls and data management

### Security Features
- JWT token validation on all protected routes
- Role-based access control at component level
- CORS configuration for cross-origin requests
- Input validation and sanitization

### Performance Optimizations
- Database indexing on frequently queried fields
- React component memoization where appropriate
- Efficient state management with contexts
- Optimized API calls with proper error handling

### Mobile Responsiveness
- Material-UI responsive grid system
- Mobile-first design approach
- Touch-friendly interface elements
- Responsive typography and spacing

## Troubleshooting

### Common Issues
1. **Port 8080 already in use**: Stop existing processes or change port
2. **Database connection errors**: Verify PostgreSQL is running and credentials are correct
3. **JWT token expired**: Clear localStorage and re-login
4. **CORS errors**: Verify backend CORS configuration

### Database Issues
- Run `update-materials-table.sql` for material approval features
- Check database constraints if order status updates fail
- Verify foreign key relationships are properly set up

## Future Enhancements
- Payment gateway integration
- Email notifications
- Advanced search and filtering
- Inventory alerts
- Multi-language support
- Mobile app development
- Advanced analytics and reporting

## Technology Stack Summary
- **Backend**: Spring Boot, Spring Security, JPA/Hibernate, PostgreSQL
- **Frontend**: React, Material-UI, React Router, Axios, Chart.js
- **Authentication**: JWT
- **Database**: PostgreSQL with proper indexing
- **Build Tools**: Maven (backend), npm (frontend)
- **Development**: Hot reload, debugging support, comprehensive logging