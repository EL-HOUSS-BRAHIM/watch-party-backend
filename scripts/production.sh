#!/bin/bash

# =============================================================================
# WATCH PARTY BACKEND - PRODUCTION SERVER MANAGEMENT SCRIPT
# =============================================================================
# Comprehensive production server setup, configuration, and management
# Author: Watch Party Team
# Version: 2.0
# Last Updated: August 12, 2025

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Unified production env file detection (prefer legacy .env.production if present)
PROD_ENV_FILE="$PROJECT_ROOT/.env"
if [[ -f "$PROJECT_ROOT/.env.production" ]]; then
    PROD_ENV_FILE="$PROJECT_ROOT/.env.production"  # backward compatibility
fi

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
DEFAULT_HTTP_PORT=8001
DEFAULT_WEBSOCKET_PORT=8002
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
    
    local env_file="$PROD_ENV_FILE"
    
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
    log_info "Creating production environment configuration (unified .env)..."
    
    local env_file="$PROD_ENV_FILE"
    local server_ip
    server_ip=$(get_server_ip)
    
    # Generate secure secret key
    local secret_key
    secret_key=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
    
    cat > "$env_file" << EOF
# =============================================================================
# WATCH PARTY BACKEND - PRODUCTION ENVIRONMENT CONFIGURATION (Unified .env)
# =============================================================================
# Generated on: $(date)
# Server IP: $server_ip
# NOTE: Prefer managing real secrets via AWS SSM / Secrets Manager and templating this file.

# Core Django
DEBUG=False
SECRET_KEY=$secret_key
DJANGO_SETTINGS_MODULE=watchparty.settings.production
ALLOWED_HOSTS=$server_ip,localhost,127.0.0.1
CSRF_TRUSTED_ORIGINS=http://$server_ip,https://$server_ip

# Database (Override with AWS RDS secret)
DATABASE_URL=postgresql://watchparty_admin:CHANGE_ME@db-host:5432/watchparty_prod?sslmode=require
DATABASE_NAME=watchparty_prod
DATABASE_USER=watchparty_admin
DATABASE_PASSWORD=CHANGE_ME
DATABASE_HOST=db-host
DATABASE_PORT=5432
DB_SSL_MODE=require

# Redis / Valkey
REDIS_URL=redis://localhost:6379/0
CELERY_BROKER_URL=redis://localhost:6379/2
CELERY_RESULT_BACKEND=redis://localhost:6379/3
CHANNEL_LAYERS_CONFIG_HOSTS=redis://localhost:6379/4

# Email (override in secret store)
EMAIL_HOST=localhost
EMAIL_PORT=25
EMAIL_HOST_USER=
EMAIL_HOST_PASSWORD=
DEFAULT_FROM_EMAIL=noreply@example.com

# Static & Media
MEDIA_URL=/media/
STATIC_URL=/static/
MEDIA_ROOT=/var/www/watchparty/media/
STATIC_ROOT=/var/www/watchparty/static/

# Security
SECURE_SSL_REDIRECT=True
SECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO,https
SESSION_COOKIE_SECURE=True
CSRF_COOKIE_SECURE=True
SECURE_BROWSER_XSS_FILTER=True
SECURE_CONTENT_TYPE_NOSNIFF=True
SECURE_HSTS_SECONDS=31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS=True
SECURE_HSTS_PRELOAD=True

# Monitoring & Environment
SENTRY_DSN=
ENVIRONMENT=production

# Rate Limiting / Analytics / Video Processing
RATE_LIMIT_ENABLED=True
ANALYTICS_RETENTION_DAYS=365
VIDEO_MAX_FILE_SIZE=5368709120
VIDEO_PROCESSING_TIMEOUT=1800

# WebSocket / Parties / ML
WS_MAX_CONNECTIONS_PER_IP=20
WS_HEARTBEAT_INTERVAL=30
MAX_PARTY_PARTICIPANTS=100
ML_PREDICTIONS_ENABLED=False

# Celery Worker Settings
CELERY_TASK_ALWAYS_EAGER=False
CELERY_TASK_EAGER_PROPAGATES=True
CELERY_WORKER_CONCURRENCY=4
CELERY_WORKER_MAX_TASKS_PER_CHILD=1000

# AWS Placeholders (set via secret manager)
USE_S3=False
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_STORAGE_BUCKET_NAME=
AWS_S3_REGION_NAME=eu-west-3

