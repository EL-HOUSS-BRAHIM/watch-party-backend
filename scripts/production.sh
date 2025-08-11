#!/bin/bash

# =============================================================================
# WATCH PARTY BACKEND - PRODUCTION SERVER MANAGEMENT SCRIPT
# =============================================================================
# Comprehensive production server setup, configuration, and management
# Author: Watch Party Team
# Version: 2.0
# Last Updated: August 11, 2025

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors and emojis
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

readonly CHECK="✅"
readonly CROSS="❌"
readonly WARNING="⚠️"
readonly INFO="ℹ️"
readonly ROCKET="🚀"
readonly GEAR="⚙️"
readonly SHIELD="🛡️"
readonly SERVER="🖥️"

# Logging functions
log_info() { echo -e "${BLUE}${INFO} $1${NC}"; }
log_success() { echo -e "${GREEN}${CHECK} $1${NC}"; }
log_warning() { echo -e "${YELLOW}${WARNING} $1${NC}"; }
log_error() { echo -e "${RED}${CROSS} $1${NC}"; }
log_title() { echo -e "${WHITE}$1${NC}"; }

# Configuration
PRODUCTION_DIR="/var/www/watchparty"
LOG_DIR="/var/log/watchparty"
CONFIG_DIR="/etc/watchparty"
BACKUP_DIR="/var/backups/watchparty"
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
SYSTEMD_DIR="/etc/systemd/system"

# Default ports
DEFAULT_HTTP_PORT=8000
DEFAULT_WEBSOCKET_PORT=8001
DEFAULT_NGINX_HTTP=80
DEFAULT_NGINX_HTTPS=443
DEFAULT_POSTGRES_PORT=5432
DEFAULT_REDIS_PORT=6379

# Environment template
ENV_TEMPLATE="production.env"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                        PRODUCTION SERVER MANAGER                            ║
║                         Watch Party Backend v2.0                           ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                    🚀 Production Deployment & Management                    ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root for safety reasons"
        log_info "It will prompt for sudo when needed"
        exit 1
    fi
}

check_system() {
    log_info "Checking system requirements..."
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine operating system"
        exit 1
    fi
    
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        log_warning "This script is optimized for Ubuntu. Proceed with caution."
    fi
    
    # Check if we have sudo access
    if ! sudo -n true 2>/dev/null; then
        log_info "This script requires sudo access. You may be prompted for your password."
    fi
    
    log_success "System check passed"
}

is_port_in_use() {
    local port="$1"
    netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "
}

find_available_port() {
    local start_port="$1"
    local port=$start_port
    
    while is_port_in_use "$port"; do
        ((port++))
        if [[ $port -gt 65535 ]]; then
            log_error "No available ports found"
            exit 1
        fi
    done
    
    echo "$port"
}

get_server_ip() {
    # Try to get external IP
    local external_ip
    external_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "")
    
    if [[ -n "$external_ip" ]]; then
        echo "$external_ip"
    else
        # Fallback to local IP
        hostname -I | awk '{print $1}' 2>/dev/null || echo "127.0.0.1"
    fi
}

# =============================================================================
# PORT MANAGEMENT
# =============================================================================

check_port_conflicts() {
    log_info "Checking for port conflicts..."
    
    local conflicts=0
    local ports_to_check=(
        "$DEFAULT_HTTP_PORT:Application HTTP"
        "$DEFAULT_WEBSOCKET_PORT:WebSocket"
        "$DEFAULT_NGINX_HTTP:Nginx HTTP"
        "$DEFAULT_NGINX_HTTPS:Nginx HTTPS"
        "$DEFAULT_POSTGRES_PORT:PostgreSQL"
        "$DEFAULT_REDIS_PORT:Redis"
    )
    
    for port_info in "${ports_to_check[@]}"; do
        local port="${port_info%%:*}"
        local service="${port_info##*:}"
        
        if is_port_in_use "$port"; then
            log_warning "Port $port ($service) is already in use"
            ((conflicts++))
            
            # Show what's using the port
            local process
            process=$(sudo lsof -ti:"$port" 2>/dev/null | head -1)
            if [[ -n "$process" ]]; then
                local process_info
                process_info=$(ps -p "$process" -o comm= 2>/dev/null || echo "unknown")
                log_info "  Used by: $process_info (PID: $process)"
            fi
        else
            log_success "Port $port ($service) is available"
        fi
    done
    
    if [[ $conflicts -gt 0 ]]; then
        log_warning "Found $conflicts port conflicts"
        return 1
    else
        log_success "No port conflicts detected"
        return 0
    fi
}

