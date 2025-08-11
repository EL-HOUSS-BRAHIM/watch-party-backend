#!/bin/bash

# =============================================================================
# WATCH PARTY BACKEND - MAIN MANAGEMENT SCRIPT
# =============================================================================
# This is the main entry point for all project management operations
# Author: Watch Party Team
# Version: 2.0
# Last Updated: August 11, 2025

set -e

# =============================================================================
# CONFIGURATION & CONSTANTS
# =============================================================================

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
PROJECT_ROOT="$SCRIPT_DIR"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Emoji for better UX
readonly CHECK="✅"
readonly CROSS="❌"
readonly WARNING="⚠️"
readonly INFO="ℹ️"
readonly ROCKET="🚀"
readonly GEAR="⚙️"
readonly CLEAN="🧹"
readonly BACKUP="💾"
readonly DEPLOY="🌐"
readonly MONITOR="📊"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log_info() {
    echo -e "${BLUE}${INFO} $1${NC}"
}

log_success() {
    echo -e "${GREEN}${CHECK} $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}${WARNING} $1${NC}"
}

log_error() {
    echo -e "${RED}${CROSS} $1${NC}"
}

log_title() {
    echo -e "${WHITE}$1${NC}"
}

show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                          WATCH PARTY BACKEND                                ║
║                         Management Script v2.0                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                    🎬 Video Collaboration Platform                          ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Check if script exists and is executable
check_script() {
    local script_path="$1"
    if [[ ! -f "$script_path" ]]; then
        log_error "Script not found: $script_path"
        return 1
    fi
    if [[ ! -x "$script_path" ]]; then
        log_warning "Making script executable: $script_path"
        chmod +x "$script_path"
    fi
    return 0
}

# Execute a script with error handling
execute_script() {
    local script_path="$1"
    shift
    local args="$@"
    
    if check_script "$script_path"; then
        log_info "Executing: $(basename "$script_path") $args"
        "$script_path" $args
        return $?
    else
        log_error "Cannot execute script: $script_path"
        return 1
    fi
}

# Check if we're in the right directory
check_project_root() {
    if [[ ! -f "manage.py" ]] || [[ ! -d "apps" ]] || [[ ! -d "watchparty" ]]; then
        log_error "This doesn't appear to be the Watch Party Backend project root"
        log_error "Please run this script from the project root directory"
        exit 1
    fi
}

# Show system information
show_system_info() {
    echo -e "${CYAN}${GEAR} System Information:${NC}"
    echo "  • Date: $(date)"
    echo "  • User: $(whoami)"
    echo "  • PWD: $(pwd)"
    echo "  • Python: $(python --version 2>/dev/null || echo 'Not found')"
    echo "  • Django: $(python -c 'import django; print(django.get_version())' 2>/dev/null || echo 'Not found')"
    echo "  • Git Branch: $(git branch --show-current 2>/dev/null || echo 'Not a git repo')"
    echo
}

# =============================================================================
# HELP & USAGE FUNCTIONS
# =============================================================================

