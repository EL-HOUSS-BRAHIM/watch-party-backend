#!/bin/bash

# Watch Party Backend - Production Deployment Script
# This script deploys the Django application with Nginx, Redis, PostgreSQL, and Celery

set -e  # Exit on any error

# Configuration
PROJECT_NAME="watch-party-backend"
PROJECT_USER="watchparty"
PROJECT_DIR="/var/www/watch-party-backend"
NGINX_CONF_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
DOMAIN="${DOMAIN:-watchparty.example.com}"
DB_NAME="${DB_NAME:-watchparty_db}"
DB_USER="${DB_USER:-watchparty_user}"
DB_PASSWORD="${DB_PASSWORD:-$(openssl rand -base64 32)}"
REDIS_PASSWORD="${REDIS_PASSWORD:-$(openssl rand -base64 32)}"
SECRET_KEY="${SECRET_KEY:-$(openssl rand -base64 50)}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

# Update system packages
update_system() {
    log "Updating system packages..."
    apt update && apt upgrade -y
}

# Install system dependencies
install_system_dependencies() {
    log "Installing system dependencies..."
    
    # Check if dependencies are already installed
    PACKAGES_TO_INSTALL=""
    
    for package in python3 python3-pip python3-venv nginx postgresql postgresql-contrib redis-server curl git supervisor certbot python3-certbot-nginx build-essential python3-dev libpq-dev; do
        if ! dpkg -s "$package" >/dev/null 2>&1; then
            PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $package"
        fi
    done
    
    if [ -n "$PACKAGES_TO_INSTALL" ]; then
        log "Installing packages:$PACKAGES_TO_INSTALL"
        apt install -y $PACKAGES_TO_INSTALL
    else
        log "All system dependencies are already installed"
    fi
    
    # Install Node.js if not present (for some frontend assets)
    if ! command -v node &> /dev/null; then
        log "Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt install -y nodejs
    else
        log "Node.js is already installed"
    fi
}

# Create project user
create_project_user() {
    log "Creating project user..."
    if ! id "$PROJECT_USER" &>/dev/null; then
        useradd --system --shell /bin/bash --home /home/$PROJECT_USER --create-home $PROJECT_USER
        log "User $PROJECT_USER created"
    else
        log "User $PROJECT_USER already exists"
    fi
}

# Setup PostgreSQL
setup_postgresql() {
    log "Setting up PostgreSQL..."
    
    # Start and enable PostgreSQL
    systemctl start postgresql
    systemctl enable postgresql
    
    # Create database and user if they don't exist
    sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1 || \
    sudo -u postgres createdb $DB_NAME
    
    sudo -u postgres psql -tc "SELECT 1 FROM pg_user WHERE usename = '$DB_USER'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
    
    sudo -u postgres psql -c "ALTER ROLE $DB_USER SET client_encoding TO 'utf8';"
    sudo -u postgres psql -c "ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';"
    sudo -u postgres psql -c "ALTER ROLE $DB_USER SET timezone TO 'UTC';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
    
    log "PostgreSQL setup completed"
}

# Setup Redis
setup_redis() {
    log "Setting up Redis..."
    
    # Configure Redis with password
    if [ ! -f /etc/redis/redis.conf.backup ]; then
        cp /etc/redis/redis.conf /etc/redis/redis.conf.backup
    fi
    
    # Set Redis password and basic security
    sed -i "s/# requirepass foobared/requirepass $REDIS_PASSWORD/" /etc/redis/redis.conf
    sed -i "s/bind 127.0.0.1 ::1/bind 127.0.0.1/" /etc/redis/redis.conf
    
    systemctl restart redis-server
    systemctl enable redis-server
    
    log "Redis setup completed"
}