resolve_port_conflicts() {
    log_info "Resolving port conflicts..."
    
    # Find alternative ports
    local new_http_port
    local new_websocket_port
    
    new_http_port=$(find_available_port $DEFAULT_HTTP_PORT)
    new_websocket_port=$(find_available_port $DEFAULT_WEBSOCKET_PORT)
    
    if [[ "$new_http_port" != "$DEFAULT_HTTP_PORT" ]]; then
        log_info "Using alternative HTTP port: $new_http_port"
        DEFAULT_HTTP_PORT=$new_http_port
    fi
    
    if [[ "$new_websocket_port" != "$DEFAULT_WEBSOCKET_PORT" ]]; then
        log_info "Using alternative WebSocket port: $new_websocket_port"
        DEFAULT_WEBSOCKET_PORT=$new_websocket_port
    fi
    
    # Stop conflicting services if they're non-essential
    stop_conflicting_services
    
    log_success "Port conflicts resolved"
}

stop_conflicting_services() {
    log_info "Checking for conflicting services..."
    
    # Common services that might conflict
    local services_to_check=("apache2" "lighttpd" "caddy")
    
    for service in "${services_to_check[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_warning "Found conflicting service: $service"
            
            if [[ "${FORCE:-false}" == "true" ]]; then
                log_info "Stopping $service..."
                sudo systemctl stop "$service"
                sudo systemctl disable "$service"
                log_success "$service stopped and disabled"
            else
                echo -n "Stop and disable $service? (y/N): "
                read -r stop_service
                if [[ "$stop_service" == "y" || "$stop_service" == "Y" ]]; then
                    sudo systemctl stop "$service"
                    sudo systemctl disable "$service"
                    log_success "$service stopped and disabled"
                fi
            fi
        fi
    done
}

# =============================================================================
# ENVIRONMENT CONFIGURATION
# =============================================================================

check_env_requirements() {
    log_info "Checking environment requirements..."
    
    local missing_vars=()
    local env_file="$PROJECT_ROOT/.env.production"
    
    if [[ ! -f "$env_file" ]]; then
        log_warning "Production environment file not found: $env_file"
        create_production_env
        return 1
    fi
    
    # Required environment variables
    local required_vars=(
        "SECRET_KEY"
        "DATABASE_URL"
        "REDIS_URL"
        "ALLOWED_HOSTS"
        "DJANGO_SETTINGS_MODULE"
    )
    
    source "$env_file"
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        return 1
    fi
    
    # Check if SECRET_KEY is secure enough
    if [[ "${SECRET_KEY:-}" == *"your-secret-key"* ]] || [[ "${#SECRET_KEY}" -lt 32 ]]; then
        log_error "SECRET_KEY is not secure enough"
        return 1
    fi
    
    log_success "Environment requirements check passed"
    return 0
}

create_production_env() {
    log_info "Creating production environment configuration..."
    
    local env_file="$PROJECT_ROOT/.env.production"
    local server_ip
    server_ip=$(get_server_ip)
    
    # Generate secure secret key
    local secret_key
    secret_key=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
    
    cat > "$env_file" << EOF
# =============================================================================
# WATCH PARTY BACKEND - PRODUCTION ENVIRONMENT CONFIGURATION
# =============================================================================
# Generated on: $(date)
# Server IP: $server_ip

# Django Settings
DEBUG=False
SECRET_KEY=$secret_key
DJANGO_SETTINGS_MODULE=watchparty.settings.production
ALLOWED_HOSTS=$server_ip,localhost,127.0.0.1

# Database Configuration
DATABASE_URL=postgresql://watchparty_user:watchparty_secure_password@localhost:5432/watchparty

# Redis Configuration
REDIS_URL=redis://localhost:6379/0
CELERY_BROKER_URL=redis://localhost:6379/0
CELERY_RESULT_BACKEND=redis://localhost:6379/0

# Server Configuration
HTTP_PORT=$DEFAULT_HTTP_PORT
WEBSOCKET_PORT=$DEFAULT_WEBSOCKET_PORT
WORKERS=3
WORKER_CLASS=gevent
MAX_REQUESTS=1000
TIMEOUT=30

# Security Settings
SECURE_SSL_REDIRECT=False
SESSION_COOKIE_SECURE=False
CSRF_COOKIE_SECURE=False
SECURE_BROWSER_XSS_FILTER=True
SECURE_CONTENT_TYPE_NOSNIFF=True
X_FRAME_OPTIONS=DENY

# Static and Media Files
STATIC_ROOT=/var/www/watchparty/static
MEDIA_ROOT=/var/www/watchparty/media
STATIC_URL=/static/
MEDIA_URL=/media/

# Logging
LOG_LEVEL=INFO
LOG_DIR=$LOG_DIR

# Email Configuration (Update with your SMTP settings)
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password

# Backup Configuration
BACKUP_DIR=$BACKUP_DIR
BACKUP_RETENTION_DAYS=30

# Performance Settings
CONN_MAX_AGE=60
DATABASE_POOL_SIZE=20

# Monitoring
SENTRY_DSN=
ENABLE_MONITORING=True

# Third-party Services (Update as needed)
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_STORAGE_BUCKET_NAME=
AWS_S3_REGION_NAME=us-east-1

# Social Authentication
GOOGLE_OAUTH2_CLIENT_ID=
GOOGLE_OAUTH2_CLIENT_SECRET=
FACEBOOK_APP_ID=
FACEBOOK_APP_SECRET=

# API Keys
YOUTUBE_API_KEY=
TWITCH_CLIENT_ID=
TWITCH_CLIENT_SECRET=
EOF
    
    # Set appropriate permissions
    chmod 600 "$env_file"
    
    log_success "Production environment file created: $env_file"
    log_warning "Please review and update the configuration with your actual values"
    log_info "Especially update:"
    echo "  - ALLOWED_HOSTS with your domain"
    echo "  - Database credentials"
    echo "  - Email settings"
    echo "  - API keys and secrets"
}