show_help() {
    show_banner
    echo -e "${WHITE}USAGE:${NC}"
    echo "  ./manage.sh [COMMAND] [OPTIONS]"
    echo
    echo -e "${WHITE}DEVELOPMENT COMMANDS:${NC}"
    echo -e "  ${GREEN}dev${NC}                    Start development server"
    echo -e "  ${GREEN}dev-ws${NC}                 Start development server with WebSocket support"
    echo -e "  ${GREEN}shell${NC}                  Open Django shell"
    echo -e "  ${GREEN}dbshell${NC}               Open database shell"
    echo -e "  ${GREEN}test${NC}                   Run tests"
    echo -e "  ${GREEN}migrate${NC}               Run database migrations"
    echo -e "  ${GREEN}makemigrations${NC}        Create new migrations"
    echo -e "  ${GREEN}collectstatic${NC}         Collect static files"
    echo -e "  ${GREEN}createsuperuser${NC}       Create Django superuser"
    echo
    echo -e "${WHITE}PROJECT MANAGEMENT:${NC}"
    echo -e "  ${BLUE}install${NC}                Install dependencies"
    echo -e "  ${BLUE}setup${NC}                  Complete project setup"
    echo -e "  ${BLUE}check${NC}                  Run health checks"
    echo -e "  ${BLUE}status${NC}                 Show project status"
    echo -e "  ${BLUE}logs${NC}                   View application logs"
    echo -e "  ${BLUE}clean${NC}                  Clean project files"
    echo -e "  ${BLUE}reset${NC}                  Reset database and start fresh"
    echo
    echo -e "${WHITE}ENVIRONMENT CONFIGURATION:${NC}"
    echo -e "  ${CYAN}setup-env${NC}              Interactive development environment setup"
    echo -e "  ${CYAN}setup-env-prod${NC}         Interactive production environment setup"
    echo -e "  ${CYAN}quick-env${NC}              Quick development environment setup"
    echo -e "  ${CYAN}quick-env-prod${NC}         Quick production environment setup"
    echo -e "  ${CYAN}validate-env${NC}           Validate .env file"
    echo -e "  ${CYAN}env-status${NC}             Show environment status"
    echo
    echo -e "${WHITE}DEPLOYMENT & SERVER:${NC}"
    echo -e "  ${MAGENTA}deploy${NC}                 Deploy to production server"
    echo -e "  ${MAGENTA}deploy-staging${NC}        Deploy to staging server"
    echo -e "  ${MAGENTA}server-setup${NC}          Setup production server"
    echo -e "  ${MAGENTA}server-update${NC}         Update server configuration"
    echo -e "  ${MAGENTA}nginx-config${NC}          Configure Nginx"
    echo -e "  ${MAGENTA}ssl-setup${NC}             Setup SSL certificates"
    echo
    echo -e "${WHITE}PRODUCTION MANAGEMENT:${NC}"
    echo -e "  ${CYAN}prod-setup${NC}             Complete production server setup"
    echo -e "  ${CYAN}prod-start${NC}             Start production services"
    echo -e "  ${CYAN}prod-stop${NC}              Stop production services"
    echo -e "  ${CYAN}prod-restart${NC}           Restart production services"
    echo -e "  ${CYAN}prod-status${NC}            Show production service status"
    echo -e "  ${CYAN}prod-logs${NC}              View production logs"
    echo -e "  ${CYAN}check-ports${NC}            Check for port conflicts"
    echo -e "  ${CYAN}fix-ports${NC}              Resolve port conflicts"
    echo -e "  ${CYAN}validate-env${NC}           Validate environment configuration"
    echo -e "  ${CYAN}fix-env${NC}                Fix environment issues"
    echo -e "  ${CYAN}setup-env${NC}              Interactive environment setup"
    echo
    echo -e "${WHITE}MAINTENANCE & BACKUP:${NC}"
    echo -e "  ${YELLOW}backup${NC}                 Create project backup"
    echo -e "  ${YELLOW}restore${NC}                Restore from backup"
    echo -e "  ${YELLOW}db-backup${NC}              Backup database only"
    echo -e "  ${YELLOW}db-restore${NC}             Restore database only"
    echo -e "  ${YELLOW}monitor${NC}                Show monitoring dashboard"
    echo
    echo -e "${WHITE}DESTRUCTIVE OPERATIONS:${NC}"
    echo -e "  ${RED}wipeout${NC}                Complete project removal"
    echo -e "  ${RED}nuke${NC}                   Nuclear option - remove everything"
    echo
    echo -e "${WHITE}UTILITY COMMANDS:${NC}"
    echo -e "  ${CYAN}docker${NC}                 Docker operations"
    echo -e "  ${CYAN}env${NC}                    Environment management"
    echo -e "  ${CYAN}git${NC}                    Git operations"
    echo -e "  ${CYAN}security${NC}               Security checks and updates"
    echo
    echo -e "${WHITE}OPTIONS:${NC}"
    echo -e "  ${GREEN}--help, -h${NC}             Show this help message"
    echo -e "  ${GREEN}--version, -v${NC}          Show version information"
    echo -e "  ${GREEN}--verbose${NC}              Enable verbose output"
    echo -e "  ${GREEN}--dry-run${NC}              Show what would be done without executing"
    echo -e "  ${GREEN}--force${NC}                Force operation without confirmation"
    echo
    echo -e "${WHITE}EXAMPLES:${NC}"
    echo "  ./manage.sh dev                     # Start development server"
    echo "  ./manage.sh quick-env               # Quick environment setup with defaults"
    echo "  ./manage.sh setup-env               # Interactive environment setup"
    echo "  ./manage.sh validate-env            # Validate .env file"
    echo "  ./manage.sh env-status              # Show environment status"
    echo "  ./manage.sh prod-setup              # Setup production server"
    echo "  ./manage.sh prod-status             # Check production status"
    echo "  ./manage.sh check-ports             # Check for port conflicts"
    echo "  ./manage.sh validate-env production # Validate production environment"
    echo "  ./manage.sh fix-env development     # Fix development environment"
    echo "  ./manage.sh deploy --staging        # Deploy to staging"
    echo "  ./manage.sh backup --compress       # Create compressed backup"
    echo "  ./manage.sh clean --deep            # Deep clean with optimization"
    echo "  ./manage.sh wipeout --force         # Complete removal without prompts"
    echo
    echo -e "${YELLOW}For detailed documentation, see: docs/README.md${NC}"
}

