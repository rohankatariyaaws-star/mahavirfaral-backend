#!/bin/bash

ACTION=${1:-start}

print_status() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
print_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
print_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

check_port() {
    lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1
}

kill_port() {
    local pid=$(lsof -ti:$1 2>/dev/null)
    if [ ! -z "$pid" ]; then
        kill -9 $pid 2>/dev/null
    fi
}

start_servers() {
    print_status "Starting Ecommerce Platform..."
    
    # Check prerequisites
    if ! command -v java &> /dev/null; then
        print_error "Java not found. Install Java 17+"
        exit 1
    fi
    
    if ! command -v node &> /dev/null; then
        print_error "Node.js not found. Install Node.js 16+"
        exit 1
    fi
    
    if ! command -v mvn &> /dev/null; then
        print_error "Maven not found. Install Maven 3.6+"
        exit 1
    fi
    
    print_success "Prerequisites: OK"
    
    # Kill existing processes
    kill_port 8080
    kill_port 3000
    
    # Start Backend
    print_status "Starting Backend Server..."
    cd backend
    nohup mvn spring-boot:run > ../backend.log 2>&1 &
    echo $! > ../backend.pid
    cd ..
    
    # Wait for backend
    sleep 5
    
    # Start Frontend
    print_status "Starting Frontend Server..."
    cd frontend
    if [ ! -d "node_modules" ]; then
        print_status "Installing dependencies..."
        npm install >/dev/null 2>&1
    fi
    nohup npm start > ../frontend.log 2>&1 &
    echo $! > ../frontend.pid
    cd ..
    
    # Wait and verify
    print_status "Waiting for servers to start..."
    local attempts=0
    local backend_started=0
    local frontend_started=0
    
    while [ $attempts -lt 30 ]; do
        if check_port 8080; then
            backend_started=1
        fi
        
        if check_port 3000; then
            frontend_started=1
        fi
        
        if [ $backend_started -eq 1 ] && [ $frontend_started -eq 1 ]; then
            print_success "Both servers are running!"
            echo "Backend:  http://localhost:8080"
            echo "Frontend: http://localhost:3000"
            echo ""
            echo "Logs: backend.log, frontend.log"
            echo "Use './start-servers.sh stop' to stop servers"
            exit 0
        fi
        
        sleep 2
        ((attempts++))
    done
    
    print_error "Servers may still be starting. Check logs: backend.log, frontend.log"
}

stop_servers() {
    print_status "Stopping servers..."
    
    # Kill by PID if available
    if [ -f "backend.pid" ]; then
        kill $(cat backend.pid) 2>/dev/null
        rm -f backend.pid
    fi
    
    if [ -f "frontend.pid" ]; then
        kill $(cat frontend.pid) 2>/dev/null
        rm -f frontend.pid
    fi
    
    # Kill by port
    kill_port 8080
    kill_port 3000
    
    print_success "Servers stopped"
}

start_backend() {
    print_status "Starting Backend Server..."
    kill_port 8080
    if [ -f "backend.pid" ]; then
        kill $(cat backend.pid) 2>/dev/null
        rm -f backend.pid
    fi
    
    cd backend
    nohup mvn spring-boot:run > ../backend.log 2>&1 &
    echo $! > ../backend.pid
    cd ..
    
    local attempts=0
    while [ $attempts -lt 30 ]; do
        if check_port 8080; then
            print_success "Backend started: http://localhost:8080"
            return 0
        fi
        sleep 2
        ((attempts++))
    done
    print_error "Backend failed to start"
}

start_frontend() {
    print_status "Starting Frontend Server..."
    kill_port 3000
    if [ -f "frontend.pid" ]; then
        kill $(cat frontend.pid) 2>/dev/null
        rm -f frontend.pid
    fi
    
    cd frontend
    if [ ! -d "node_modules" ]; then
        print_status "Installing dependencies..."
        npm install >/dev/null 2>&1
    fi
    nohup npm start > ../frontend.log 2>&1 &
    echo $! > ../frontend.pid
    cd ..
    
    local attempts=0
    while [ $attempts -lt 30 ]; do
        if check_port 3000; then
            print_success "Frontend started: http://localhost:3000"
            return 0
        fi
        sleep 2
        ((attempts++))
    done
    print_error "Frontend failed to start"
}

stop_backend() {
    print_status "Stopping Backend Server..."
    if [ -f "backend.pid" ]; then
        kill $(cat backend.pid) 2>/dev/null
        rm -f backend.pid
    fi
    kill_port 8080
    print_success "Backend stopped"
}

stop_frontend() {
    print_status "Stopping Frontend Server..."
    if [ -f "frontend.pid" ]; then
        kill $(cat frontend.pid) 2>/dev/null
        rm -f frontend.pid
    fi
    kill_port 3000
    print_success "Frontend stopped"
}

show_status() {
    print_status "Server Status:"
    
    if check_port 8080; then
        print_success "Backend:  RUNNING on http://localhost:8080"
    else
        print_error "Backend:  NOT RUNNING"
    fi
    
    if check_port 3000; then
        print_success "Frontend: RUNNING on http://localhost:3000"
    else
        print_error "Frontend: NOT RUNNING"
    fi
}

case "$ACTION" in
    "start")
        start_servers
        ;;
    "stop")
        stop_servers
        ;;
    "status")
        show_status
        ;;
    "restart")
        stop_servers
        sleep 2
        start_servers
        ;;
    "backend")
        start_backend
        ;;
    "frontend")
        start_frontend
        ;;
    "restart-backend")
        stop_backend
        sleep 2
        start_backend
        ;;
    "restart-frontend")
        stop_frontend
        sleep 2
        start_frontend
        ;;
    "stop-backend")
        stop_backend
        ;;
    "stop-frontend")
        stop_frontend
        ;;
    *)
        echo "Usage: $0 [start|stop|restart|status|backend|frontend|restart-backend|restart-frontend|stop-backend|stop-frontend]"
        echo "  start            - Start both servers"
        echo "  stop             - Stop both servers"
        echo "  restart          - Restart both servers"
        echo "  status           - Show server status"
        echo "  backend          - Start only backend"
        echo "  frontend         - Start only frontend"
        echo "  restart-backend  - Restart only backend"
        echo "  restart-frontend - Restart only frontend"
        echo "  stop-backend     - Stop only backend"
        echo "  stop-frontend    - Stop only frontend"
        exit 1
        ;;
esac