validate_env_config() {
    log_info "Validating environment configuration..."
    
    local env_file="$PROJECT_ROOT/.env.production"
    
    if [[ ! -f "$env_file" ]]; then
        log_error "Production environment file not found"
        return 1
    fi
    
    # Check file permissions
    local file_perms
    file_perms=$(stat -c "%a" "$env_file")
    if [[ "$file_perms" != "600" ]]; then
        log_warning "Environment file has insecure permissions: $file_perms"
        chmod 600 "$env_file"
        log_success "Fixed environment file permissions"
    fi
    
    # Check for common misconfigurations
    source "$env_file"
    
    local warnings=0
    
    if [[ "${DEBUG:-}" == "True" ]]; then
        log_warning "DEBUG is enabled in production"
        ((warnings++))
    fi
    
    if [[ "${ALLOWED_HOSTS:-}" == "*" ]]; then
        log_warning "ALLOWED_HOSTS is set to wildcard (*)"
        ((warnings++))
    fi
    
    if [[ "${SECRET_KEY:-}" =~ ^[a-zA-Z0-9]{32}$ ]]; then
        log_warning "SECRET_KEY appears to be weak"
        ((warnings++))
    fi
    
    if [[ $warnings -gt 0 ]]; then
        log_warning "Found $warnings configuration warnings"
        return 1
    fi
    
    log_success "Environment configuration validated"
    return 0
}

# =============================================================================
# SYSTEM SETUP
# =============================================================================

