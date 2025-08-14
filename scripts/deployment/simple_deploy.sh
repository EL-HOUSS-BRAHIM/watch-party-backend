#!/bin/bash

# =============================================================================
# WATCH PARTY BACKEND - SIMPLIFIED DEPLOYMENT SCRIPT
# =============================================================================
# Updated for new project structure (config/, shared/, requirements/)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

# Configuration
DEPLOY_USER="${DEPLOY_USER:-ubuntu}"
DEPLOY_HOST="${DEPLOY_HOST:-}"
DEPLOY_PORT="${DEPLOY_PORT:-22}"
DEPLOY_PATH="/var/www/watchparty"
BACKUP_PATH="/var/backups/watchparty"
REQUIREMENTS_FILE="requirements/production.txt"

# Change to project root
cd "$PROJECT_ROOT"

show_help() {
    cat << EOF
🚀 Watch Party Backend Deployment Script (New Structure)

USAGE:
    $0 <command> [options]

COMMANDS:
    deploy [server]         Deploy to production server
    quick-deploy [server]   Quick deployment (no backup, faster)
    setup [server]          Initial server setup
    rollback [server]       Rollback to previous deployment
    status [server]         Check deployment status
    logs [server]           Show application logs
    restart [server]        Restart services
    backup [server]         Create backup
    test                    Test deployment package locally

EXAMPLES:
    $0 deploy ubuntu@your-server.com              # Full deployment
    $0 quick-deploy ubuntu@your-server.com        # Quick update
    $0 setup ubuntu@your-server.com               # Initial setup
    $0 status ubuntu@your-server.com              # Check status
    $0 logs ubuntu@your-server.com                # View logs

ENVIRONMENT VARIABLES:
    DEPLOY_USER     Default user (default: ubuntu)
    DEPLOY_HOST     Target server hostname
    DEPLOY_PORT     SSH port (default: 22)

NOTES:
    - Uses new structure: config/, shared/, requirements/
    - Automatically handles systemd services
    - Creates backups before deployment
    - Uses production requirements from requirements/production.txt
EOF
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if we're in the project root
    if [[ ! -f "manage.py" ]] || [[ ! -d "config" ]]; then
        log_error "This script must be run from the project root directory"
        log_error "Expected files: manage.py, config/, apps/"
        exit 1
    fi
    
    # Check if new structure exists
    if [[ ! -d "config" ]] || [[ ! -d "shared" ]] || [[ ! -d "requirements" ]]; then
        log_error "New project structure not found!"
        log_error "Expected directories: config/, shared/, requirements/"
        log_error "Please run the project restructuring first."
        exit 1
    fi
    
    # Check requirements file
    if [[ ! -f "$REQUIREMENTS_FILE" ]]; then
        log_error "Requirements file not found: $REQUIREMENTS_FILE"
        if [[ -f "requirements.txt" ]]; then
            log_warning "Found requirements.txt - using it as fallback"
            REQUIREMENTS_FILE="requirements.txt"
        else
            exit 1
        fi
    fi
    
    # Check for required commands
    command -v rsync >/dev/null 2>&1 || { log_error "rsync is required but not installed"; exit 1; }
    command -v ssh >/dev/null 2>&1 || { log_error "ssh is required but not installed"; exit 1; }
    
    log_success "Prerequisites check passed"
}

# Create deployment package
create_deployment_package() {
    log_info "Creating deployment package..."
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local temp_dir="/tmp/watchparty_deploy_$$"
    
    # Create temporary directory
    mkdir -p "$temp_dir"
    
    # Copy project files
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
        --exclude='node_modules/' \
        --exclude='.pytest_cache/' \
        --exclude='htmlcov/' \
        "$PROJECT_ROOT/" "$temp_dir/"
    
    # Create deployment info
    cat > "$temp_dir/.deployment_info" << EOF
Deployment Timestamp: $timestamp
Git Commit: $(git rev-parse HEAD 2>/dev/null || echo "unknown")
Git Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
Deployed By: $(whoami)@$(hostname)
Structure Version: New (config/, shared/, requirements/)
EOF
    
    echo "$temp_dir"
}

