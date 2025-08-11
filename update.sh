#!/bin/bash

# Update Script for Watch Party Backend
# This script updates the application with minimal downtime

set -e

# Configuration
PROJECT_DIR="${PROJECT_DIR:-/var/www/watch-party-backend}"
PROJECT_USER="${PROJECT_USER:-watchparty}"
BACKUP_DIR="/var/backups/watchparty/updates"

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

# Check if project directory exists
check_project() {
    if [ ! -d "$PROJECT_DIR" ]; then
        error "Project directory $PROJECT_DIR does not exist. Run initial deployment first."
    fi
    
    if [ ! -f "$PROJECT_DIR/.env" ]; then
        error "Environment file not found. Project may not be properly deployed."
    fi
}

# Create backup
create_backup() {
    log "Creating backup before update..."
    
    mkdir -p "$BACKUP_DIR"
    local backup_name="pre-update-$(date +%Y%m%d_%H%M%S)"
    
    # Backup application files
    tar -czf "$BACKUP_DIR/$backup_name.tar.gz" -C "$PROJECT_DIR" \
        --exclude='venv' --exclude='logs/*.log' --exclude='*.pyc' --exclude='__pycache__' \
        . 2>/dev/null || true
    
    # Backup database
    if [ -f "$PROJECT_DIR/.env" ]; then
        source "$PROJECT_DIR/.env"
        if [ -n "$DATABASE_URL" ]; then
            sudo -u postgres pg_dump "$DATABASE_URL" > "$BACKUP_DIR/$backup_name-db.sql" 2>/dev/null || true
        fi
    fi
    
    log "Backup created: $backup_name"
}

# Update code from git
update_code() {
    log "Updating code from git repository..."
    
    cd "$PROJECT_DIR"
    
    # Fetch latest changes
    sudo -u "$PROJECT_USER" git fetch origin
    
    # Get current branch
    local current_branch=$(sudo -u "$PROJECT_USER" git rev-parse --abbrev-ref HEAD)
    log "Current branch: $current_branch"
    
    # Check for local changes
    if ! sudo -u "$PROJECT_USER" git diff --quiet HEAD; then
        warn "Local changes detected. Stashing them..."
        sudo -u "$PROJECT_USER" git stash push -m "Auto-stash before update $(date)"
    fi
    
    # Pull latest changes
    sudo -u "$PROJECT_USER" git pull origin "$current_branch"
    
    log "Code updated successfully"
}

# Update Python dependencies
update_dependencies() {
    log "Updating Python dependencies..."
    
    cd "$PROJECT_DIR"
    
    # Backup current virtual environment
    if [ -d "venv" ]; then
        sudo -u "$PROJECT_USER" cp -r venv venv.backup
    fi
    
    # Update pip and dependencies
    sudo -u "$PROJECT_USER" ./venv/bin/pip install --upgrade pip
    sudo -u "$PROJECT_USER" ./venv/bin/pip install -r requirements.txt --upgrade
    
    log "Dependencies updated successfully"
}

# Run Django management commands
run_django_commands() {
    log "Running Django management commands..."
    
    cd "$PROJECT_DIR"
    
    # Load environment
    source .env
    
    # Run migrations
    log "Running database migrations..."
    sudo -u "$PROJECT_USER" ./venv/bin/python manage.py migrate --settings=watchparty.settings.production
    
    # Collect static files
    log "Collecting static files..."
    sudo -u "$PROJECT_USER" ./venv/bin/python manage.py collectstatic --noinput --settings=watchparty.settings.production
    
    # Clear cache (if using Redis)
    if [ -n "$REDIS_URL" ]; then
        log "Clearing application cache..."
        sudo -u "$PROJECT_USER" ./venv/bin/python manage.py shell --settings=watchparty.settings.production << 'EOF'
from django.core.cache import cache
cache.clear()
print("Cache cleared successfully")
EOF
    fi
    
    log "Django commands completed successfully"
}

# Update supervisor configuration
update_supervisor() {
    log "Updating supervisor configuration..."
    
    # Reload supervisor configuration
    supervisorctl reread
    supervisorctl update
    
    log "Supervisor configuration updated"
}