validate_and_fix_directories() {
    log_info "Validating and fixing directory structure..."
    
    # Define all required directories
    local required_dirs=(
        "$PRODUCTION_DIR"
        "$LOG_DIR"
        "$CONFIG_DIR"
        "$BACKUP_DIR"
        "$PRODUCTION_DIR/static"
        "$PRODUCTION_DIR/media"
        "$PRODUCTION_DIR/logs"
        "$NGINX_SITES_AVAILABLE"
        "$NGINX_SITES_ENABLED"
        "/var/run/watchparty"
    )
    
    # Define all required log files
    local required_log_files=(
        "$LOG_DIR/django.log"
        "$LOG_DIR/django_errors.log"
        "$LOG_DIR/gunicorn_access.log"
        "$LOG_DIR/gunicorn_error.log"
        "$LOG_DIR/celery.log"
        "$LOG_DIR/celery-beat.log"
        "$LOG_DIR/nginx_access.log"
        "$LOG_DIR/nginx_error.log"
    )
    
    local fixes_needed=0
    local errors=0
    
    # Temporarily disable exit on error for this function
    set +e
    
    # Check and create directories
    log_info "Checking directories..."
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_warning "Missing directory: $dir"
            if sudo mkdir -p "$dir" 2>/dev/null; then
                log_success "Created directory: $dir"
                ((fixes_needed++))
            else
                log_error "Failed to create directory: $dir"
                ((errors++))
            fi
        else
            echo "  ✓ Directory exists: $dir"
        fi
    done
    
    # Check and create log files
    log_info "Checking log files..."
    for log_file in "${required_log_files[@]}"; do
        if [[ ! -f "$log_file" ]]; then
            log_warning "Missing log file: $log_file"
            # Ensure parent directory exists first
            local log_dir=$(dirname "$log_file")
            if [[ ! -d "$log_dir" ]]; then
                sudo mkdir -p "$log_dir" 2>/dev/null
            fi
            if sudo touch "$log_file" 2>/dev/null; then
                log_success "Created log file: $log_file"
                ((fixes_needed++))
            else
                log_error "Failed to create log file: $log_file"
                ((errors++))
            fi
        else
            echo "  ✓ Log file exists: $log_file"
        fi
    done
    
    # Create symlinks for backwards compatibility if they don't exist
    log_info "Checking compatibility symlinks..."
    if [[ -d "$PRODUCTION_DIR/logs" ]]; then
        if [[ ! -L "$PRODUCTION_DIR/logs/django.log" && -f "$LOG_DIR/django.log" ]]; then
            if sudo ln -sf "$LOG_DIR/django.log" "$PRODUCTION_DIR/logs/django.log" 2>/dev/null; then
                log_success "Created symlink: $PRODUCTION_DIR/logs/django.log"
                ((fixes_needed++))
            fi
        fi
        
        if [[ ! -L "$PRODUCTION_DIR/logs/django_errors.log" && -f "$LOG_DIR/django_errors.log" ]]; then
            if sudo ln -sf "$LOG_DIR/django_errors.log" "$PRODUCTION_DIR/logs/django_errors.log" 2>/dev/null; then
                log_success "Created symlink: $PRODUCTION_DIR/logs/django_errors.log"
                ((fixes_needed++))
            fi
        fi
    fi
    
    # Fix permissions for all directories and files
    log_info "Fixing permissions..."
    local permission_fixes=0
    
    for dir in "$PRODUCTION_DIR" "$LOG_DIR" "$CONFIG_DIR" "$BACKUP_DIR" "/var/run/watchparty"; do
        if [[ -d "$dir" ]]; then
            if sudo chown -R $USER:www-data "$dir" 2>/dev/null; then
                ((permission_fixes++))
            fi
            if sudo chmod -R 755 "$dir" 2>/dev/null; then
                ((permission_fixes++))
            fi
        fi
    done
    
    # Set specific permissions for log files
    if [[ -d "$LOG_DIR" ]]; then
        sudo chmod 644 "$LOG_DIR"/*.log 2>/dev/null || true
    fi
    
    # Re-enable exit on error
    set -e
    
    # Summary
    echo
    if [[ $errors -gt 0 ]]; then
        log_error "Validation completed with $errors errors"
        if [[ $fixes_needed -gt 0 ]]; then
            log_warning "Successfully fixed $fixes_needed issues"
        fi
        return 1
    elif [[ $fixes_needed -gt 0 ]]; then
        log_success "Directory structure validation completed - Fixed $fixes_needed issues"
        return 0
    else
        log_success "Directory structure validation passed - No issues found"
        return 0
    fi
}

install_system_dependencies() {
    log_info "Installing system dependencies..."
    
    # Update package list
    sudo apt-get update -y
    
    # Install essential packages
    sudo apt-get install -y \
        python3 \
        python3-dev \
        python3-venv \
        python3-pip \
        postgresql \
        postgresql-contrib \
        redis-server \
        nginx \
        supervisor \
        git \
        curl \
        wget \
        unzip \
        build-essential \
        libpq-dev \
        libssl-dev \
        libffi-dev \
        libjpeg-dev \
        libpng-dev \
        pkg-config \
        htop \
        tree \
        vim \
        fail2ban \
        ufw \
        certbot \
        python3-certbot-nginx
    
    log_success "System dependencies installed"
}

setup_directories() {
    log_info "Setting up directories..."
    
    # Create application directories
    sudo mkdir -p "$PRODUCTION_DIR"
    sudo mkdir -p "$LOG_DIR"
    sudo mkdir -p "$CONFIG_DIR"
    sudo mkdir -p "$BACKUP_DIR"
    sudo mkdir -p "$PRODUCTION_DIR/static"
    sudo mkdir -p "$PRODUCTION_DIR/media"
    sudo mkdir -p "$PRODUCTION_DIR/logs"  # For backwards compatibility with base settings
    
    # Create Nginx directories if they don't exist
    sudo mkdir -p "$NGINX_SITES_AVAILABLE"
    sudo mkdir -p "$NGINX_SITES_ENABLED"
    
    # Create systemd runtime directory
    sudo mkdir -p /var/run/watchparty
    
    # Create log files with proper permissions
    sudo touch "$LOG_DIR/django.log"
    sudo touch "$LOG_DIR/django_errors.log"
    sudo touch "$LOG_DIR/gunicorn_access.log"
    sudo touch "$LOG_DIR/gunicorn_error.log"
    sudo touch "$LOG_DIR/celery.log"
    sudo touch "$LOG_DIR/celery-beat.log"
    sudo touch "$LOG_DIR/nginx_access.log"
    sudo touch "$LOG_DIR/nginx_error.log"
    
    # Create symlinks for backwards compatibility (base settings might still reference these)
    sudo ln -sf "$LOG_DIR/django.log" "$PRODUCTION_DIR/logs/django.log" 2>/dev/null || true
    sudo ln -sf "$LOG_DIR/django_errors.log" "$PRODUCTION_DIR/logs/django_errors.log" 2>/dev/null || true
    
    # Set ownership and permissions
    sudo chown -R $USER:www-data "$PRODUCTION_DIR"
    sudo chown -R $USER:www-data "$LOG_DIR"
    sudo chown -R $USER:www-data "$CONFIG_DIR"
    sudo chown -R $USER:www-data "$BACKUP_DIR"
    sudo chown -R $USER:www-data /var/run/watchparty
    
    sudo chmod -R 755 "$PRODUCTION_DIR"
    sudo chmod -R 755 "$LOG_DIR"
    sudo chmod -R 755 "$CONFIG_DIR"
    sudo chmod -R 755 "$BACKUP_DIR"
    sudo chmod -R 755 /var/run/watchparty
    
    # Set specific permissions for log files
    sudo chmod 644 "$LOG_DIR"/*.log
    
    log_success "Directories and log files created and configured"
}

configure_postgresql() {
    log_info "Configuring PostgreSQL..."
    
    # Start and enable PostgreSQL
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    
    # Check if database exists
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw watchparty; then
        log_info "Database 'watchparty' already exists"
    else
        # Create database and user
        sudo -u postgres createdb watchparty
        log_success "Database 'watchparty' created"
    fi
    
    # Check if user exists
    if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='watchparty_user'" | grep -q 1; then
        log_info "User 'watchparty_user' already exists"
    else
        sudo -u postgres createuser --createdb watchparty_user
        log_success "User 'watchparty_user' created"
    fi
    
    # Set password and permissions
    sudo -u postgres psql -c "ALTER USER watchparty_user PASSWORD 'watchparty_secure_password';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE watchparty TO watchparty_user;"
    
    log_success "PostgreSQL configured"
}

configure_redis() {
    log_info "Configuring Redis..."
    
    # Configure Redis for production
    sudo cp /etc/redis/redis.conf /etc/redis/redis.conf.backup
    
    # Update Redis configuration
    sudo tee /etc/redis/redis.conf > /dev/null << 'EOF'
# Redis configuration for Watch Party Backend
port 6379
bind 127.0.0.1
timeout 300
tcp-keepalive 60
daemonize yes
pidfile /var/run/redis/redis-server.pid
loglevel notice
logfile /var/log/redis/redis-server.log
databases 16
dir /var/lib/redis
maxmemory 512mb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
EOF
    
    # Start and enable Redis
    sudo systemctl start redis-server
    sudo systemctl enable redis-server
    
    log_success "Redis configured"
}

# =============================================================================
# APPLICATION DEPLOYMENT
# =============================================================================

deploy_application() {
    log_info "Deploying application..."
    
    # Copy application files
    rsync -av \
        --exclude='.git/' \
        --exclude='venv/' \
        --exclude='__pycache__/' \
        --exclude='*.pyc' \
        --exclude='.env*' \
        --exclude='db.sqlite3' \
        --exclude='logs/' \
        --exclude='media/' \
        --exclude='staticfiles/' \
        --exclude='backups/' \
        "$PROJECT_ROOT/" "$PRODUCTION_DIR/"
    
    # Copy production environment file
    cp "$PROJECT_ROOT/.env.production" "$PRODUCTION_DIR/.env"
    chmod 600 "$PRODUCTION_DIR/.env"
    
    # Create virtual environment
    cd "$PRODUCTION_DIR"
    python3 -m venv venv
    source venv/bin/activate
    
    # Install dependencies
    pip install --upgrade pip setuptools wheel
    pip install -r requirements.txt
    pip install gunicorn gevent
    
    # Django management commands
    python manage.py collectstatic --noinput
    python manage.py migrate
    
    log_success "Application deployed"
}

create_systemd_services() {
    log_info "Creating systemd services..."
    
    # Gunicorn service
    sudo tee "$SYSTEMD_DIR/watchparty-gunicorn.service" > /dev/null << EOF
[Unit]
Description=Watch Party Gunicorn daemon
After=network.target postgresql.service redis.service

[Service]
Type=notify
User=$USER
Group=www-data
RuntimeDirectory=watchparty
WorkingDirectory=$PRODUCTION_DIR
Environment=PATH=$PRODUCTION_DIR/venv/bin
EnvironmentFile=$PRODUCTION_DIR/.env
ExecStart=$PRODUCTION_DIR/venv/bin/gunicorn \\
    --bind 127.0.0.1:$DEFAULT_HTTP_PORT \\
    --workers 3 \\
    --worker-class gevent \\
    --max-requests 1000 \\
    --timeout 30 \\
    --keep-alive 5 \\
    --preload \\
    --access-logfile $LOG_DIR/gunicorn_access.log \\
    --error-logfile $LOG_DIR/gunicorn_error.log \\
    --log-level info \\
    watchparty.wsgi:application
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Daphne service for WebSockets
    sudo tee "$SYSTEMD_DIR/watchparty-daphne.service" > /dev/null << EOF
[Unit]
Description=Watch Party Daphne daemon
After=network.target postgresql.service redis.service

[Service]
Type=simple
User=$USER
Group=www-data
WorkingDirectory=$PRODUCTION_DIR
Environment=PATH=$PRODUCTION_DIR/venv/bin
EnvironmentFile=$PRODUCTION_DIR/.env
ExecStart=$PRODUCTION_DIR/venv/bin/daphne \\
    -b 127.0.0.1 \\
    -p $DEFAULT_WEBSOCKET_PORT \\
    watchparty.asgi:application
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Celery worker service
    sudo tee "$SYSTEMD_DIR/watchparty-celery.service" > /dev/null << EOF
[Unit]
Description=Watch Party Celery Worker
After=network.target postgresql.service redis.service

[Service]
Type=forking
User=$USER
Group=www-data
WorkingDirectory=$PRODUCTION_DIR
Environment=PATH=$PRODUCTION_DIR/venv/bin
EnvironmentFile=$PRODUCTION_DIR/.env
ExecStart=$PRODUCTION_DIR/venv/bin/celery -A watchparty worker \\
    --loglevel=info \\
    --detach \\
    --pidfile=/var/run/watchparty/celery.pid \\
    --logfile=$LOG_DIR/celery.log
ExecStop=/bin/kill -s TERM \$MAINPID
Restart=on-failure
RestartSec=5
PIDFile=/var/run/watchparty/celery.pid

[Install]
WantedBy=multi-user.target
EOF

    # Celery beat service
    sudo tee "$SYSTEMD_DIR/watchparty-celery-beat.service" > /dev/null << EOF
[Unit]
Description=Watch Party Celery Beat
After=network.target postgresql.service redis.service watchparty-celery.service

[Service]
Type=forking
User=$USER
Group=www-data
WorkingDirectory=$PRODUCTION_DIR
Environment=PATH=$PRODUCTION_DIR/venv/bin
EnvironmentFile=$PRODUCTION_DIR/.env
ExecStart=$PRODUCTION_DIR/venv/bin/celery -A watchparty beat \\
    --loglevel=info \\
    --detach \\
    --pidfile=/var/run/watchparty/celery-beat.pid \\
    --logfile=$LOG_DIR/celery-beat.log
ExecStop=/bin/kill -s TERM \$MAINPID
Restart=on-failure
RestartSec=5
PIDFile=/var/run/watchparty/celery-beat.pid

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd
    sudo systemctl daemon-reload
    
    log_success "Systemd services created"
}

configure_nginx() {
    log_info "Configuring Nginx..."
    
    # Ensure Nginx directories exist
    sudo mkdir -p "$NGINX_SITES_AVAILABLE"
    sudo mkdir -p "$NGINX_SITES_ENABLED"
    
    # Remove default site if it exists
    sudo rm -f "$NGINX_SITES_ENABLED/default"
    
    # Create Watch Party site configuration
    sudo tee "$NGINX_SITES_AVAILABLE/watchparty" > /dev/null << EOF
# Watch Party Backend Nginx Configuration
server {
    listen $DEFAULT_NGINX_HTTP;
    server_name _;

    # Logging
    access_log $LOG_DIR/nginx_access.log;
    error_log $LOG_DIR/nginx_error.log;

    client_max_body_size 100M;
    client_body_timeout 300s;
    client_header_timeout 300s;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Static files
    location /static/ {
        alias $PRODUCTION_DIR/static/;
        expires 30d;
        add_header Cache-Control "public, immutable";
        add_header Vary Accept-Encoding;
        gzip_static on;
    }

    # Media files
    location /media/ {
        alias $PRODUCTION_DIR/media/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # WebSocket connections
    location /ws/ {
        proxy_pass http://127.0.0.1:$DEFAULT_WEBSOCKET_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }

    # API and application
    location / {
        proxy_pass http://127.0.0.1:$DEFAULT_HTTP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
        
        # Rate limiting
        limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
        limit_req zone=api burst=20 nodelay;
    }

    # Health check endpoint (no rate limiting)
    location /health/ {
        proxy_pass http://127.0.0.1:$DEFAULT_HTTP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        access_log off;
    }

    # Deny access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    location ~ /(\.env|requirements\.txt|manage\.py)$ {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF

    # Ensure the sites-enabled directory exists and enable site
    sudo mkdir -p "$NGINX_SITES_ENABLED"
    sudo ln -sf "$NGINX_SITES_AVAILABLE/watchparty" "$NGINX_SITES_ENABLED/"
    
    # Test configuration
    if ! sudo nginx -t; then
        log_error "Nginx configuration test failed"
        return 1
    fi
    
    # Start and enable Nginx
    sudo systemctl start nginx
    sudo systemctl enable nginx
    
    log_success "Nginx configured"
}

# =============================================================================
# SECURITY SETUP
# =============================================================================

configure_firewall() {
    log_info "Configuring firewall..."
    
    # Reset UFW
    sudo ufw --force reset
    
    # Default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Allow essential services
    sudo ufw allow ssh
    sudo ufw allow $DEFAULT_NGINX_HTTP/tcp
    sudo ufw allow $DEFAULT_NGINX_HTTPS/tcp
    
    # Enable firewall
    sudo ufw --force enable
    
    log_success "Firewall configured"
}

setup_fail2ban() {
    log_info "Setting up Fail2Ban..."
    
    # Create custom jail configuration
    sudo tee /etc/fail2ban/jail.local > /dev/null << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
bantime = 86400

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10

[nginx-botsearch]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
EOF

    # Start and enable Fail2Ban
    sudo systemctl start fail2ban
    sudo systemctl enable fail2ban
    
    log_success "Fail2Ban configured"
}

# =============================================================================
# SERVICE MANAGEMENT
# =============================================================================

start_services() {
    log_info "Starting services..."
    
    # Start system services
    sudo systemctl start postgresql redis-server nginx
    
    # Start application services
    sudo systemctl start watchparty-gunicorn
    sudo systemctl start watchparty-daphne
    sudo systemctl start watchparty-celery
    sudo systemctl start watchparty-celery-beat
    
    # Enable services
    sudo systemctl enable watchparty-gunicorn
    sudo systemctl enable watchparty-daphne
    sudo systemctl enable watchparty-celery
    sudo systemctl enable watchparty-celery-beat
    
    log_success "Services started"
}

stop_services() {
    log_info "Stopping services..."
    
    # Stop application services
    sudo systemctl stop watchparty-celery-beat || true
    sudo systemctl stop watchparty-celery || true
    sudo systemctl stop watchparty-daphne || true
    sudo systemctl stop watchparty-gunicorn || true
    
    log_success "Services stopped"
}

restart_services() {
    log_info "Restarting services..."
    
    stop_services
    sleep 2
    start_services
    
    log_success "Services restarted"
}

show_service_status() {
    log_info "Service Status:"
    echo
    
    local services=(
        "postgresql:PostgreSQL Database"
        "redis-server:Redis Cache"
        "nginx:Nginx Web Server"
        "watchparty-gunicorn:Application Server"
        "watchparty-daphne:WebSocket Server"
        "watchparty-celery:Background Worker"
        "watchparty-celery-beat:Task Scheduler"
    )
    
    for service_info in "${services[@]}"; do
        local service="${service_info%%:*}"
        local description="${service_info##*:}"
        
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo -e "  ${GREEN}${CHECK} $description${NC} (Running)"
        else
            echo -e "  ${RED}${CROSS} $description${NC} (Stopped)"
        fi
    done
    
    echo
    log_info "Application Health:"
    
    # Check application health
    if curl -s http://localhost:$DEFAULT_HTTP_PORT/health/ > /dev/null 2>&1; then
        echo -e "  ${GREEN}${CHECK} HTTP Health Check${NC} (OK)"
    else
        echo -e "  ${RED}${CROSS} HTTP Health Check${NC} (Failed)"
    fi
    
    # Check WebSocket
    if netstat -tuln | grep -q ":$DEFAULT_WEBSOCKET_PORT "; then
        echo -e "  ${GREEN}${CHECK} WebSocket Server${NC} (Running)"
    else
        echo -e "  ${RED}${CROSS} WebSocket Server${NC} (Not Running)"
    fi
    
    echo
    log_info "System Resources:"
    echo "  Memory Usage: $(free -h | awk '/^Mem:/ {printf "%.1f%% (%s/%s)", $3/$2*100, $3, $2}')"
    echo "  Disk Usage: $(df -h / | awk 'NR==2 {printf "%s (%s)", $5, $4" available"}')"
    echo "  Load Average: $(uptime | awk -F'load average:' '{print $2}')"
}

# =============================================================================
# MAINTENANCE FUNCTIONS
# =============================================================================

create_backup() {
    log_info "Creating backup..."
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$BACKUP_DIR/backup_$timestamp.tar.gz"
    
    # Create backup directory
    sudo mkdir -p "$BACKUP_DIR"
    
    # Database backup
    sudo -u postgres pg_dump watchparty > /tmp/watchparty_db_$timestamp.sql
    
    # Create full backup
    sudo tar -czf "$backup_file" \
        -C "$PRODUCTION_DIR" . \
        -C /tmp "watchparty_db_$timestamp.sql" \
        -C "$CONFIG_DIR" . 2>/dev/null || true
    
    # Clean up temporary files
    rm -f /tmp/watchparty_db_$timestamp.sql
    
    # Set appropriate permissions
    sudo chown $USER:$USER "$backup_file"
    
    log_success "Backup created: $backup_file"
}

update_application() {
    log_info "Updating application..."
    
    # Create backup first
    create_backup
    
    # Stop services
    stop_services
    
    # Update application code
    cd "$PROJECT_ROOT"
    git pull origin main 2>/dev/null || log_warning "Git pull failed or not a git repository"
    
    # Deploy updated application
    deploy_application
    
    # Start services
    start_services
    
    log_success "Application updated"
}

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

setup_production() {
    show_banner
    log_title "Setting up production server..."
    
    check_root
    check_system
    
    # Validate and fix any existing directory issues first
    validate_and_fix_directories
    
    # Check and resolve port conflicts
    if ! check_port_conflicts; then
        if [[ "${FORCE:-false}" == "true" ]]; then
            resolve_port_conflicts
        else
            echo -n "Resolve port conflicts automatically? (y/N): "
            read -r resolve_conflicts
            if [[ "$resolve_conflicts" == "y" || "$resolve_conflicts" == "Y" ]]; then
                resolve_port_conflicts
            else
                log_error "Please resolve port conflicts manually and run again"
                exit 1
            fi
        fi
    fi
    
    # Check environment requirements
    if ! check_env_requirements; then
        log_error "Environment requirements not met. Please fix and run again"
        exit 1
    fi
    
    # Install dependencies and setup
    install_system_dependencies
    setup_directories
    configure_postgresql
    configure_redis
    deploy_application
    create_systemd_services
    configure_nginx
    configure_firewall
    setup_fail2ban
    start_services
    
    log_success "Production server setup completed!"
    
    # Show final information
    echo
    log_title "🎉 SETUP COMPLETE!"
    echo
    log_info "Server Details:"
    echo "  • Server IP: $(get_server_ip)"
    echo "  • Application URL: http://$(get_server_ip)"
    echo "  • HTTP Port: $DEFAULT_HTTP_PORT"
    echo "  • WebSocket Port: $DEFAULT_WEBSOCKET_PORT"
    echo
    log_info "Next Steps:"
    echo "  1. Update ALLOWED_HOSTS in .env.production with your domain"
    echo "  2. Set up SSL with: ./manage.sh ssl-setup"
    echo "  3. Configure your domain DNS to point to this server"
    echo "  4. Monitor logs with: ./manage.sh prod logs"
    echo
    log_warning "Don't forget to:"
    echo "  • Change default database password"
    echo "  • Configure email settings"
    echo "  • Set up monitoring and alerting"
    echo "  • Create regular backups"
}

show_help() {
    echo "Watch Party Production Server Management"
    echo
    echo "USAGE:"
    echo "  $0 [COMMAND] [OPTIONS]"
    echo
    echo "SETUP COMMANDS:"
    echo "  setup                  Complete production setup"
    echo "  setup-env              Create production environment file"
    echo "  validate-dirs          Validate and fix directory structure"
    echo "  check-ports            Check for port conflicts"
    echo "  resolve-ports          Resolve port conflicts"
    echo
    echo "SERVICE COMMANDS:"
    echo "  start                  Start all services"
    echo "  stop                   Stop all services"
    echo "  restart                Restart all services"
    echo "  status                 Show service status"
    echo
    echo "MAINTENANCE COMMANDS:"
    echo "  backup                 Create backup"
    echo "  update                 Update application"
    echo "  logs [service]         Show logs"
    echo "  health                 Health check"
    echo
    echo "CONFIGURATION COMMANDS:"
    echo "  validate-env           Validate environment configuration"
    echo "  fix-permissions        Fix file permissions"
    echo "  config-nginx           Reconfigure Nginx"
    echo
    echo "OPTIONS:"
    echo "  --force                Force operations without confirmation"
    echo "  --verbose              Enable verbose output"
    echo
    echo "EXAMPLES:"
    echo "  $0 setup               # Complete production setup"
    echo "  $0 status              # Show service status"
    echo "  $0 logs nginx          # Show Nginx logs"
    echo "  $0 restart --force     # Force restart without confirmation"
}

main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        setup)
            setup_production "$@"
            ;;
        setup-env)
            create_production_env
            ;;
        validate-dirs|fix-dirs)
            validate_and_fix_directories
            ;;
        check-ports)
            check_port_conflicts
            ;;
        resolve-ports)
            resolve_port_conflicts
            ;;
        start)
            start_services
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        status)
            show_service_status
            ;;
        backup)
            create_backup
            ;;
        update)
            update_application
            ;;
        logs)
            local service="${1:-all}"
            if [[ "$service" == "all" ]]; then
                sudo journalctl -f -u watchparty-*
            else
                sudo journalctl -f -u "$service"
            fi
            ;;
        health)
            show_service_status
            ;;
        validate-env)
            validate_env_config
            ;;
        fix-permissions)
            sudo chown -R $USER:www-data "$PRODUCTION_DIR" "$LOG_DIR" "$CONFIG_DIR"
            sudo chmod -R 755 "$PRODUCTION_DIR" "$LOG_DIR" "$CONFIG_DIR"
            log_success "Permissions fixed"
            ;;
        config-nginx)
            configure_nginx
            sudo systemctl reload nginx
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
