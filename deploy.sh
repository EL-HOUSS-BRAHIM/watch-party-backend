#!/bin/bash

# Watch Party Backend Deployment Script
# This script manages PM2, Nginx, and SSL configurations for the watch-party backend
# Domain: https://be-watch-party.brahim-elhouss.me (backend)
# Frontend: https://watch-party.brahim-elhouss.me (frontend)

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="/workspaces/watch-party-backend"
BACKEND_DOMAIN="be-watch-party.brahim-elhouss.me"
FRONTEND_DOMAIN="watch-party.brahim-elhouss.me"
LOG_DIR="/var/log/watchparty"
STATIC_DIR="/var/www/watchparty"
NGINX_SITES="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
NGINX_CONFIG_NAME="watchparty-backend"
SSL_CERT_PATH="/etc/ssl/certs"
SSL_KEY_PATH="/etc/ssl/private"

# Non-interactive behavior: set AUTO_CONFIRM=1 to auto-answer prompts with sensible defaults.
# Set RUN_ACTION to a number 0-6 to run a specific menu action non-interactively and exit.
AUTO_CONFIRM=${AUTO_CONFIRM:-0}
RUN_ACTION=${RUN_ACTION:-}

# Helper to conditionally prompt (uses AUTO_CONFIRM)
conditional_read() {
    # Usage: conditional_read varname prompt default
    local __varname="$1"
    local __prompt="$2"
    local __default="$3"

    if [ "$AUTO_CONFIRM" -eq 1 ]; then
        # Set REPLY to default (if provided) otherwise 'y' for yes-like prompts
        if [ -z "$__default" ]; then
            REPLY='y'
        else
            REPLY="$__default"
        fi
    else
        read -p "$__prompt" -n 1 -r
        echo
    fi
    eval $__varname='"$REPLY"'
}

# If RUN_ACTION is set, execute that action and exit (non-interactive helpers can call functions directly)
if [ -n "$RUN_ACTION" ]; then
    if [[ "$RUN_ACTION" =~ ^[0-6]$ ]]; then
        case $RUN_ACTION in
            1)
                init_pm2
                exit 0
                ;;
            2)
                install_nginx_http
                exit 0
                ;;
            3)
                install_nginx_https
                exit 0
                ;;
            4)
                test_nginx_config
                exit 0
                ;;
            5)
                stop_services
                exit 0
                ;;
            6)
                show_status
                exit 0
                ;;
            0)
                print_status "Exiting via RUN_ACTION"
                exit 0
                ;;
        esac
    else
        print_warning "RUN_ACTION must be a number 0-6. Ignoring."
    fi
fi

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[TASK]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to create necessary directories
create_directories() {
    print_status "Creating necessary directories..."
    mkdir -p $LOG_DIR
    mkdir -p $STATIC_DIR/staticfiles
    mkdir -p $STATIC_DIR/media
    chown -R www-data:www-data $STATIC_DIR
    chmod -R 755 $STATIC_DIR
}

