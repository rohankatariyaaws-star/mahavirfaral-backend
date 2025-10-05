# Ecommerce Platform

A full-stack ecommerce platform built with React frontend and Spring Boot backend.

## Features

### User Roles
- **Admin**: Manage products and users
- **User**: Browse products, add to cart, generate bills
- **Supervisor**: Manage material orders

### Functionalities
1. User authentication (login/signup)
2. Product management (CRUD operations)
3. Shopping cart functionality
4. Bill generation with PDF export
5. Material order management
6. User management

## Tech Stack

### Backend
- Java Spring Boot
- Spring Security with JWT
- PostgreSQL
- Maven

### Frontend
- React 18
- Material-UI
- React Router
- Axios
- jsPDF for PDF generation

## Setup Instructions

### Prerequisites
- Java 17+
- Node.js 16+
- PostgreSQL 12+
- Maven 3.6+

### Database Setup
1. Install PostgreSQL and create a database:
```sql
CREATE DATABASE ecommerce_db;
```

2. Run the database setup script:
```bash
psql -U postgres -d ecommerce_db -f database-setup.sql
```

3. Update database credentials in `backend/src/main/resources/application.yml`

### Backend Setup
1. Navigate to backend directory:
```bash
cd backend
```

2. Install dependencies and run:
```bash
mvn clean install
mvn spring-boot:run
```

The backend will start on `http://localhost:8080`

### Frontend Setup
1. Navigate to frontend directory:
```bash
cd frontend
```

2. Install dependencies:
```bash
npm install
```

3. Start the development server:
```bash
npm start
```

The frontend will start on `http://localhost:3000`

## Default Credentials

### Admin Login
- Username: `admin`
- Password: `admin123`

## API Endpoints

### Authentication
- POST `/api/auth/login` - User login
- POST `/api/auth/signup` - User registration

### Products
- GET `/api/products/all` - Get all products
- GET `/api/products/available` - Get available products
- POST `/api/products` - Create product (Admin only)
- PUT `/api/products/{id}` - Update product (Admin only)
- DELETE `/api/products/{id}` - Delete product (Admin only)

### Cart
- POST `/api/cart/add` - Add item to cart
- GET `/api/cart/{username}` - Get user's cart
- DELETE `/api/cart/{id}` - Remove item from cart
- DELETE `/api/cart/clear/{username}` - Clear cart

### Admin
- GET `/api/admin/users` - Get all users
- DELETE `/api/admin/users/{id}` - Delete user
- PUT `/api/admin/users/{id}/role` - Update user role

### Materials (Supervisor)
- POST `/api/supervisor/materials` - Add material order
- GET `/api/supervisor/materials` - Get all materials
- GET `/api/supervisor/materials/{username}` - Get materials by supervisor
- DELETE `/api/supervisor/materials/{id}` - Delete material

## Usage

1. **Admin Functions**:
   - Login with admin credentials
   - Add/edit/delete products
   - Manage user accounts and roles

2. **User Functions**:
   - Register new account or login
   - Browse available products
   - Add products to cart
   - Generate and print bills as PDF

3. **Supervisor Functions**:
   - Login with supervisor account
   - Add material orders with costs
   - View material order history

## Project Structure

```
ecommerce/
├── backend/
│   ├── src/main/java/com/ecommerce/
│   │   ├── controller/     # REST controllers
│   │   ├── service/        # Business logic
│   │   ├── repository/     # Data access layer
│   │   ├── model/          # Entity classes
│   │   ├── dto/            # Data transfer objects
│   │   └── config/         # Configuration classes
│   └── src/main/resources/
│       └── application.yml # Application configuration
├── frontend/
│   ├── src/
│   │   ├── components/     # Reusable components
│   │   ├── pages/          # Page components
│   │   ├── services/       # API services
│   │   └── utils/          # Utility functions
│   └── public/
└── database-setup.sql      # Database initialization script
```