# Infrastructure IDs (non-secret)
VPC_ID=
RDS_SECURITY_GROUP_ID=
ELASTICACHE_SECURITY_GROUP_ID=
APPLICATION_SECURITY_GROUP_ID=
EOF
    
    chmod 600 "$env_file"
    log_success "Production environment file created: $env_file"
    log_warning "Update DATABASE_URL, REDIS_URL and secrets via secret manager or edit file."
}

validate_env_config() {
    log_info "Validating environment configuration..."
    local env_file="$PROD_ENV_FILE"
    
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
    
    # Copy production environment file (unified)
    cp "$PROD_ENV_FILE" "$PRODUCTION_DIR/.env"
    chmod 600 "$PRODUCTION_DIR/.env"
    
    # Create virtual environment (remove existing if corrupted)
    cd "$PRODUCTION_DIR"
    if [[ -d "venv" ]]; then
        log_info "Removing existing virtual environment..."
        rm -rf venv
    fi
    
    log_info "Creating fresh virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    
    # Install dependencies
    log_info "Installing Python dependencies..."
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
ExecStart=$PRODUCTION_DIR/venv/bin/gunicorn --bind 127.0.0.1:$DEFAULT_HTTP_PORT --workers 3 --worker-class gevent --max-requests 1000 --timeout 30 --keep-alive 5 --preload --access-logfile $LOG_DIR/gunicorn_access.log --error-logfile $LOG_DIR/gunicorn_error.log --log-level info watchparty.wsgi:application
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
ExecStart=$PRODUCTION_DIR/venv/bin/daphne -b 127.0.0.1 -p $DEFAULT_WEBSOCKET_PORT watchparty.asgi:application
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

# =============================================================================
# NGINX CONFIGURATION
# =============================================================================

force_clean_nginx() {
    log_info "Force cleaning all Nginx configuration conflicts..."
    
    # Stop nginx first
    sudo systemctl stop nginx 2>/dev/null || true
    
    # Find and disable all site configurations that have rate limiting zones
    log_info "Identifying conflicting site configurations..."
    
    local conflicting_sites=()
    while IFS= read -r -d '' file; do
        if [[ -f "$file" && "$file" != *"watch-party"* ]]; then
            if grep -q "limit_req_zone\|limit_req.*zone=" "$file" 2>/dev/null; then
                conflicting_sites+=("$file")
                log_warning "Found conflicting configuration: $file"
            fi
        fi
    done < <(find /etc/nginx/sites-enabled -name "*.conf" -print0 2>/dev/null)
    
    # Backup and disable conflicting sites temporarily
    local disabled_files=()
    for site in "${conflicting_sites[@]}"; do
        local backup_name="${site}.backup.$(date +%s)"
        log_info "Temporarily disabling: $(basename "$site")"
        sudo mv "$site" "$backup_name"
        disabled_files+=("$backup_name")
    done
    
    # Clean up any existing watch-party configurations
    sudo rm -f /etc/nginx/sites-enabled/watch-party
    sudo rm -f /etc/nginx/sites-available/watch-party
    
    # Remove any watch-party zones from nginx.conf
    if [[ -f /etc/nginx/nginx.conf ]]; then
        sudo sed -i '/# Rate limiting zones for Watch Party/,+10d' /etc/nginx/nginx.conf 2>/dev/null || true
        sudo sed -i '/limit_req_zone.*watchparty/d' /etc/nginx/nginx.conf 2>/dev/null || true
    fi
    
    log_success "Nginx configuration cleaned"
    
    # Save disabled files list for later restoration
    if [[ ${#disabled_files[@]} -gt 0 ]]; then
        printf '%s\n' "${disabled_files[@]}" > /tmp/nginx_disabled_files.txt
        log_info "Disabled configurations saved to /tmp/nginx_disabled_files.txt"
        log_info "You can restore them later with: restore-nginx-configs"
    fi
}

restore_nginx_configs() {
    log_info "Restoring previously disabled Nginx configurations..."
    
    if [[ ! -f /tmp/nginx_disabled_files.txt ]]; then
        log_warning "No disabled configurations found to restore"
        return 0
    fi
    
    local restored=0
    while IFS= read -r backup_file; do
        if [[ -f "$backup_file" ]]; then
            local original_file="${backup_file%.backup.*}"
            log_info "Restoring: $(basename "$original_file")"
            sudo mv "$backup_file" "$original_file"
            ((restored++))
        fi
    done < /tmp/nginx_disabled_files.txt
    
    if [[ $restored -gt 0 ]]; then
        rm -f /tmp/nginx_disabled_files.txt
        log_success "Restored $restored configuration files"
        log_info "Testing nginx configuration..."
        if sudo nginx -t; then
            log_success "Nginx configuration is valid"
            sudo systemctl reload nginx
        else
            log_error "Nginx configuration test failed after restoration"
        fi
    else
        log_warning "No files were restored"
    fi
}

clean_nginx_conflicts() {
    log_info "Cleaning up Nginx configuration conflicts..."
    
    # First, let's check what's actually causing the conflict
    log_info "Analyzing nginx configuration for zone conflicts..."
    
    # Get all nginx configuration files and check for zone conflicts
    local all_zones=()
    local conflicting_zones=()
    
    # Parse all nginx configurations to find limit_req_zone directives
    if command -v nginx >/dev/null 2>&1; then
        # Get the full nginx configuration dump and extract zone information
        local config_dump=$(sudo nginx -T 2>/dev/null)
        
        # Find all limit_req_zone directives
        while IFS= read -r line; do
            if [[ "$line" =~ limit_req_zone.*zone=([^[:space:]]+) ]]; then
                local zone_name="${BASH_REMATCH[1]}"
                zone_name="${zone_name%;}"  # Remove trailing semicolon
                all_zones+=("$zone_name")
            fi
        done <<< "$config_dump"
        
        # Check for duplicate zones
        local seen_zones=()
        for zone in "${all_zones[@]}"; do
            if [[ " ${seen_zones[*]} " =~ " ${zone} " ]]; then
                if [[ ! " ${conflicting_zones[*]} " =~ " ${zone} " ]]; then
                    conflicting_zones+=("$zone")
                fi
            else
                seen_zones+=("$zone")
            fi
        done
        
        if [[ ${#conflicting_zones[@]} -gt 0 ]]; then
            log_warning "Found duplicate zone names:"
            for zone in "${conflicting_zones[@]}"; do
                echo "  • Zone: $zone"
            done
            
            # If one of the conflicting zones is 'api', we need to remove our old configurations
            if [[ " ${conflicting_zones[*]} " =~ " api " ]]; then
                log_warning "Conflict with 'api' zone detected. Cleaning up old configurations..."
                
                # Remove any old watch-party configurations that might use 'api' zone
                sudo rm -f /etc/nginx/sites-enabled/watch-party /etc/nginx/sites-available/watch-party
                
                # Remove our rate limiting zones from nginx.conf if they exist
                if sudo grep -q "limit_req_zone.*zone=api.*# Watch Party" /etc/nginx/nginx.conf 2>/dev/null; then
                    log_info "Removing old Watch Party rate limiting zones from nginx.conf..."
                    sudo sed -i '/# Rate limiting zones for Watch Party/,+2d' /etc/nginx/nginx.conf
                fi
            fi
            
            return 1
        fi
    fi
    
    return 0
}

configure_nginx_global() {
    log_info "Configuring global Nginx settings..."
    
    # Clean up any conflicts first
    clean_nginx_conflicts
    local has_conflicts=$?
    
    # Check for existing rate limiting zones that might conflict
    if sudo nginx -T 2>/dev/null | grep -q "limit_req_zone.*zone=watchparty_api"; then
        log_info "Watch Party rate limiting zones already configured"
        export WATCHPARTY_API_ZONE="watchparty_api"
        export WATCHPARTY_WS_ZONE="watchparty_ws"
        return 0
    fi
    
    # Determine zone suffix based on conflicts
    local zone_suffix=""
    if [[ $has_conflicts -eq 1 ]] || sudo nginx -T 2>/dev/null | grep -q "limit_req_zone.*zone=api:"; then
        log_warning "Detected zone name conflicts, using unique suffixes"
        zone_suffix="_wp$(date +%s | tail -c 4)"  # Add timestamp suffix for uniqueness
    fi
    
    # Add rate limiting configuration to nginx.conf if not already present
    if ! sudo grep -q "limit_req_zone.*zone=watchparty_api" /etc/nginx/nginx.conf; then
        log_info "Adding Watch Party rate limiting zones to nginx.conf..."
        
        # Create backup if it doesn't exist
        if [[ ! -f /etc/nginx/nginx.conf.backup ]]; then
            sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
        fi
        
        # Insert rate limiting configuration after the http directive with unique zone names
        local api_zone="watchparty_api${zone_suffix}"
        local ws_zone="watchparty_ws${zone_suffix}"
        
        sudo sed -i "/http {/a\\\\n\\t# Rate limiting zones for Watch Party Backend\\n\\tlimit_req_zone \$binary_remote_addr zone=${api_zone}:10m rate=10r/s;\\n\\tlimit_req_zone \$binary_remote_addr zone=${ws_zone}:10m rate=50r/s;\\n" /etc/nginx/nginx.conf
        
        # Export zone names for use in site configuration
        export WATCHPARTY_API_ZONE="$api_zone"
        export WATCHPARTY_WS_ZONE="$ws_zone"
        
        log_success "Watch Party rate limiting zones added: $api_zone, $ws_zone"
    else
        log_info "Watch Party rate limiting zones already configured in nginx.conf"
        export WATCHPARTY_API_ZONE="watchparty_api${zone_suffix}"
        export WATCHPARTY_WS_ZONE="watchparty_ws${zone_suffix}"
    fi
}


configure_nginx() {
    log_info "Configuring Nginx..."
    
    # Configure global nginx settings first
    configure_nginx_global
    
    # Set default zone names if not set by global config
    local api_zone="${WATCHPARTY_API_ZONE:-}"
    local ws_zone="${WATCHPARTY_WS_ZONE:-}"
    local use_rate_limiting=true
    
    # If zones are empty, disable rate limiting to avoid conflicts
    if [[ -z "$api_zone" || -z "$ws_zone" ]]; then
        log_warning "Rate limiting zones not available, creating configuration without rate limiting"
        use_rate_limiting=false
    fi
    
    # Ensure Nginx directories exist
    sudo mkdir -p "$NGINX_SITES_AVAILABLE"
    sudo mkdir -p "$NGINX_SITES_ENABLED"
    
    # Remove default site and any existing watch-party configs
    sudo rm -f "$NGINX_SITES_ENABLED/default"
    sudo rm -f "$NGINX_SITES_ENABLED/watch-party"
    sudo rm -f "$NGINX_SITES_AVAILABLE/watch-party"
    sudo rm -f "$NGINX_SITES_ENABLED/watchparty"
    sudo rm -f "$NGINX_SITES_AVAILABLE/watchparty"
    
    # Create Watch Party site configuration
    log_info "Using project nginx configuration (Cloudflare-compatible)..."
    
    # Copy the nginx configuration from the project
    if [[ -f "$PROJECT_ROOT/nginx.conf" ]]; then
        log_info "Copying nginx.conf from project..."
        sudo cp "$PROJECT_ROOT/nginx.conf" "$NGINX_SITES_AVAILABLE/watch-party"
        log_success "Nginx configuration copied from project"
    else
        log_warning "Project nginx.conf not found, creating basic configuration..."
        # Fallback configuration if nginx.conf doesn't exist in project
        sudo tee "$NGINX_SITES_AVAILABLE/watch-party" > /dev/null << 'NGINX_EOF'
# Watch Party Backend Nginx Configuration - Cloudflare Compatible
server {
    listen 80;
    server_name be-watch-party.brahim-elhouss.me watch-party.brahim-elhouss.me _;

    # Logging
    access_log /var/log/watchparty/nginx_access.log;
    error_log /var/log/watchparty/nginx_error.log;

    client_max_body_size 100M;
    client_body_timeout 300s;
    client_header_timeout 300s;
    
    # Trust Cloudflare IPs - Get real client IP
    real_ip_header CF-Connecting-IP;
    real_ip_recursive on;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Static files
    location /static/ {
        alias /var/www/watchparty/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
        add_header Vary Accept-Encoding;
        gzip_static on;
        try_files $uri $uri/ =404;
    }

    # Media files
    location /media/ {
        alias /var/www/watchparty/media/;
        expires 30d;
        add_header Cache-Control "public, immutable";
        try_files $uri $uri/ =404;
    }

    # WebSocket connections
    location /ws/ {
        proxy_pass http://127.0.0.1:8002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
        proxy_set_header CF-Connecting-IP $http_cf_connecting_ip;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }

    # Health check endpoint (no rate limiting)
    location /health/ {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
        proxy_set_header CF-Connecting-IP $http_cf_connecting_ip;
        access_log off;
    }

    # API and application
    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
        proxy_set_header CF-Connecting-IP $http_cf_connecting_ip;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
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
NGINX_EOF
    fi

    # Add rate limiting to the configuration if zones are available
    if [[ "$use_rate_limiting" == "true" && -n "$api_zone" && -n "$ws_zone" ]]; then
        log_info "Adding rate limiting to configuration..."
        
        # Add rate limiting to the API location
        sudo sed -i "/location \/ {/a\\        # Apply API rate limiting\\n        limit_req zone=$api_zone burst=20 nodelay;\\n" "$NGINX_SITES_AVAILABLE/watch-party"
        
        # Add rate limiting to the WebSocket location  
        sudo sed -i "/location \/ws\/ {/a\\        # Apply WebSocket rate limiting\\n        limit_req zone=$ws_zone burst=50 nodelay;\\n" "$NGINX_SITES_AVAILABLE/watch-party"
        
        log_success "Rate limiting added to configuration"
    fi

    # Ensure the sites-enabled directory exists and enable site
    sudo mkdir -p "$NGINX_SITES_ENABLED"
    sudo ln -sf "$NGINX_SITES_AVAILABLE/watch-party" "$NGINX_SITES_ENABLED/"
    
    log_info "Testing Nginx configuration..."
    
    # Test configuration
    if ! sudo nginx -t; then
        log_error "Nginx configuration test failed"
        if [[ "$use_rate_limiting" == "true" ]]; then
            log_info "Configuration details:"
            echo "  • API Zone: ${api_zone:-not set}"
            echo "  • WebSocket Zone: ${ws_zone:-not set}"
        else
            log_info "Configuration created without rate limiting due to conflicts"
        fi
        echo "  • Config file: /etc/nginx/sites-available/watch-party"
        return 1
    fi
    
    # Start and enable Nginx
    sudo systemctl start nginx
    sudo systemctl enable nginx
    
    log_success "Nginx configured successfully"
    if [[ "$use_rate_limiting" == "true" ]]; then
        log_info "Rate limiting enabled:"
        echo "  • API Zone: $api_zone"
        echo "  • WebSocket Zone: $ws_zone"
    else
        log_info "Rate limiting disabled due to conflicts"
    fi
    echo "  • Config file: /etc/nginx/sites-available/watch-party"
}

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

# Function to clean up any existing processes and ensure clean start
cleanup_existing_processes() {
    log_info "Cleaning up any existing processes..."
    
    # Kill any existing gunicorn processes to avoid port conflicts
    sudo pkill -f gunicorn || true
    
    # Stop services if they exist (ignore errors if they don't exist)
    sudo systemctl stop watchparty-gunicorn || true
    sudo systemctl stop watchparty-daphne || true
    sudo systemctl stop watchparty-celery || true
    sudo systemctl stop watchparty-celery-beat || true
    
    # Reload systemd to pick up any service file changes
    sudo systemctl daemon-reload
    
    log_success "Cleanup completed"
}

# =============================================================================
# SERVICE MANAGEMENT
# =============================================================================

start_services() {
    log_info "Starting services..."
    
    # Clean up any existing processes first
    cleanup_existing_processes
    
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
    echo "  1. Update ALLOWED_HOSTS in $(basename "$PROD_ENV_FILE") with your domain"
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
    echo "  fix-nginx              Fix Nginx configuration issues"
    echo "  clean-nginx            Force clean all nginx conflicts"
    echo "  force-clean-nginx      Aggressively clean nginx conflicts by disabling conflicting sites"
    echo "  restore-nginx-configs  Restore previously disabled nginx configurations"
    echo "  force-fix-nginx        Force clean and reconfigure nginx completely"
    echo "  test-nginx             Test nginx configuration syntax"
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
        fix-nginx|config-nginx)
            configure_nginx_global
            configure_nginx
            sudo systemctl reload nginx
            ;;
        clean-nginx)
            log_info "Force cleaning nginx configuration conflicts..."
            clean_nginx_conflicts
            log_info "Removing all Watch Party nginx configurations..."
            sudo rm -f /etc/nginx/sites-enabled/watch-party /etc/nginx/sites-available/watch-party
            if sudo grep -q "Watch Party" /etc/nginx/nginx.conf 2>/dev/null; then
                log_info "Removing Watch Party zones from nginx.conf..."
                sudo sed -i '/# Rate limiting zones for Watch Party/,+3d' /etc/nginx/nginx.conf
                sudo sed -i '/# Watch Party rate limiting zones/,+3d' /etc/nginx/nginx.conf
            fi
            log_success "Nginx configuration cleaned"
            ;;
        force-clean-nginx)
            force_clean_nginx
            ;;
        restore-nginx-configs)
            restore_nginx_configs
            ;;
        force-fix-nginx)
            force_clean_nginx
            configure_nginx_global
            configure_nginx
            sudo systemctl reload nginx
            ;;
        test-nginx)
            sudo nginx -t
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