show_version() {
    show_banner
    echo -e "${WHITE}Version Information:${NC}"
    echo "  • Management Script: 2.0"
    echo "  • Project: Watch Party Backend"
    echo "  • Author: Watch Party Team"
    echo "  • Last Updated: August 11, 2025"
    echo
}

# =============================================================================
# MAIN COMMAND ROUTING
# =============================================================================

# Development commands
cmd_dev() {
    execute_script "$SCRIPTS_DIR/development.sh" "start" "$@"
}

cmd_dev_ws() {
    execute_script "$SCRIPTS_DIR/development.sh" "start-ws" "$@"
}

cmd_shell() {
    execute_script "$SCRIPTS_DIR/development.sh" "shell" "$@"
}

cmd_dbshell() {
    execute_script "$SCRIPTS_DIR/development.sh" "dbshell" "$@"
}

cmd_test() {
    execute_script "$SCRIPTS_DIR/development.sh" "test" "$@"
}

cmd_migrate() {
    execute_script "$SCRIPTS_DIR/development.sh" "migrate" "$@"
}

cmd_makemigrations() {
    execute_script "$SCRIPTS_DIR/development.sh" "makemigrations" "$@"
}

cmd_collectstatic() {
    execute_script "$SCRIPTS_DIR/development.sh" "collectstatic" "$@"
}

cmd_createsuperuser() {
    execute_script "$SCRIPTS_DIR/development.sh" "createsuperuser" "$@"
}

# Project management commands
cmd_install() {
    execute_script "$SCRIPTS_DIR/setup.sh" "install" "$@"
}

cmd_setup() {
    execute_script "$SCRIPTS_DIR/setup.sh" "full-setup" "$@"
}

cmd_check() {
    execute_script "$SCRIPTS_DIR/health.sh" "check" "$@"
}

cmd_status() {
    execute_script "$SCRIPTS_DIR/health.sh" "status" "$@"
}

cmd_logs() {
    execute_script "$SCRIPTS_DIR/monitoring.sh" "logs" "$@"
}

cmd_clean() {
    execute_script "$SCRIPTS_DIR/cleanup.sh" "clean" "$@"
}

cmd_reset() {
    execute_script "$SCRIPTS_DIR/development.sh" "reset" "$@"
}

# Environment configuration commands
cmd_setup_env() {
    execute_script "$SCRIPTS_DIR/env-setup.sh" "interactive-dev" "$@"
}

cmd_setup_env_prod() {
    execute_script "$SCRIPTS_DIR/env-setup.sh" "interactive-prod" "$@"
}

cmd_quick_env() {
    execute_script "$SCRIPTS_DIR/env-setup.sh" "quick-dev" "$@"
}

cmd_quick_env_prod() {
    execute_script "$SCRIPTS_DIR/env-setup.sh" "quick-prod" "$@"
}