# Restart services with zero downtime
restart_services() {
    log "Restarting services..."
    
    # Restart services one by one to minimize downtime
    log "Restarting Celery workers..."
    supervisorctl restart celery || warn "Failed to restart celery"
    
    log "Restarting Celery beat..."
    supervisorctl restart celerybeat || warn "Failed to restart celerybeat"
    
    log "Restarting Daphne (WebSocket server)..."
    supervisorctl restart daphne || warn "Failed to restart daphne"
    
    log "Restarting Gunicorn (Django app)..."
    supervisorctl restart gunicorn || warn "Failed to restart gunicorn"
    
    # Reload Nginx configuration
    log "Reloading Nginx..."
    nginx -t && systemctl reload nginx || warn "Failed to reload nginx"
    
    log "Services restarted successfully"
}

# Health check
health_check() {
    log "Running health check..."
    
    # Wait for services to start
    sleep 10
    
    # Check if Django app is responding
    if curl -f http://localhost:8000/health/ > /dev/null 2>&1; then
        log "✅ Django app health check passed"
    else
        error "❌ Django app health check failed"
    fi
    
    # Check if WebSocket server is responding
    if curl -f http://localhost:8001/ > /dev/null 2>&1; then
        log "✅ WebSocket server is running"
    else
        warn "⚠️ WebSocket server may not be responding"
    fi
    
    log "Health check completed"
}

# Rollback function
rollback() {
    error_msg="$1"
    log "Rolling back due to error: $error_msg"
    
    # Stop services
    supervisorctl stop all
    
    # Restore virtual environment if backup exists
    if [ -d "$PROJECT_DIR/venv.backup" ]; then
        sudo -u "$PROJECT_USER" rm -rf "$PROJECT_DIR/venv"
        sudo -u "$PROJECT_USER" mv "$PROJECT_DIR/venv.backup" "$PROJECT_DIR/venv"
    fi
    
    # Start services
    supervisorctl start all
    
    error "Rollback completed. Update failed: $error_msg"
}

# Main update function
main() {
    log "Starting Watch Party Backend update..."
    
    # Pre-update checks
    check_root
    check_project
    
    # Create backup
    create_backup
    
    # Update steps with error handling
    {
        update_code &&
        update_dependencies &&
        run_django_commands &&
        update_supervisor &&
        restart_services &&
        health_check
    } || {
        rollback "Update process failed"
    }
    
    # Cleanup backup venv if everything succeeded
    if [ -d "$PROJECT_DIR/venv.backup" ]; then
        sudo rm -rf "$PROJECT_DIR/venv.backup"
    fi
    
    log "Update completed successfully!"
    
    # Display summary
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  Update Summary${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo "✅ Code updated from git repository"
    echo "✅ Python dependencies updated"
    echo "✅ Database migrations applied"
    echo "✅ Static files collected"
    echo "✅ Services restarted"
    echo "✅ Health check passed"
    echo ""
    echo -e "${GREEN}Your Watch Party Backend has been updated successfully!${NC}"
    echo ""
    echo "To view service status: sudo supervisorctl status"
    echo "To view logs: sudo tail -f $PROJECT_DIR/logs/*.log"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --project-dir)
            PROJECT_DIR="$2"
            shift 2
            ;;
        --project-user)
            PROJECT_USER="$2"
            shift 2
            ;;
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --project-dir DIR       Project directory (default: /var/www/watch-party-backend)"
            echo "  --project-user USER     Project user (default: watchparty)"
            echo "  --skip-backup           Skip creating backup before update"
            echo "  --help                  Show this help message"
            echo ""
            echo "This script will:"
            echo "  1. Create a backup of the current deployment"
            echo "  2. Pull the latest code from git"
            echo "  3. Update Python dependencies"
            echo "  4. Run Django migrations and collect static files"
            echo "  5. Restart all services with minimal downtime"
            echo "  6. Verify the update with a health check"
            exit 0
            ;;
        *)
            error "Unknown option: $1. Use --help for usage information."
            ;;
    esac
done

# Trap errors and attempt rollback
trap 'rollback "Script interrupted"' INT TERM

# Run main function
main
