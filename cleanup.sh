#!/bin/bash

# Watch Party Backend - Project Cleanup Script
# This script performs comprehensive cleanup of the project

set -e

echo "🧹 Starting Watch Party Backend Cleanup..."
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to cleanup Python cache files
cleanup_python_cache() {
    log_info "Cleaning Python cache files..."
    
    # Remove .pyc files
    find . -name "*.pyc" -type f -delete 2>/dev/null || true
    
    # Remove __pycache__ directories
    find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    
    log_success "Python cache files cleaned"
}

# Function to cleanup log files
cleanup_log_files() {
    log_info "Cleaning log files..."
    
    # Remove main logfile
    rm -f logfile 2>/dev/null || true
    
    # Remove other log files
    rm -f *.log *.out *.err 2>/dev/null || true
    
    # Clean logs directory but keep the directory structure
    if [ -d "logs" ]; then
        rm -f logs/*.log 2>/dev/null || true
        touch logs/django.log  # Recreate main log file
    else
        mkdir -p logs
        touch logs/django.log
    fi
    
    log_success "Log files cleaned"
}

# Function to cleanup temporary files
cleanup_temp_files() {
    log_info "Cleaning temporary files..."
    
    # Remove various temporary file types
    find . \( -name "*.tmp" -o -name "*.temp" -o -name "*.bak" -o -name "*.backup" \
             -o -name "*.swp" -o -name "*.swo" -o -name ".DS_Store" -o -name "Thumbs.db" \
             -o -name "*.orig" -o -name "*.rej" \) -type f -delete 2>/dev/null || true
    
    log_success "Temporary files cleaned"
}

# Function to optimize imports
optimize_imports() {
    log_info "Optimizing imports..."
    
    # Install autoflake if not present
    if ! command -v autoflake &> /dev/null; then
        log_info "Installing autoflake..."
        pip install autoflake --quiet 2>/dev/null || log_warning "Could not install autoflake"
    fi
    
    # Install isort if not present
    if ! command -v isort &> /dev/null; then
        log_info "Installing isort..."
        pip install isort --quiet 2>/dev/null || log_warning "Could not install isort"
    fi
    
    # Remove unused imports
    if command -v autoflake &> /dev/null; then
        autoflake --remove-all-unused-imports --remove-unused-variables \
                  --in-place --recursive . --exclude=migrations 2>/dev/null || \
        log_warning "Some issues with autoflake, but continuing..."
    fi
    
    # Sort imports
    if command -v isort &> /dev/null; then
        isort . --skip=migrations --skip=venv --profile=django 2>/dev/null || \
        log_warning "Some issues with isort, but continuing..."
    fi
    
    log_success "Import optimization completed"
}

# Function to clean Django static files
cleanup_django_static() {
    log_info "Cleaning Django static files..."
    
    # Only run if we can set up Django
    if python -c "import django; django.setup()" 2>/dev/null; then
        python manage.py collectstatic --clear --noinput 2>/dev/null || \
        log_warning "Static files cleanup skipped (database might not be available)"
    else
        log_warning "Django setup failed, skipping static files cleanup"
    fi
    
    log_success "Django static files cleanup completed"
}

# Function to optimize Git repository
optimize_git() {
    log_info "Optimizing Git repository..."
    
    if [ -d ".git" ]; then
        git gc --prune=now 2>/dev/null && log_success "Git repository optimized" || \
        log_warning "Git optimization failed"
    else
        log_warning "Not a Git repository, skipping Git optimization"
    fi
}

# Function to validate project structure
validate_structure() {
    log_info "Validating project structure..."
    
    # Check for critical files and directories
    critical_paths=("manage.py" "requirements.txt" "apps" "core" "watchparty")
    
    for path in "${critical_paths[@]}"; do
        if [ -e "$path" ]; then
            log_success "Found: $path"
        else
            log_error "Missing: $path"
            return 1
        fi
    done
    
    log_success "Project structure validation passed"
}

# Function to show disk usage
show_disk_usage() {
    log_info "Showing disk usage..."
    
    echo "Top directories by size:"
    du -sh */ 2>/dev/null | sort -hr | head -5 || true
    
    echo ""
    echo "Total project size:"
    du -sh . 2>/dev/null || true
}

# Function to run project health check
run_health_check() {
    log_info "Running project health check..."
    
    if [ -f "check_todo_status.py" ]; then
        # Ensure logs directory exists
        mkdir -p logs
        touch logs/django.log
        
        # Run the health check and show only the summary
        python check_todo_status.py 2>/dev/null | tail -10 || \
        log_warning "Health check encountered some issues"
    else
        log_warning "Health check script not found"
    fi
}

# Main cleanup function
main() {
    local start_time=$(date +%s)
    
    echo "Starting cleanup at $(date)"
    echo ""
    
    # Run all cleanup operations
    cleanup_python_cache
    cleanup_log_files  
    cleanup_temp_files
    optimize_imports
    cleanup_django_static
    optimize_git
    validate_structure
    
    echo ""
    echo "========================================"
    echo "🎉 CLEANUP COMPLETED!"
    echo "========================================"
    
    show_disk_usage
    
    echo ""
    run_health_check
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo "========================================"
    echo "⏱️  Cleanup completed in ${duration} seconds"
    echo "📅 Cleanup finished at $(date)"
    echo "========================================"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Watch Party Backend Cleanup Script"
        echo ""
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --cache-only   Clean only Python cache files"
        echo "  --logs-only    Clean only log files"
        echo "  --temp-only    Clean only temporary files"
        echo "  --imports-only Optimize only imports"
        echo "  --git-only     Optimize only Git repository"
        echo ""
        echo "Default: Run full cleanup"
        exit 0
        ;;
    --cache-only)
        cleanup_python_cache
        ;;
    --logs-only)
        cleanup_log_files
        ;;
    --temp-only)
        cleanup_temp_files
        ;;
    --imports-only)
        optimize_imports
        ;;
    --git-only)
        optimize_git
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