cmd_validate_env() {
    execute_script "$SCRIPTS_DIR/env-setup.sh" "validate" "$@"
}

cmd_env_status() {
    execute_script "$SCRIPTS_DIR/env-setup.sh" "status" "$@"
}

# Deployment commands
cmd_deploy() {
    execute_script "$SCRIPTS_DIR/deployment.sh" "deploy" "$@"
}

cmd_deploy_staging() {
    execute_script "$SCRIPTS_DIR/deployment.sh" "deploy-staging" "$@"
}

cmd_server_setup() {
    execute_script "$SCRIPTS_DIR/server-setup.sh" "setup" "$@"
}

cmd_server_update() {
    execute_script "$SCRIPTS_DIR/server-setup.sh" "update" "$@"
}

cmd_nginx_config() {
    execute_script "$SCRIPTS_DIR/nginx-config.sh" "configure" "$@"
}

cmd_ssl_setup() {
    execute_script "$SCRIPTS_DIR/ssl-setup.sh" "setup" "$@"
}

# Production server management commands
cmd_prod() {
    execute_script "$SCRIPTS_DIR/production.sh" "$@"
}

cmd_prod_setup() {
    execute_script "$SCRIPTS_DIR/production.sh" "setup" "$@"
}

cmd_prod_start() {
    execute_script "$SCRIPTS_DIR/production.sh" "start" "$@"
}

cmd_prod_stop() {
    execute_script "$SCRIPTS_DIR/production.sh" "stop" "$@"
}

cmd_prod_restart() {
    execute_script "$SCRIPTS_DIR/production.sh" "restart" "$@"
}

cmd_prod_status() {
    execute_script "$SCRIPTS_DIR/production.sh" "status" "$@"
}

cmd_prod_logs() {
    execute_script "$SCRIPTS_DIR/production.sh" "logs" "$@"
}

cmd_check_ports() {
    execute_script "$SCRIPTS_DIR/production.sh" "check-ports" "$@"
}

cmd_fix_ports() {
    execute_script "$SCRIPTS_DIR/production.sh" "resolve-ports" "$@"
}

# Environment validation commands
cmd_validate_env() {
    execute_script "$SCRIPTS_DIR/env-validator.sh" "validate" "$@"
}

cmd_fix_env() {
    execute_script "$SCRIPTS_DIR/env-validator.sh" "fix" "$@"
}

cmd_setup_env() {
    execute_script "$SCRIPTS_DIR/env-validator.sh" "interactive" "$@"
}

# Backup and maintenance commands
cmd_backup() {
    execute_script "$SCRIPTS_DIR/backup.sh" "backup" "$@"
}

cmd_restore() {
    execute_script "$SCRIPTS_DIR/backup.sh" "restore" "$@"
}

cmd_db_backup() {
    execute_script "$SCRIPTS_DIR/backup.sh" "db-backup" "$@"
}

cmd_db_restore() {
    execute_script "$SCRIPTS_DIR/backup.sh" "db-restore" "$@"
}

cmd_monitor() {
    execute_script "$SCRIPTS_DIR/monitoring.sh" "dashboard" "$@"
}

# Destructive operations
cmd_wipeout() {
    execute_script "$SCRIPTS_DIR/wipeout.sh" "wipeout" "$@"
}

cmd_nuke() {
    execute_script "$SCRIPTS_DIR/wipeout.sh" "nuke" "$@"
}

# Utility commands
cmd_docker() {
    execute_script "$SCRIPTS_DIR/docker.sh" "$@"
}

cmd_env() {
    execute_script "$SCRIPTS_DIR/environment.sh" "$@"
}

cmd_git() {
    execute_script "$SCRIPTS_DIR/git-ops.sh" "$@"
}

cmd_security() {
    execute_script "$SCRIPTS_DIR/security.sh" "$@"
}

# =============================================================================
# MAIN EXECUTION LOGIC
# =============================================================================