# Setup project directory and code
setup_project() {
    log "Setting up project directory..."
    
    # Create project directory
    mkdir -p $PROJECT_DIR
    
    # Copy project files (assuming script is run from project root)
    if [ -d "$(pwd)/.git" ]; then
        log "Copying project files from current directory..."
        rsync -av --exclude='.git' --exclude='*.pyc' --exclude='__pycache__' \
              --exclude='.env' --exclude='db.sqlite3' --exclude='logs/*' \
              ./ $PROJECT_DIR/
    else
        error "This script should be run from the project root directory"
    fi
    
    # Set ownership
    chown -R $PROJECT_USER:$PROJECT_USER $PROJECT_DIR
    
    # Create necessary directories
    sudo -u $PROJECT_USER mkdir -p $PROJECT_DIR/logs
    sudo -u $PROJECT_USER mkdir -p $PROJECT_DIR/static
    sudo -u $PROJECT_USER mkdir -p $PROJECT_DIR/media
    
    log "Project directory setup completed"
}

# Setup Python virtual environment
setup_virtualenv() {
    log "Setting up Python virtual environment..."
    
    sudo -u $PROJECT_USER python3 -m venv $PROJECT_DIR/venv
    
    # Install Python dependencies
    log "Installing Python dependencies..."
    sudo -u $PROJECT_USER $PROJECT_DIR/venv/bin/pip install --upgrade pip
    sudo -u $PROJECT_USER $PROJECT_DIR/venv/bin/pip install -r $PROJECT_DIR/requirements.txt
    sudo -u $PROJECT_USER $PROJECT_DIR/venv/bin/pip install gunicorn psycopg2-binary
    
    log "Virtual environment setup completed"
}

# Create environment file
create_env_file() {
    log "Creating environment configuration..."
    
    cat > $PROJECT_DIR/.env << EOF
# Django Configuration
DJANGO_SETTINGS_MODULE=watchparty.settings.production
SECRET_KEY='$SECRET_KEY'
DEBUG=False
ALLOWED_HOSTS=$DOMAIN,www.$DOMAIN,localhost,127.0.0.1

# Database Configuration
DATABASE_URL=postgres://$DB_USER:$DB_PASSWORD@localhost:5432/$DB_NAME

# Redis Configuration
REDIS_URL=redis://:$REDIS_PASSWORD@127.0.0.1:6379/0
CELERY_BROKER_URL=redis://:$REDIS_PASSWORD@127.0.0.1:6379/2
CELERY_RESULT_BACKEND=redis://:$REDIS_PASSWORD@127.0.0.1:6379/3

# Email Configuration (update these with your SMTP settings)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password

# Static and Media Files
STATIC_URL=/static/
MEDIA_URL=/media/
STATIC_ROOT=$PROJECT_DIR/static
MEDIA_ROOT=$PROJECT_DIR/media

# Security Settings
SECURE_SSL_REDIRECT=True
SECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO,https
SESSION_COOKIE_SECURE=True
CSRF_COOKIE_SECURE=True

# CORS Settings
CORS_ALLOWED_ORIGINS=https://$DOMAIN,https://www.$DOMAIN
CORS_ALLOW_CREDENTIALS=True
EOF

    chown $PROJECT_USER:$PROJECT_USER $PROJECT_DIR/.env
    chmod 600 $PROJECT_DIR/.env
    
    log "Environment file created"
}

# Run Django management commands
run_django_commands() {
    log "Running Django management commands..."
    
    cd $PROJECT_DIR
    
    # Run migrations
    sudo -u $PROJECT_USER $PROJECT_DIR/venv/bin/python manage.py migrate --settings=watchparty.settings.production
    
    # Collect static files
    sudo -u $PROJECT_USER $PROJECT_DIR/venv/bin/python manage.py collectstatic --noinput --settings=watchparty.settings.production
    
    # Create superuser if it doesn't exist
    sudo -u $PROJECT_USER $PROJECT_DIR/venv/bin/python manage.py shell --settings=watchparty.settings.production << EOF
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(is_superuser=True).exists():
    User.objects.create_superuser('admin', 'admin@$DOMAIN', 'admin123')
    print('Superuser created: admin/admin123')
else:
    print('Superuser already exists')
EOF
    
    log "Django commands completed"
}