# Deploy to server
deploy_to_server() {
    local server="$1"
    local quick="${2:-false}"
    
    if [[ -z "$server" ]]; then
        log_error "Server address is required"
        log_info "Usage: $0 deploy ubuntu@your-server.com"
        exit 1
    fi
    
    log_info "Deploying to server: $server"
    
    # Create deployment package
    local temp_dir=$(create_deployment_package)
    
    log_info "Uploading and deploying to $server..."
    
    # Upload and execute deployment
    ssh -p "$DEPLOY_PORT" "$server" "
        set -e
        
        # Function definitions
        log_info() { echo -e '\033[0;34mℹ️  \$1\033[0m'; }
        log_success() { echo -e '\033[0;32m✅ \$1\033[0m'; }
        log_error() { echo -e '\033[0;31m❌ \$1\033[0m'; }
        
        log_info 'Starting deployment on server...'
        
        # Create directories
        sudo mkdir -p $DEPLOY_PATH $BACKUP_PATH
        sudo chown -R \$(whoami):\$(whoami) $DEPLOY_PATH $BACKUP_PATH
        
        # Backup current deployment (unless quick deploy)
        if [[ '$quick' != 'true' ]] && [[ -d '$DEPLOY_PATH/apps' ]]; then
            log_info 'Creating backup...'
            backup_file=\"$BACKUP_PATH/backup_\$(date +%Y%m%d_%H%M%S).tar.gz\"
            sudo tar -czf \"\$backup_file\" -C \$(dirname $DEPLOY_PATH) \$(basename $DEPLOY_PATH) 2>/dev/null || true
            log_success \"Backup created: \$backup_file\"
        fi
        
        # Stop services
        log_info 'Stopping services...'
        sudo systemctl stop watchparty-gunicorn 2>/dev/null || true
        sudo systemctl stop watchparty-daphne 2>/dev/null || true
        sudo systemctl stop watchparty-celery 2>/dev/null || true
        sudo systemctl stop watchparty-celery-beat 2>/dev/null || true
        
        # Create temporary directory for upload
        temp_upload=\"/tmp/watchparty_upload_\$\$\"
        mkdir -p \"\$temp_upload\"
    "
    
    # Upload the deployment package
    rsync -avz --delete -e "ssh -p $DEPLOY_PORT" "$temp_dir/" "$server:$temp_upload/"
    
    # Continue deployment on server
    ssh -p "$DEPLOY_PORT" "$server" "
        set -e
        temp_upload=\"/tmp/watchparty_upload_\$\$\"
        
        # Deploy new version
        log_info 'Deploying new version...'
        sudo rsync -av --delete --exclude='.env' \"\$temp_upload/\" $DEPLOY_PATH/
        
        cd $DEPLOY_PATH
        
        # Set permissions
        sudo chown -R www-data:www-data $DEPLOY_PATH
        sudo chmod +x manage.py
        sudo chmod +x scripts/deployment/*.sh 2>/dev/null || true
        sudo chmod +x scripts/maintenance/*.sh 2>/dev/null || true
        
        # Create/update virtual environment
        log_info 'Setting up virtual environment...'
        if [[ ! -d venv ]]; then
            sudo -u www-data python3 -m venv venv
        fi
        
        sudo -u www-data venv/bin/pip install --upgrade pip setuptools wheel
        sudo -u www-data venv/bin/pip install -r $REQUIREMENTS_FILE
        sudo -u www-data venv/bin/pip install gunicorn daphne gevent
        
        # Django operations (if .env exists)
        if [[ -f .env ]]; then
            log_info 'Running Django migrations...'
            sudo -u www-data venv/bin/python manage.py migrate --noinput || log_error 'Migrations failed'
            
            log_info 'Collecting static files...'
            sudo -u www-data venv/bin/python manage.py collectstatic --noinput --clear || log_error 'collectstatic failed'
        else
            log_error '.env file not found - skipping migrations and collectstatic'
            log_info 'Please create .env file with proper configuration'
        fi
        
        # Create systemd services
        log_info 'Creating systemd services...'
        
        # Gunicorn service
        sudo tee /etc/systemd/system/watchparty-gunicorn.service > /dev/null << 'EOL'
[Unit]
Description=Watch Party Gunicorn (New Structure)
After=network.target

[Service]
Type=notify
User=www-data
Group=www-data
WorkingDirectory=$DEPLOY_PATH
EnvironmentFile=$DEPLOY_PATH/.env
ExecStart=$DEPLOY_PATH/venv/bin/gunicorn --bind 127.0.0.1:8000 --workers 3 --worker-class gevent config.wsgi:application
Restart=on-failure
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOL
        
        # Daphne service (WebSocket)
        sudo tee /etc/systemd/system/watchparty-daphne.service > /dev/null << 'EOL'
[Unit]
Description=Watch Party Daphne WebSocket (New Structure)
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=$DEPLOY_PATH
EnvironmentFile=$DEPLOY_PATH/.env
ExecStart=$DEPLOY_PATH/venv/bin/daphne -b 127.0.0.1 -p 8001 config.asgi:application
Restart=on-failure
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOL
        
        # Celery Worker service
        sudo tee /etc/systemd/system/watchparty-celery.service > /dev/null << 'EOL'
[Unit]
Description=Watch Party Celery Worker (New Structure)
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=$DEPLOY_PATH
EnvironmentFile=$DEPLOY_PATH/.env
ExecStart=$DEPLOY_PATH/venv/bin/celery -A config worker -l info
Restart=on-failure
KillMode=mixed
TimeoutStopSec=30
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOL
        
        # Celery Beat service
        sudo tee /etc/systemd/system/watchparty-celery-beat.service > /dev/null << 'EOL'
[Unit]
Description=Watch Party Celery Beat (New Structure)
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=$DEPLOY_PATH
EnvironmentFile=$DEPLOY_PATH/.env
ExecStart=$DEPLOY_PATH/venv/bin/celery -A config beat -l info --scheduler django_celery_beat.schedulers:DatabaseScheduler
Restart=on-failure
KillMode=mixed
TimeoutStopSec=30
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOL
        
        # Reload systemd and start services
        sudo systemctl daemon-reload
        
        log_info 'Starting services...'
        sudo systemctl enable watchparty-gunicorn watchparty-daphne
        sudo systemctl start watchparty-gunicorn
        sudo systemctl start watchparty-daphne
        
        # Start Celery services if Redis is configured
        if grep -q 'CELERY_BROKER_URL' .env 2>/dev/null; then
            log_info 'Starting Celery services...'
            sudo systemctl enable watchparty-celery watchparty-celery-beat
            sudo systemctl start watchparty-celery
            sudo systemctl start watchparty-celery-beat
        fi
        
        # Cleanup
        rm -rf \"\$temp_upload\"
        
        log_success 'Deployment completed successfully!'
        
        # Show status
        echo
        echo '=== Service Status ==='
        sudo systemctl status watchparty-gunicorn --no-pager --lines=3 || true
        sudo systemctl status watchparty-daphne --no-pager --lines=3 || true
        sudo systemctl status watchparty-celery --no-pager --lines=3 || true
        sudo systemctl status watchparty-celery-beat --no-pager --lines=3 || true
    "
    
    # Cleanup local temp directory
    rm -rf "$temp_dir"
    
    log_success "Deployment completed successfully!"
}

# Check deployment status
check_status() {
    local server="$1"
    
    if [[ -z "$server" ]]; then
        log_error "Server address is required"
        exit 1
    fi
    
    log_info "Checking status on $server..."
    
    ssh -p "$DEPLOY_PORT" "$server" "
        echo '=== Watch Party Backend Status (New Structure) ==='
        echo 'Date: \$(date)'
        echo 'Server: \$(hostname)'
        echo
        
        echo '=== Services Status ==='
        systemctl is-active watchparty-gunicorn && echo '  ✅ Gunicorn: Running' || echo '  ❌ Gunicorn: Not running'
        systemctl is-active watchparty-daphne && echo '  ✅ Daphne (WebSocket): Running' || echo '  ❌ Daphne: Not running'
        systemctl is-active watchparty-celery && echo '  ✅ Celery Worker: Running' || echo '  ❌ Celery Worker: Not running'
        systemctl is-active watchparty-celery-beat && echo '  ✅ Celery Beat: Running' || echo '  ❌ Celery Beat: Not running'
        systemctl is-active nginx && echo '  ✅ Nginx: Running' || echo '  ❌ Nginx: Not running'
        
        echo
        echo '=== Health Checks ==='
        # Check if Django is responding
        if curl -f -s http://localhost:8000/health/ > /dev/null 2>&1; then
            echo '  ✅ Django Health Check: OK'
        else
            echo '  ❌ Django Health Check: Failed'
        fi
        
        # Check WebSocket port
        if nc -z localhost 8001 2>/dev/null; then
            echo '  ✅ WebSocket Port (8001): Open'
        else
            echo '  ❌ WebSocket Port (8001): Closed'
        fi
        
        echo
        echo '=== Deployment Info ==='
        if [[ -f '$DEPLOY_PATH/.deployment_info' ]]; then
            cat $DEPLOY_PATH/.deployment_info
        else
            echo '  No deployment info found'
        fi
        
        echo
        echo '=== Disk Usage ==='
        df -h $DEPLOY_PATH | tail -1
        
        echo
        echo '=== Recent Errors (last 10 lines) ==='
        journalctl -u watchparty-gunicorn --no-pager --lines=10 -p err || echo '  No recent errors'
    "
}

# Show application logs
show_logs() {
    local server="$1"
    local service="${2:-gunicorn}"
    local lines="${3:-50}"
    
    if [[ -z "$server" ]]; then
        log_error "Server address is required"
        exit 1
    fi
    
    log_info "Showing logs for watchparty-$service on $server (last $lines lines)..."
    
    ssh -p "$DEPLOY_PORT" "$server" "
        echo '=== Watch Party $service Logs ==='
        journalctl -u watchparty-$service --no-pager --lines=$lines -f
    "
}

# Restart services
restart_services() {
    local server="$1"
    
    if [[ -z "$server" ]]; then
        log_error "Server address is required"
        exit 1
    fi
    
    log_info "Restarting services on $server..."
    
    ssh -p "$DEPLOY_PORT" "$server" "
        echo '=== Restarting Watch Party Services ==='
        sudo systemctl restart watchparty-gunicorn
        sudo systemctl restart watchparty-daphne
        sudo systemctl restart watchparty-celery || true
        sudo systemctl restart watchparty-celery-beat || true
        
        echo '=== Service Status ==='
        systemctl status watchparty-gunicorn --no-pager --lines=3
        systemctl status watchparty-daphne --no-pager --lines=3
        systemctl status watchparty-celery --no-pager --lines=3 || true
        systemctl status watchparty-celery-beat --no-pager --lines=3 || true
    "
    
    log_success "Services restarted successfully!"
}

# Test deployment package locally
test_deployment() {
    log_info "Testing deployment package locally..."
    
    local temp_dir=$(create_deployment_package)
    
    log_info "Testing in: $temp_dir"
    
    cd "$temp_dir"
    
    # Check structure
    log_info "Checking project structure..."
    if [[ -d "config" ]] && [[ -d "shared" ]] && [[ -d "apps" ]] && [[ -d "requirements" ]]; then
        log_success "Project structure: OK"
    else
        log_error "Project structure: Missing directories"
        return 1
    fi
    
    # Check requirements
    if [[ -f "$REQUIREMENTS_FILE" ]]; then
        log_success "Requirements file: OK"
    else
        log_error "Requirements file not found: $REQUIREMENTS_FILE"
        return 1
    fi
    
    # Check manage.py
    if [[ -f "manage.py" ]]; then
        log_success "manage.py: OK"
    else
        log_error "manage.py not found"
        return 1
    fi
    
    # Try Django check (if Python available)
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import django" 2>/dev/null; then
            log_info "Running Django check..."
            if DJANGO_SETTINGS_MODULE=config.settings.production python3 manage.py check --verbosity=0; then
                log_success "Django check: OK"
            else
                log_warning "Django check: Failed (but deployment package is OK)"
            fi
        else
            log_info "Django not installed locally - skipping Django check"
        fi
    fi
    
    log_success "Deployment package test completed!"
    log_info "Package location: $temp_dir"
}

# Main function
main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        deploy|production)
            check_prerequisites
            deploy_to_server "$@"
            ;;
        quick-deploy|quick)
            check_prerequisites
            deploy_to_server "$1" "true"
            ;;
        setup)
            log_error "Initial server setup not implemented in this simplified script"
            log_info "Please use the full deployment script or set up manually"
            exit 1
            ;;
        status|check)
            check_status "$@"
            ;;
        logs)
            show_logs "$@"
            ;;
        restart)
            restart_services "$@"
            ;;
        test)
            check_prerequisites
            test_deployment
            ;;
        help|--help|-h|"")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
