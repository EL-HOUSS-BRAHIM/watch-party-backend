#!/bin/bash

# =============================================================================
# GITHUB ACTIONS SECRETS SETTER SCRIPT
# =============================================================================
# This script sets GitHub Actions secrets for a repository using the GitHub CLI
# Author: Watch Party Team
# Version: 1.0

set -e

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

readonly CHECK="✅"
readonly CROSS="❌"
readonly WARNING="⚠️"
readonly INFO="ℹ️"

log_info() { echo -e "${BLUE}${INFO} $1${NC}"; }
log_success() { echo -e "${GREEN}${CHECK} $1${NC}"; }
log_warning() { echo -e "${YELLOW}${WARNING} $1${NC}"; }
log_error() { echo -e "${RED}${CROSS} $1${NC}"; }

print_header() {
    echo
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    🔐 GitHub Actions Secrets Setter                          ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

check_github_cli() {
    if command -v gh &> /dev/null; then
        return 0
    else
        log_warning "GitHub CLI (gh) not found. Install it to automatically set secrets."
        log_info "Visit: https://cli.github.com/"
        return 1
    fi
}

set_secrets_with_gh() {
    local env_file="${1:-.env}"
    
    if [[ ! -f "$env_file" ]]; then
        log_error "Environment file not found: $env_file"
        return 1
    fi
    
    if ! check_github_cli; then
        return 1
    fi
    
    log_info "Setting GitHub secrets using GitHub CLI..."
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not in a git repository"
        return 1
    fi
    
    # Check if authenticated with GitHub
    if ! gh auth status &> /dev/null; then
        log_error "Not authenticated with GitHub CLI. Run: gh auth login"
        return 1
    fi
    
    # Read secrets from env file and set them
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ $key =~ ^#.*$ ]] && continue
        [[ -z $key ]] && continue
        
        # Remove quotes from value
        value=$(echo "$value" | sed 's/^["'\'']//' | sed 's/["'\'']$//')
        
        if [[ -n $value ]]; then
            echo "Setting secret: $key"
            echo "$value" | gh secret set "$key"
        fi
    done < <(grep -v '^#' "$env_file" | grep -v '^$')
    
    log_success "Secrets set successfully!"
}

main() {
    print_header
    
    case "${1:-}" in
        --help|-h)
            echo "GitHub Actions Secrets Setter Script"
            echo
            echo "Usage: $0 [env_file]"
            echo
            echo "This script sets GitHub Actions secrets for a repository using the GitHub CLI"
            echo "and reads secrets from the specified environment file."
            echo
            echo "Options:"
            echo "  env_file   Path to the environment file (default: .env)"
            echo "  --help     Show this help message"
            ;;
        *)
            set_secrets_with_gh "${1:-.env}"
            ;;
    esac
}

main "$@"