main() {
    # Check if we're in the right directory
    check_project_root
    
    # Parse global options
    local verbose=false
    local dry_run=false
    local force=false
    
    # Process global flags
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose)
                verbose=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                show_version
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Export global options for use in scripts
    export VERBOSE=$verbose
    export DRY_RUN=$dry_run
    export FORCE=$force
    
    # Show verbose info if requested
    if [[ "$verbose" == "true" ]]; then
        show_system_info
    fi
    
    # Get the command
    local command="${1:-help}"
    shift || true
    
    # Execute the appropriate command
    case "$command" in
        # Development commands
        dev|start)              cmd_dev "$@" ;;
        dev-ws|start-ws)        cmd_dev_ws "$@" ;;
        shell)                  cmd_shell "$@" ;;
        dbshell)                cmd_dbshell "$@" ;;
        test|tests)             cmd_test "$@" ;;
        migrate)                cmd_migrate "$@" ;;
        makemigrations)         cmd_makemigrations "$@" ;;
        collectstatic)          cmd_collectstatic "$@" ;;
        createsuperuser)        cmd_createsuperuser "$@" ;;
        
        # Project management
        install|requirements)   cmd_install "$@" ;;
        setup|init)             cmd_setup "$@" ;;
        check|health)           cmd_check "$@" ;;
        status|info)            cmd_status "$@" ;;
        logs|log)               cmd_logs "$@" ;;
        clean|cleanup)          cmd_clean "$@" ;;
        reset|restart)          cmd_reset "$@" ;;
        
        # Environment configuration
        setup-env)              cmd_setup_env "$@" ;;
        setup-env-prod)         cmd_setup_env_prod "$@" ;;
        quick-env)              cmd_quick_env "$@" ;;
        quick-env-prod)         cmd_quick_env_prod "$@" ;;
        validate-env)           cmd_validate_env "$@" ;;
        env-status)             cmd_env_status "$@" ;;
        env)                    cmd_env_status "$@" ;;
        
        # Deployment
        deploy)                 cmd_deploy "$@" ;;
        deploy-staging)         cmd_deploy_staging "$@" ;;
        server-setup)           cmd_server_setup "$@" ;;
        server-update)          cmd_server_update "$@" ;;
        nginx-config|nginx)     cmd_nginx_config "$@" ;;
        ssl-setup|ssl)          cmd_ssl_setup "$@" ;;
        
        # Production management
        prod)                   cmd_prod "$@" ;;
        prod-setup)             cmd_prod_setup "$@" ;;
        prod-start)             cmd_prod_start "$@" ;;
        prod-stop)              cmd_prod_stop "$@" ;;
        prod-restart)           cmd_prod_restart "$@" ;;
        prod-status)            cmd_prod_status "$@" ;;
        prod-logs)              cmd_prod_logs "$@" ;;
        check-ports)            cmd_check_ports "$@" ;;
        fix-ports)              cmd_fix_ports "$@" ;;
        production)             cmd_prod "$@" ;;
        
        # Environment validation
        validate-env)           cmd_validate_env "$@" ;;
        fix-env)                cmd_fix_env "$@" ;;
        setup-env)              cmd_setup_env "$@" ;;
        
        # Backup and maintenance
        backup)                 cmd_backup "$@" ;;
        restore)                cmd_restore "$@" ;;
        db-backup)              cmd_db_backup "$@" ;;
        db-restore)             cmd_db_restore "$@" ;;
        monitor|monitoring)     cmd_monitor "$@" ;;
        
        # Destructive operations
        wipeout)                cmd_wipeout "$@" ;;
        nuke)                   cmd_nuke "$@" ;;
        
        # Utility commands
        docker)                 cmd_docker "$@" ;;
        env|environment)        cmd_env "$@" ;;
        git)                    cmd_git "$@" ;;
        security)               cmd_security "$@" ;;
        
        # Help and info
        help|--help|-h)         show_help ;;
        version|--version|-v)   show_version ;;
        
        # Unknown command
        *)
            log_error "Unknown command: $command"
            echo
            echo "Available commands:"
            echo "  dev, shell, test, migrate, setup, deploy, backup, clean, wipeout"
            echo "  prod-setup, prod-start, prod-stop, prod-status, check-ports"
            echo "  validate-env, fix-env, setup-env"
            echo
            echo "Use './manage.sh help' for detailed usage information"
            exit 1
            ;;
    esac
}

# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
