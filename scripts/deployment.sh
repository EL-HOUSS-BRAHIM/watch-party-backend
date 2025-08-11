#!/bin/bash

# =============================================================================
# WATCH PARTY BACKEND - DEPLOYMENT SCRIPT
# =============================================================================
# Handle deployment operations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Change to project root
cd "$PROJECT_ROOT"

# Deploy to production
deploy_production() {
    local target="${1:-production}"
    
    log_info "Starting deployment to $target..."
    
    # Pre-deployment checks
    log_info "Running pre-deployment checks..."
    
    # Check git status
    if [[ -d ".git" ]]; then
        if ! git diff-index --quiet HEAD --; then
            log_error "Uncommitted changes found. Please commit all changes before deploying."
            exit 1
        fi
        log_success "Git status: Clean"
    fi
    
    # Check tests
    log_info "Running tests..."
    if [[ -f "venv/bin/activate" ]]; then
        source venv/bin/activate
        if ! python manage.py test --verbosity=0; then
            log_error "Tests failed. Deployment aborted."
            exit 1
        fi
        log_success "Tests: Passed"
    fi
    
    # Create deployment package
    log_info "Creating deployment package..."
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local deploy_package="deployment_${target}_${timestamp}.tar.gz"
    
    # Create temporary deployment directory
    local temp_dir="/tmp/watchparty_deploy_$$"
    mkdir -p "$temp_dir/watchparty"
    
    # Copy files (excluding dev files)
    rsync -av \
        --exclude='.git/' \
        --exclude='venv/' \
        --exclude='__pycache__/' \
        --exclude='*.pyc' \
        --exclude='.env' \
        --exclude='.env.local' \
        --exclude='db.sqlite3' \
        --exclude='logs/' \
        --exclude='media/' \
        --exclude='staticfiles/' \
        --exclude='backups/' \
        --exclude='node_modules/' \
        "$PROJECT_ROOT/" "$temp_dir/watchparty/"
    
    # Create deployment scripts
    cat > "$temp_dir/deploy.sh" << 'EOF'
#!/bin/bash
# Auto-generated deployment script

set -e

log_info() { echo -e "\033[0;34mℹ️  $1\033[0m"; }
log_success() { echo -e "\033[0;32m✅ $1\033[0m"; }
log_error() { echo -e "\033[0;31m❌ $1\033[0m"; }

DEPLOY_DIR="/var/www/watch-party-backend"
BACKUP_DIR="/var/backups/watch-party-backend"

# Create backup of current deployment
if [[ -d "$DEPLOY_DIR" ]]; then
    log_info "Creating backup of current deployment..."
    sudo mkdir -p "$BACKUP_DIR"
    sudo tar -czf "$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).tar.gz" -C "$(dirname "$DEPLOY_DIR")" "$(basename "$DEPLOY_DIR")"
fi

# Stop services
log_info "Stopping services..."
sudo systemctl stop watchparty-backend 2>/dev/null || true
sudo systemctl stop watchparty-websocket 2>/dev/null || true

# Deploy new version
log_info "Deploying new version..."
sudo mkdir -p "$DEPLOY_DIR"
sudo cp -r watchparty/* "$DEPLOY_DIR/"
sudo chown -R www-data:www-data "$DEPLOY_DIR"

# Install dependencies
log_info "Installing dependencies..."
cd "$DEPLOY_DIR"
sudo -u www-data python3 -m venv venv
sudo -u www-data venv/bin/pip install -r requirements.txt

# Run migrations
log_info "Running migrations..."
sudo -u www-data venv/bin/python manage.py migrate --settings=watchparty.settings.production

# Collect static files
log_info "Collecting static files..."
sudo -u www-data venv/bin/python manage.py collectstatic --noinput --settings=watchparty.settings.production

# Start services
log_info "Starting services..."
sudo systemctl start watchparty-backend
sudo systemctl start watchparty-websocket
sudo systemctl reload nginx

log_success "Deployment completed successfully!"
EOF
    
    chmod +x "$temp_dir/deploy.sh"
    
    # Create the package
    cd "$temp_dir"
    tar -czf "$deploy_package" deploy.sh watchparty/
    mv "$deploy_package" "$PROJECT_ROOT/"
    
    # Cleanup
    rm -rf "$temp_dir"
    
    log_success "Deployment package created: $deploy_package"
    
    # If target server is specified, deploy automatically
    if [[ "$2" != "" ]]; then
        deploy_to_server "$2" "$deploy_package"
    else
        echo
        echo "To deploy to server, run:"
        echo "  scp $deploy_package user@server:/tmp/"
        echo "  ssh user@server 'cd /tmp && tar -xzf $deploy_package && sudo ./deploy.sh'"
    fi
}

# Deploy to staging
deploy_staging() {
    log_info "Deploying to staging environment..."
    
    # Similar to production but with different settings
    export DJANGO_SETTINGS_MODULE=watchparty.settings.staging
    
    deploy_production "staging" "$@"
}

# Deploy to server directly
deploy_to_server() {
    local server="$1"
    local package="$2"
    
    if [[ -z "$server" ]] || [[ -z "$package" ]]; then
        log_error "Server and package are required"
        exit 1
    fi
    
    log_info "Deploying $package to $server..."
    
    # Upload package
    scp "$package" "$server:/tmp/"
    
    # Execute deployment
    ssh "$server" "cd /tmp && tar -xzf $(basename "$package") && sudo ./deploy.sh"
    
    log_success "Deployment to $server completed!"
}

# Rollback deployment
rollback_deployment() {
    local server="$1"
    local backup_file="$2"
    
    if [[ -z "$server" ]]; then
        log_error "Server is required for rollback"
        exit 1
    fi
    
    log_info "Rolling back deployment on $server..."
    
    # Create rollback script
    cat > "/tmp/rollback.sh" << 'EOF'
#!/bin/bash
set -e

DEPLOY_DIR="/var/www/watch-party-backend"
BACKUP_DIR="/var/backups/watch-party-backend"

# Stop services
sudo systemctl stop watchparty-backend watchparty-websocket

# Restore from backup
if [[ -n "$1" ]]; then
    BACKUP_FILE="$BACKUP_DIR/$1"
else
    BACKUP_FILE=$(ls -t $BACKUP_DIR/backup_*.tar.gz | head -1)
fi

if [[ -f "$BACKUP_FILE" ]]; then
    echo "Restoring from: $BACKUP_FILE"
    sudo tar -xzf "$BACKUP_FILE" -C "$(dirname "$DEPLOY_DIR")"
    sudo chown -R www-data:www-data "$DEPLOY_DIR"
    
    # Start services
    sudo systemctl start watchparty-backend watchparty-websocket
    sudo systemctl reload nginx
    
    echo "Rollback completed successfully!"
else
    echo "No backup file found!"
    exit 1
fi
EOF
    
    # Upload and execute rollback
    scp "/tmp/rollback.sh" "$server:/tmp/"
    ssh "$server" "chmod +x /tmp/rollback.sh && sudo /tmp/rollback.sh $backup_file"
    
    log_success "Rollback completed!"
}

# Zero-downtime deployment
zero_downtime_deploy() {
    local server="$1"
    
    log_info "Performing zero-downtime deployment to $server..."
    
    # This would involve blue-green deployment or rolling updates
    # For now, this is a placeholder
    log_warning "Zero-downtime deployment not yet implemented"
    log_info "Use regular deployment for now"
}

# Check deployment status
check_deployment_status() {
    local server="$1"
    
    if [[ -z "$server" ]]; then
        log_error "Server is required"
        exit 1
    fi
    
    log_info "Checking deployment status on $server..."
    
    # Create status check script
    cat > "/tmp/status_check.sh" << 'EOF'
#!/bin/bash

echo "=== Deployment Status ==="
echo "Date: $(date)"
echo

# Check services
echo "Services:"
systemctl is-active watchparty-backend && echo "  ✅ Backend: Running" || echo "  ❌ Backend: Not running"
systemctl is-active watchparty-websocket && echo "  ✅ WebSocket: Running" || echo "  ❌ WebSocket: Not running"
systemctl is-active nginx && echo "  ✅ Nginx: Running" || echo "  ❌ Nginx: Not running"

echo

# Check application
echo "Application:"
if curl -s http://localhost:8000/health/ > /dev/null; then
    echo "  ✅ Health check: OK"
else
    echo "  ❌ Health check: Failed"
fi

# Check logs for errors
echo
echo "Recent errors:"
tail -20 /var/log/nginx/watchparty_error.log 2>/dev/null | grep -i error | tail -5 || echo "  No recent errors"

echo
echo "Deployment info:"
if [[ -f "/var/www/watch-party-backend/.deployment_info" ]]; then
    cat /var/www/watch-party-backend/.deployment_info
else
    echo "  No deployment info found"
fi
EOF
    
    ssh "$server" "bash -s" < "/tmp/status_check.sh"
}

# Setup deployment environment
setup_deployment_env() {
    local server="$1"
    
    if [[ -z "$server" ]]; then
        log_error "Server is required"
        exit 1
    fi
    
    log_info "Setting up deployment environment on $server..."
    
    # Create setup script
    cat > "/tmp/setup_deploy.sh" << 'EOF'
#!/bin/bash
set -e

echo "Setting up Watch Party Backend deployment environment..."

# Install system dependencies
apt-get update
apt-get install -y python3 python3-venv python3-pip nginx postgresql postgresql-contrib redis-server

# Create application user
useradd -r -s /bin/false watchparty || true

# Create directories
mkdir -p /var/www/watch-party-backend
mkdir -p /var/log/watchparty
mkdir -p /var/backups/watch-party-backend

# Set permissions
chown -R www-data:www-data /var/www/watch-party-backend
chown -R www-data:www-data /var/log/watchparty

# Create systemd service files
cat > /etc/systemd/system/watchparty-backend.service << EOL
[Unit]
Description=Watch Party Backend
After=network.target postgresql.service redis.service

[Service]
Type=exec
User=www-data
Group=www-data
WorkingDirectory=/var/www/watch-party-backend
Environment=DJANGO_SETTINGS_MODULE=watchparty.settings.production
ExecStart=/var/www/watch-party-backend/venv/bin/gunicorn watchparty.wsgi:application --bind 127.0.0.1:8000
Restart=always

[Install]
WantedBy=multi-user.target
EOL

cat > /etc/systemd/system/watchparty-websocket.service << EOL
[Unit]
Description=Watch Party WebSocket
After=network.target postgresql.service redis.service

[Service]
Type=exec
User=www-data
Group=www-data
WorkingDirectory=/var/www/watch-party-backend
Environment=DJANGO_SETTINGS_MODULE=watchparty.settings.production
ExecStart=/var/www/watch-party-backend/venv/bin/daphne -b 127.0.0.1 -p 8001 watchparty.asgi:application
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd
systemctl daemon-reload

echo "Deployment environment setup completed!"
echo "Next steps:"
echo "1. Configure database (create user and database)"
echo "2. Configure environment variables"
echo "3. Deploy application"
echo "4. Configure Nginx"
EOF
    
    # Upload and execute setup
    scp "/tmp/setup_deploy.sh" "$server:/tmp/"
    ssh "$server" "sudo bash /tmp/setup_deploy.sh"
    
    log_success "Deployment environment setup completed!"
}

# Main command handler
main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        deploy|production)
            deploy_production "$@"
            ;;
        deploy-staging|staging)
            deploy_staging "$@"
            ;;
        deploy-to|to)
            deploy_to_server "$@"
            ;;
        rollback)
            rollback_deployment "$@"
            ;;
        zero-downtime|zdt)
            zero_downtime_deploy "$@"
            ;;
        status|check)
            check_deployment_status "$@"
            ;;
        setup-env|setup)
            setup_deployment_env "$@"
            ;;
        help|--help|-h)
            echo "Deployment Script Commands:"
            echo "  deploy, production      Create production deployment package"
            echo "  deploy-staging, staging Deploy to staging environment"
            echo "  deploy-to, to <server>  Deploy directly to server"
            echo "  rollback <server>       Rollback deployment on server"
            echo "  zero-downtime <server>  Zero-downtime deployment"
            echo "  status, check <server>  Check deployment status"
            echo "  setup-env <server>      Setup deployment environment"
            echo
            echo "Examples:"
            echo "  ./deployment.sh deploy                    # Create deployment package"
            echo "  ./deployment.sh deploy-to user@server    # Deploy to server"
            echo "  ./deployment.sh status user@server       # Check status"
            echo "  ./deployment.sh rollback user@server     # Rollback"
            ;;
        *)
            log_error "Unknown deployment command: $command"
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