# Function to install PM2 and initialize the project
init_pm2() {
    print_header "Initializing PM2 for Watch Party Backend"
    
    # Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        print_status "Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
    fi
    
    # Install PM2 globally
    if ! command -v pm2 &> /dev/null; then
        print_status "Installing PM2..."
        npm install -g pm2
    fi
    
    # Create log directory
    create_directories
    
    # Install Python dependencies
    print_status "Installing Python dependencies..."
    cd $PROJECT_DIR
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    source venv/bin/activate
    pip install -r requirements/production.txt
    
    # Run Django migrations and collect static files
    print_status "Running Django setup..."
    python manage.py migrate
    python manage.py collectstatic --noinput
    
    # Copy static files to nginx directory
    cp -r staticfiles/* $STATIC_DIR/staticfiles/
    chown -R www-data:www-data $STATIC_DIR
    
    # Start PM2 ecosystem
    print_status "Starting PM2 ecosystem..."
    pm2 start ecosystem.config.js
    pm2 save
    pm2 startup
    
    print_status "PM2 initialization complete!"
    pm2 status
}

# Function to install Nginx with HTTP configuration
install_nginx_http() {
    print_header "Installing Nginx with HTTP Configuration"
    
    # Install Nginx
    if ! command -v nginx &> /dev/null; then
        print_status "Installing Nginx..."
        apt-get update
        apt-get install -y nginx
    fi
    
    create_directories
    
    # Create HTTP-only Nginx configuration for backend
    print_status "Creating HTTP Nginx configuration for backend..."
    cat > $NGINX_SITES/$NGINX_CONFIG_NAME << 'EOF'
# Watch Party Backend API - Nginx Configuration (HTTP Only)
# This configuration is specifically for the backend API server
# Frontend should have its own separate configuration
upstream django_backend {
    server 127.0.0.1:8000 max_fails=3 fail_timeout=30s;
    keepalive 32;
}

upstream websocket_backend {
    server 127.0.0.1:8002 max_fails=3 fail_timeout=30s;
}

# Rate limiting zones
limit_req_zone $binary_remote_addr zone=api:10m rate=30r/m;
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;

# HTTP server - Backend Only
server {
    listen 80;
    server_name be-watch-party.brahim-elhouss.me;
    
    # Optimized buffers and timeouts
    client_max_body_size 50M;
    client_body_buffer_size 128k;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 4k;
    client_body_timeout 30s;
    client_header_timeout 30s;
    send_timeout 30s;
    
    # Logging
    access_log /var/log/watchparty/nginx_access.log;
    error_log /var/log/watchparty/nginx_error.log warn;
    
    # Trust Cloudflare IPs - Get real client IP
    real_ip_header CF-Connecting-IP;
    real_ip_recursive on;
    
    # Cloudflare IP ranges (IPv4)
    set_real_ip_from 173.245.48.0/20;
    set_real_ip_from 103.21.244.0/22;
    set_real_ip_from 103.22.200.0/22;
    set_real_ip_from 103.31.4.0/22;
    set_real_ip_from 141.101.64.0/18;
    set_real_ip_from 108.162.192.0/18;
    set_real_ip_from 190.93.240.0/20;
    set_real_ip_from 188.114.96.0/20;
    set_real_ip_from 188.114.112.0/20;
    set_real_ip_from 197.234.240.0/22;
    set_real_ip_from 198.41.128.0/17;
    set_real_ip_from 162.158.0.0/15;
    set_real_ip_from 104.16.0.0/13;
    set_real_ip_from 104.24.0.0/14;
    set_real_ip_from 172.64.0.0/13;
    set_real_ip_from 131.0.72.0/22;

    # Basic security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # Static files
    location /static/ {
        alias /var/www/watchparty/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        gzip_static on;
    }

    # Media files
    location /media/ {
        alias /var/www/watchparty/media/;
        expires 30d;
        add_header Cache-Control "public";
    }

    # WebSocket connections
    location /ws/ {
        proxy_pass http://websocket_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header CF-Connecting-IP $http_cf_connecting_ip;
        proxy_buffering off;
    }

    # Health check
    location /health/ {
        proxy_pass http://django_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        access_log off;
    }

    # API endpoints with rate limiting
    location /api/ {
        limit_req zone=api burst=10 nodelay;
        
        proxy_pass http://django_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header CF-Connecting-IP $http_cf_connecting_ip;
        proxy_set_header CF-Ray $http_cf_ray;
        proxy_set_header CF-Visitor $http_cf_visitor;
        proxy_set_header CF-Country $http_cf_ipcountry;
    }

    # Admin with strict rate limiting
    location /admin/ {
        limit_req zone=login burst=5 nodelay;
        
        proxy_pass http://django_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header CF-Connecting-IP $http_cf_connecting_ip;
    }

    # All other requests
    location / {
        proxy_pass http://django_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header CF-Connecting-IP $http_cf_connecting_ip;
        proxy_set_header CF-Ray $http_cf_ray;
        proxy_set_header CF-Visitor $http_cf_visitor;
        proxy_set_header CF-Country $http_cf_ipcountry;
    }

    # Security blocks
    location ~ /\.(env|git|htaccess|htpasswd) {
        deny all;
        access_log off;
        log_not_found off;
        return 404;
    }
    
    location ~ /(requirements.*\.txt|manage\.py|\.py$|\.pyc$) {
        deny all;
        access_log off;
        log_not_found off;
        return 404;
    }
}
EOF

    # Test the configuration before enabling
    print_status "Testing Nginx configuration syntax..."
    if ! nginx -t -c /etc/nginx/nginx.conf; then
        print_error "Nginx configuration test failed!"
        print_error "Please check the configuration file: $NGINX_SITES/$NGINX_CONFIG_NAME"
        exit 1
    fi
    
    # Enable the backend site
    print_status "Enabling backend Nginx configuration..."
    ln -sf $NGINX_SITES/$NGINX_CONFIG_NAME $NGINX_ENABLED/$NGINX_CONFIG_NAME
    
    # Remove default nginx site if it exists
    if [ -f "$NGINX_ENABLED/default" ]; then
        print_status "Removing default Nginx site..."
        rm -f $NGINX_ENABLED/default
    fi
    
    # Test configuration with the new site enabled
    print_status "Testing complete Nginx configuration..."
    if ! nginx -t; then
        print_error "Nginx configuration test failed with new site!"
        print_error "Disabling the new configuration..."
        rm -f $NGINX_ENABLED/$NGINX_CONFIG_NAME
        exit 1
    fi
    
    # Start and enable Nginx
    print_status "Starting Nginx service..."
    systemctl restart nginx
    systemctl enable nginx
    
    print_status "Backend Nginx HTTP configuration complete!"
    print_status "Configuration file: $NGINX_SITES/$NGINX_CONFIG_NAME"
    print_status "Enabled at: $NGINX_ENABLED/$NGINX_CONFIG_NAME"
    print_warning "Your backend API is now available at: http://$BACKEND_DOMAIN"
    print_warning "Remember to set up SSL certificates and run option 3 for HTTPS!"
    
    # Ask about SSL setup
    echo
    conditional_read REPLY "Do you want to set up SSL certificates now? (y/n): " 'n'
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        setup_ssl_prompt
    fi
}

# Function to prompt for SSL certificate setup
setup_ssl_prompt() {
    print_header "SSL Certificate Setup"
    echo "For Cloudflare Origin SSL certificates:"
    echo "1. Go to SSL/TLS > Origin Server in your Cloudflare dashboard"
    echo "2. Create a certificate for your domains:"
    echo "   - $BACKEND_DOMAIN"
    echo "   - $FRONTEND_DOMAIN"
    echo "3. Copy the certificate and save it as: $SSL_CERT_PATH/cloudflare-origin.pem"
    echo "4. Copy the private key and save it as: $SSL_KEY_PATH/cloudflare-origin.key"
    echo "5. Set proper permissions: chmod 600 $SSL_KEY_PATH/cloudflare-origin.key"
    echo "6. Run this script again with option 3 to enable HTTPS"
    echo
    print_warning "Make sure to secure your private key file!"
}

# Function to install HTTPS configuration
install_nginx_https() {
    print_header "Installing Nginx with HTTPS Configuration"
    
    # Check if SSL certificates exist
    if [ ! -f "$SSL_CERT_PATH/cloudflare-origin.pem" ] || [ ! -f "$SSL_KEY_PATH/cloudflare-origin.key" ]; then
        print_error "SSL certificates not found!"
        print_error "Expected files:"
        print_error "  Certificate: $SSL_CERT_PATH/cloudflare-origin.pem"
        print_error "  Private Key: $SSL_KEY_PATH/cloudflare-origin.key"
        echo
        setup_ssl_prompt
        exit 1
    fi
    
    create_directories
    
    # Create HTTPS Nginx configuration for backend
    print_status "Creating HTTPS Nginx configuration for backend..."
    cp $PROJECT_DIR/nginx.conf $NGINX_SITES/$NGINX_CONFIG_NAME
    
    # Test the configuration before enabling
    print_status "Testing Nginx configuration syntax..."
    if ! nginx -t -c /etc/nginx/nginx.conf; then
        print_error "Nginx configuration test failed!"
        print_error "Please check the configuration file: $NGINX_SITES/$NGINX_CONFIG_NAME"
        exit 1
    fi
    
    # Enable the backend site
    print_status "Enabling backend HTTPS Nginx configuration..."
    ln -sf $NGINX_SITES/$NGINX_CONFIG_NAME $NGINX_ENABLED/$NGINX_CONFIG_NAME
    
    # Remove default nginx site if it exists
    if [ -f "$NGINX_ENABLED/default" ]; then
        print_status "Removing default Nginx site..."
        rm -f $NGINX_ENABLED/default
    fi
    
    # Test configuration with the new site enabled
    print_status "Testing complete Nginx configuration..."
    if ! nginx -t; then
        print_error "Nginx configuration test failed with new site!"
        print_error "Disabling the new configuration..."
        rm -f $NGINX_ENABLED/$NGINX_CONFIG_NAME
        exit 1
    fi
    
    # Start and enable Nginx
    print_status "Restarting Nginx service..."
    systemctl restart nginx
    systemctl enable nginx
    
    print_status "Backend HTTPS configuration complete!"
    print_status "Configuration file: $NGINX_SITES/$NGINX_CONFIG_NAME"
    print_status "Enabled at: $NGINX_ENABLED/$NGINX_CONFIG_NAME"
    print_status "Your backend API is now available at: https://$BACKEND_DOMAIN"
    print_warning "Note: Frontend should be configured separately at: https://$FRONTEND_DOMAIN"
}

# Function to stop all services
stop_services() {
    print_header "Stopping All Services"
    
    # Stop PM2 processes
    if command -v pm2 &> /dev/null; then
        print_status "Stopping PM2 processes..."
        pm2 stop all
        pm2 delete all
        print_status "PM2 processes stopped"
    fi
    
    # Stop Nginx
    if systemctl is-active --quiet nginx; then
        print_status "Stopping Nginx..."
        systemctl stop nginx
        systemctl disable nginx
        print_status "Nginx stopped"
    fi
    
    # Stop Redis if running
    if systemctl is-active --quiet redis-server; then
        print_status "Stopping Redis..."
        systemctl stop redis-server
        print_status "Redis stopped"
    fi
    
    # Stop PostgreSQL if running locally
    if systemctl is-active --quiet postgresql; then
        print_warning "PostgreSQL is running."
        conditional_read REPLY "Stop PostgreSQL? (y/n): " 'n'
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            systemctl stop postgresql
            print_status "PostgreSQL stopped"
        fi
    fi
    
    print_status "All services have been stopped!"
}

# Function to test nginx configuration
test_nginx_config() {
    print_header "Testing Nginx Configuration"
    
    if [ ! -f "$NGINX_SITES/$NGINX_CONFIG_NAME" ]; then
        print_error "Backend Nginx configuration file not found: $NGINX_SITES/$NGINX_CONFIG_NAME"
        return 1
    fi
    
    print_status "Testing Nginx syntax..."
    if nginx -t; then
        print_status "✅ Nginx configuration test passed!"
        
        if [ -L "$NGINX_ENABLED/$NGINX_CONFIG_NAME" ]; then
            print_status "✅ Backend configuration is enabled"
        else
            print_warning "⚠️  Backend configuration exists but is not enabled"
        fi
        
        if systemctl is_active --quiet nginx; then
            print_status "✅ Nginx service is running"
        else
            print_warning "⚠️  Nginx service is not running"
        fi
    else
        print_error "❌ Nginx configuration test failed!"
        return 1
    fi
}

# Function to show service status
show_status() {
    print_header "Service Status"
    
    echo -e "\n${BLUE}PM2 Status:${NC}"
    if command -v pm2 &> /dev/null; then
        pm2 status
    else
        echo "PM2 not installed"
    fi
    
    echo -e "\n${BLUE}Nginx Status:${NC}"
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✅ Nginx is running${NC}"
        
        if [ -f "$NGINX_SITES/$NGINX_CONFIG_NAME" ]; then
            echo "Backend config file: $NGINX_SITES/$NGINX_CONFIG_NAME"
        fi
        
        if [ -L "$NGINX_ENABLED/$NGINX_CONFIG_NAME" ]; then
            echo -e "${GREEN}✅ Backend configuration is enabled${NC}"
        else
            echo -e "${YELLOW}⚠️  Backend configuration is not enabled${NC}"
        fi
    else
        echo -e "${RED}❌ Nginx is stopped${NC}"
    fi
    
    echo -e "\n${BLUE}SSL Certificate Status:${NC}"
    if [ -f "$SSL_CERT_PATH/cloudflare-origin.pem" ] && [ -f "$SSL_KEY_PATH/cloudflare-origin.key" ]; then
        echo -e "${GREEN}SSL certificates found${NC}"
        echo "Certificate: $SSL_CERT_PATH/cloudflare-origin.pem"
        echo "Private Key: $SSL_KEY_PATH/cloudflare-origin.key"
    else
        echo -e "${YELLOW}SSL certificates not found${NC}"
    fi
    
    echo -e "\n${BLUE}Disk Space:${NC}"
    df -h | grep -E '^/dev|Size'
    
    echo -e "\n${BLUE}Memory Usage:${NC}"
    free -h
}

# Main menu
show_menu() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Watch Party Backend Deployment      ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    echo "Backend Domain: $BACKEND_DOMAIN"
    echo "Frontend Domain: $FRONTEND_DOMAIN"
    echo
    echo "1. Initialize PM2 (Django + Celery + WebSocket)"
    echo "2. Install Nginx HTTP for Backend (development/testing)"
    echo "3. Install Nginx HTTPS for Backend (production with SSL)"
    echo "4. Test Nginx configuration"
    echo "5. Stop all services"
    echo "6. Show service status"
    echo "0. Exit"
    echo
}

# Main execution
main() {
    check_root
    
    while true; do
        show_menu
        read -p "Choose an option [0-6]: " choice
        
        case $choice in
            1)
                init_pm2
                ;;
            2)
                install_nginx_http
                ;;
            3)
                install_nginx_https
                ;;
            4)
                test_nginx_config
                ;;
            5)
                stop_services
                ;;
            6)
                show_status
                ;;
            0)
                print_status "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please choose 0-6."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..." -r
        echo
    done
}

# Run main function
main "$@"