# Create Nginx configuration
create_nginx_config() {
    log "Creating Nginx configuration..."
    
    cat > $NGINX_CONF_DIR/$PROJECT_NAME << EOF
upstream django_app {
    server 127.0.0.1:8000;
}

upstream daphne_app {
    server 127.0.0.1:8001;
}

# Rate limiting
limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone \$binary_remote_addr zone=login:10m rate=5r/m;

server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    
    # Redirect HTTP to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;
    
    # SSL Configuration (will be handled by certbot)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin";
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json
        image/svg+xml;
    
    # Client body size
    client_max_body_size 50M;
    
    # Root directory
    root $PROJECT_DIR;
    
    # Static files
    location /static/ {
        alias $PROJECT_DIR/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Media files
    location /media/ {
        alias $PROJECT_DIR/media/;
        expires 1y;
        add_header Cache-Control "public";
    }
    
    # WebSocket connections for real-time features
    location /ws/ {
        proxy_pass http://daphne_app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
        proxy_buffering off;
    }
    
    # API endpoints with rate limiting
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        
        proxy_pass http://django_app;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
    }
    
    # Authentication endpoints with stricter rate limiting
    location ~ ^/(auth|login|register|password) {
        limit_req zone=login burst=5 nodelay;
        
        proxy_pass http://django_app;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
    }
    
    # Admin interface
    location /admin/ {
        proxy_pass http://django_app;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
    }
    
    # Main application
    location / {
        proxy_pass http://django_app;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
    }
    
    # Health check endpoint
    location /health/ {
        access_log off;
        proxy_pass http://django_app;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    
    # Enable the site
    ln -sf $NGINX_CONF_DIR/$PROJECT_NAME $NGINX_ENABLED_DIR/
    
    # Remove default site if it exists
    rm -f $NGINX_ENABLED_DIR/default
    
    log "Nginx configuration created"
}

# Create Supervisor configuration for Gunicorn and Celery
create_supervisor_config() {
    log "Creating Supervisor configuration..."
    
    # Gunicorn configuration
    cat > /etc/supervisor/conf.d/gunicorn.conf << EOF
[program:gunicorn]
command=$PROJECT_DIR/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:8000 watchparty.wsgi:application
directory=$PROJECT_DIR
user=$PROJECT_USER
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=$PROJECT_DIR/logs/gunicorn.log
environment=DJANGO_SETTINGS_MODULE="watchparty.settings.production"
EOF
    
    # Daphne configuration for WebSockets
    cat > /etc/supervisor/conf.d/daphne.conf << EOF
[program:daphne]
command=$PROJECT_DIR/venv/bin/daphne -b 127.0.0.1 -p 8001 watchparty.asgi:application
directory=$PROJECT_DIR
user=$PROJECT_USER
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=$PROJECT_DIR/logs/daphne.log
environment=DJANGO_SETTINGS_MODULE="watchparty.settings.production"
EOF
    
    # Celery Worker configuration
    cat > /etc/supervisor/conf.d/celery.conf << EOF
[program:celery]
command=$PROJECT_DIR/venv/bin/celery -A watchparty worker --loglevel=info
directory=$PROJECT_DIR
user=$PROJECT_USER
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=$PROJECT_DIR/logs/celery.log
environment=DJANGO_SETTINGS_MODULE="watchparty.settings.production"
EOF
    
    # Celery Beat configuration
    cat > /etc/supervisor/conf.d/celerybeat.conf << EOF
[program:celerybeat]
command=$PROJECT_DIR/venv/bin/celery -A watchparty beat --loglevel=info --scheduler django_celery_beat.schedulers:DatabaseScheduler
directory=$PROJECT_DIR
user=$PROJECT_USER
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=$PROJECT_DIR/logs/celerybeat.log
environment=DJANGO_SETTINGS_MODULE="watchparty.settings.production"
EOF
    
    log "Supervisor configuration created"
}

# Setup SSL with Let's Encrypt
setup_ssl() {
    log "Setting up SSL with Let's Encrypt..."
    
    # Test Nginx configuration
    nginx -t
    
    # Stop Nginx temporarily for certbot
    systemctl stop nginx
    
    # Get SSL certificate
    certbot certonly --standalone -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN
    
    # Start Nginx
    systemctl start nginx
    
    # Auto-renewal
    (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
    
    log "SSL setup completed"
}

# Start and enable services
start_services() {
    log "Starting and enabling services..."
    
    # Reload supervisor configuration
    supervisorctl reread
    supervisorctl update
    
    # Start all programs
    supervisorctl start all
    
    # Enable and start Nginx
    systemctl enable nginx
    systemctl restart nginx
    
    # Enable and start other services
    systemctl enable postgresql
    systemctl enable redis-server
    systemctl enable supervisor
    
    log "All services started and enabled"
}

# Create backup script
create_backup_script() {
    log "Creating backup script..."
    
    cat > /usr/local/bin/backup-watchparty.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/var/backups/watchparty"
DATE=$(date +%Y%m%d_%H%M%S)
PROJECT_DIR="/var/www/watch-party-backend"

mkdir -p $BACKUP_DIR

# Backup database
sudo -u postgres pg_dump watchparty_db > $BACKUP_DIR/db_backup_$DATE.sql

# Backup media files
tar -czf $BACKUP_DIR/media_backup_$DATE.tar.gz -C $PROJECT_DIR media/

# Backup environment file
cp $PROJECT_DIR/.env $BACKUP_DIR/env_backup_$DATE

# Keep only last 7 days of backups
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
find $BACKUP_DIR -name "env_backup_*" -mtime +7 -delete

echo "Backup completed: $DATE"
EOF
    
    chmod +x /usr/local/bin/backup-watchparty.sh
    
    # Add to crontab (daily backup at 2 AM)
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/backup-watchparty.sh") | crontab -
    
    log "Backup script created and scheduled"
}

# Print deployment information
print_deployment_info() {
    log "Deployment completed successfully!"
    echo ""
    echo "================================================"
    echo "DEPLOYMENT INFORMATION"
    echo "================================================"
    echo "Domain: https://$DOMAIN"
    echo "Project Directory: $PROJECT_DIR"
    echo "Project User: $PROJECT_USER"
    echo ""
    echo "Database:"
    echo "  Name: $DB_NAME"
    echo "  User: $DB_USER"
    echo "  Password: $DB_PASSWORD"
    echo ""
    echo "Redis Password: $REDIS_PASSWORD"
    echo ""
    echo "Django Admin:"
    echo "  URL: https://$DOMAIN/admin/"
    echo "  Username: admin"
    echo "  Password: admin123"
    echo ""
    echo "Service Commands:"
    echo "  Check status: supervisorctl status"
    echo "  Restart services: supervisorctl restart all"
    echo "  View logs: tail -f $PROJECT_DIR/logs/*.log"
    echo "  Backup: /usr/local/bin/backup-watchparty.sh"
    echo ""
    echo "IMPORTANT: Change the default admin password!"
    echo "================================================"
}

# Main deployment function
main() {
    log "Starting Watch Party Backend deployment..."
    
    check_root
    update_system
    install_system_dependencies
    create_project_user
    setup_postgresql
    setup_redis
    setup_project
    setup_virtualenv
    create_env_file
    run_django_commands
    create_nginx_config
    create_supervisor_config
    
    # Only setup SSL if domain is not the default example
    if [ "$DOMAIN" != "watchparty.example.com" ]; then
        setup_ssl
    else
        warn "Using example domain. SSL setup skipped. Update DOMAIN variable and run SSL setup manually."
        systemctl restart nginx
    fi
    
    start_services
    create_backup_script
    print_deployment_info
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --db-password)
            DB_PASSWORD="$2"
            shift 2
            ;;
        --redis-password)
            REDIS_PASSWORD="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --domain DOMAIN          Set the domain name (default: watchparty.example.com)"
            echo "  --db-password PASSWORD   Set the database password"
            echo "  --redis-password PASSWORD Set the Redis password"
            echo "  --help                   Show this help message"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Run main function
main
