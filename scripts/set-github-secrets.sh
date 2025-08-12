#!/bin/bash

# =============================================================================
# GITHUB ACTIONS SECRETS SETTER SCRIPT
# =============================================================================
# This script sets GitHub Actions secrets for a repository using the GitHub CLI
# Author: Watch Party Team
# Version: 2.0

set -e

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

readonly CHECK="✅"
readonly CROSS="❌"
readonly WARNING="⚠️"
readonly INFO="ℹ️"
readonly ROCKET="🚀"

log_info() { echo -e "${BLUE}${INFO} $1${NC}"; }
log_success() { echo -e "${GREEN}${CHECK} $1${NC}"; }
log_warning() { echo -e "${YELLOW}${WARNING} $1${NC}"; }
log_error() { echo -e "${RED}${CROSS} $1${NC}"; }
log_title() { echo -e "${WHITE}$1${NC}"; }

print_header() {
    echo
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    🔐 GitHub Actions Secrets Manager                         ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Deployment-specific secrets that might not be in .env
declare -A DEPLOYMENT_SECRETS=(
    ["DEPLOY_HOST"]="be-watch-party.brahim-elhouss.me"
    ["DEPLOY_USER"]="ubuntu"
    ["DEPLOY_PORT"]="22"
    ["SSH_PRIVATE_KEY"]="# Add your SSH private key here"
    # Add these if they're not in .env but needed for deployment
    ["EMAIL_HOST_USER"]="your-email@gmail.com"
    ["EMAIL_HOST_PASSWORD"]="your-app-password"
    ["EMAIL_USE_TLS"]="True"
    ["GOOGLE_OAUTH2_KEY"]="your-google-client-id"
    ["GOOGLE_OAUTH2_SECRET"]="your-google-client-secret"
    ["GITHUB_CLIENT_ID"]="your-github-client-id"
    ["GITHUB_CLIENT_SECRET"]="your-github-client-secret"
    ["AWS_ACCESS_KEY_ID"]="your-aws-access-key"
    ["AWS_SECRET_ACCESS_KEY"]="your-aws-secret-key"
    ["AWS_STORAGE_BUCKET_NAME"]="your-s3-bucket"
)

check_github_cli() {
    if command -v gh &> /dev/null; then
        return 0
    else
        log_error "GitHub CLI (gh) not found. Install it first:"
        log_info "Visit: https://cli.github.com/"
        log_info "Or run: sudo apt update && sudo apt install gh"
        return 1
    fi
}

check_git_and_auth() {
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
    
    return 0
}

list_secrets() {
    log_info "Listing current repository secrets..."
    
    if ! check_github_cli; then
        return 1
    fi
    
    if ! check_git_and_auth; then
        return 1
    fi
    
    echo
    log_title "Current Repository Secrets:"
    echo
    
    local secrets=$(gh secret list --json name,updatedAt | jq -r '.[] | "\(.name) (updated: \(.updatedAt))"' 2>/dev/null)
    
    if [[ -n "$secrets" ]]; then
        while IFS= read -r secret; do
            echo "  🔐 $secret"
        done <<< "$secrets"
    else
        echo "  No secrets found or jq not available"
        gh secret list 2>/dev/null || echo "  Failed to list secrets"
    fi
    
    echo
}

drop_all_secrets() {
    log_warning "This will DELETE ALL repository secrets!"
    
    if ! check_github_cli; then
        log_error "GitHub CLI not found"
        return 1
    fi
    
    if ! check_git_and_auth; then
        log_error "Not authenticated with GitHub CLI or not in a git repository"
        log_info "Run: gh auth login"
        return 1
    fi
    
    # Check if we have proper permissions
    log_info "Checking repository permissions..."
    if ! gh repo view &>/dev/null; then
        log_error "Cannot access repository or insufficient permissions"
        log_info "Make sure you have admin access to this repository"
        return 1
    fi
    
    # Confirmation prompt
    echo
    read -p "Are you sure you want to delete ALL secrets? (type 'YES' to confirm): " confirmation
    
    if [[ "$confirmation" != "YES" ]]; then
        log_info "Operation cancelled"
        return 0
    fi
    
    log_info "Deleting all repository secrets..."
    
    # Get list of secret names
    local secret_names=$(gh secret list --json name | jq -r '.[].name' 2>/dev/null)
    
    if [[ -z "$secret_names" ]]; then
        log_info "No secrets found to delete"
        return 0
    fi
    
    local deleted_count=0
    local failed_count=0
    
    while IFS= read -r secret_name; do
        if [[ -n "$secret_name" ]]; then
            echo "Deleting secret: $secret_name"
            
            # Try to delete with more verbose error handling
            if output=$(gh secret delete "$secret_name" --confirm 2>&1); then
                log_success "Deleted: $secret_name"
                ((deleted_count++))
            else
                log_warning "Failed to delete: $secret_name"
                if [[ "$output" == *"not found"* ]]; then
                    log_info "  Reason: Secret not found"
                elif [[ "$output" == *"permission"* ]] || [[ "$output" == *"forbidden"* ]]; then
                    log_info "  Reason: Insufficient permissions"
                else
                    log_info "  Error: $output"
                fi
                ((failed_count++))
            fi
        fi
    done <<< "$secret_names"
    
    echo
    if [[ $failed_count -gt 0 ]]; then
        log_warning "Deleted $deleted_count secrets, failed to delete $failed_count secrets"
        echo
        log_info "Common reasons for deletion failure:"
        log_info "  • Insufficient repository permissions (need admin access)"
        log_info "  • Organization policies preventing secret deletion"
        log_info "  • Rate limiting (try again in a few minutes)"
        log_info "  • Secrets may be organization-level secrets (not repository secrets)"
    else
        log_success "Successfully deleted $deleted_count secrets"
    fi
}

check_missing_deployment_secrets() {
    log_info "Checking for missing deployment secrets..."
    
    if ! check_github_cli; then
        return 1
    fi
    
    if ! check_git_and_auth; then
        return 1
    fi
    
    echo
    log_title "Deployment Secrets Status:"
    echo
    
    local missing_secrets=()
    local existing_secrets=()
    
    # Get current secrets
    local current_secrets=$(gh secret list --json name | jq -r '.[].name' 2>/dev/null)
    
    # Required deployment secrets (critical ones)
    local required_secrets=(
        "DEPLOY_HOST"
        "DEPLOY_USER" 
        "SSH_PRIVATE_KEY"
        "SECRET_KEY"
        "DATABASE_URL"
        "ALLOWED_HOSTS"
    )
    
    for secret in "${required_secrets[@]}"; do
        if echo "$current_secrets" | grep -q "^$secret$"; then
            existing_secrets+=("$secret")
            echo "  ✅ $secret (exists)"
        else
            missing_secrets+=("$secret")
            echo "  ❌ $secret (missing - REQUIRED)"
        fi
    done
    
    echo
    log_title "Optional Deployment Secrets:"
    echo
    
    # Optional deployment secrets
    local optional_secrets=(
        "EMAIL_HOST_USER"
        "EMAIL_HOST_PASSWORD"
        "GOOGLE_OAUTH2_KEY"
        "GOOGLE_OAUTH2_SECRET"
        "GITHUB_CLIENT_ID"
        "GITHUB_CLIENT_SECRET"
        "AWS_ACCESS_KEY_ID"
        "AWS_SECRET_ACCESS_KEY"
    )
    
    for secret in "${optional_secrets[@]}"; do
        if echo "$current_secrets" | grep -q "^$secret$"; then
            echo "  ✅ $secret (exists)"
        else
            echo "  ⚠️  $secret (missing - optional)"
        fi
    done
    
    echo
    if [ ${#missing_secrets[@]} -gt 0 ]; then
        log_warning "Missing ${#missing_secrets[@]} required deployment secrets: ${missing_secrets[*]}"
        echo
        log_info "To set missing secrets, run:"
        log_info "  $0 --set-missing"
        log_info "  $0 --deploy-secrets"
        log_info "  $0 .env  # to set all from .env file"
    else
        log_success "All required deployment secrets are present!"
    fi
}
    log_info "Setting deployment-specific secrets..."
    
    for secret_name in "${!DEPLOYMENT_SECRETS[@]}"; do
        local secret_value="${DEPLOYMENT_SECRETS[$secret_name]}"
        
        if [[ "$secret_name" == "SSH_PRIVATE_KEY" ]]; then
            log_warning "Please set SSH_PRIVATE_KEY manually with your actual private key"
            echo "  Run: gh secret set SSH_PRIVATE_KEY < /path/to/your/private/key"
            continue
        fi
        
        echo "Setting deployment secret: $secret_name"
        echo "$secret_value" | gh secret set "$secret_name"
    done
}

set_missing_secrets() {
    log_info "Setting only missing deployment secrets..."
    
    if ! check_github_cli; then
        return 1
    fi
    
    if ! check_git_and_auth; then
        return 1
    fi
    
    # Get current secrets
    local current_secrets=$(gh secret list --json name | jq -r '.[].name' 2>/dev/null)
    
    # Required deployment secrets with default values
    local -A required_secrets=(
        ["DEPLOY_HOST"]="be-watch-party.brahim-elhouss.me"
        ["DEPLOY_USER"]="ubuntu"
        ["DEPLOY_PORT"]="22"
        ["SSH_PRIVATE_KEY"]="# Please set your SSH private key manually"
    )
    
    local set_count=0
    
    for secret_name in "${!required_secrets[@]}"; do
        if ! echo "$current_secrets" | grep -q "^$secret_name$"; then
            local secret_value="${required_secrets[$secret_name]}"
            
            if [[ "$secret_name" == "SSH_PRIVATE_KEY" ]]; then
                log_warning "SSH_PRIVATE_KEY is missing but must be set manually"
                echo "  Run: gh secret set SSH_PRIVATE_KEY < /path/to/your/private/key"
                continue
            fi
            
            echo "Setting missing secret: $secret_name"
            if echo "$secret_value" | gh secret set "$secret_name"; then
                log_success "Set: $secret_name"
                ((set_count++))
            else
                log_warning "Failed to set: $secret_name"
            fi
        fi
    done
    
    if [[ $set_count -eq 0 ]]; then
        log_info "No missing secrets to set (excluding SSH_PRIVATE_KEY)"
    else
        log_success "Set $set_count missing secrets"
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
    
    if ! check_git_and_auth; then
        return 1
    fi
    
    log_info "Setting GitHub secrets from $env_file..."
    
    local secrets_set=0
    local secrets_skipped=0
    
    # Read secrets from env file and set them
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ $key =~ ^#.*$ ]] && continue
        [[ -z $key ]] && continue
        
        # Remove leading/trailing whitespace from key
        key=$(echo "$key" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        
        # Remove quotes and whitespace from value
        value=$(echo "$value" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/^["'\'']//' | sed 's/["'\'']$//')
        
        if [[ -n "$value" && "$value" != "your-"* && "$value" != "" ]]; then
            echo "Setting secret: $key"
            if echo "$value" | gh secret set "$key" 2>/dev/null; then
                ((secrets_set++))
            else
                log_warning "Failed to set secret: $key"
            fi
        else
            log_warning "Skipping empty or placeholder value: $key"
            ((secrets_skipped++))
        fi
    done < <(grep -v '^#' "$env_file" | grep -v '^$' | grep '=')
    
    echo
    log_success "Set $secrets_set secrets successfully"
    if [[ $secrets_skipped -gt 0 ]]; then
        log_warning "Skipped $secrets_skipped secrets with empty/placeholder values"
    fi
    
    # Also set deployment-specific secrets
    echo
    set_deployment_secrets
}

show_help() {
    echo -e "${WHITE}USAGE:${NC}"
    echo -e "  $0 [OPTIONS] [env_file]"
    echo
    echo -e "${WHITE}DESCRIPTION:${NC}"
    echo -e "  This script manages GitHub Actions secrets for a repository using the GitHub CLI."
    echo -e "  It can set secrets from an environment file, list existing secrets, or remove all secrets."
    echo
    echo -e "${WHITE}OPTIONS:${NC}"
    echo -e "  ${GREEN}--set [env_file]${NC}        Set secrets from environment file (default: .env)"
    echo -e "  ${GREEN}--list${NC}                  List all current repository secrets"
    echo -e "  ${GREEN}--drop${NC}                  Delete ALL repository secrets (requires confirmation)"
    echo -e "  ${GREEN}--check${NC}                 Check which deployment secrets are missing"
    echo -e "  ${GREEN}--set-missing${NC}           Set only missing deployment secrets"
    echo -e "  ${GREEN}--deploy-secrets${NC}        Set deployment-specific secrets"
    echo -e "  ${GREEN}--help, -h${NC}              Show this help message"
    echo
    echo -e "${WHITE}EXAMPLES:${NC}"
    echo -e "  $0                      # Set secrets from .env file"
    echo -e "  $0 --set .env.prod      # Set secrets from .env.prod file"
    echo -e "  $0 --list               # List all current secrets"
    echo -e "  $0 --check              # Check missing deployment secrets"
    echo -e "  $0 --set-missing        # Set only missing deployment secrets"
    echo -e "  $0 --drop               # Delete all secrets (dangerous!)"
    echo
    echo -e "${WHITE}REQUIREMENTS:${NC}"
    echo -e "  • GitHub CLI (gh) installed and authenticated"
    echo -e "  • Must be run from within a Git repository"
    echo -e "  • Repository admin access to manage secrets"
    echo
    echo -e "${WHITE}NOTES:${NC}"
    echo -e "  • SSH_PRIVATE_KEY must be set manually for security"
    echo -e "  • Empty or placeholder values (starting with 'your-') are skipped"
    echo -e "  • Use ${GREEN}--check${NC} first to see what secrets are missing"
    echo -e "  • The --drop option requires admin permissions and may fail for org-level secrets"
    echo
}

main() {
    print_header
    
    case "${1:-}" in
        --set)
            set_secrets_with_gh "${2:-.env}"
            ;;
        --list)
            list_secrets
            ;;
        --drop)
            drop_all_secrets
            ;;
        --check|--check-missing)
            check_missing_deployment_secrets
            ;;
        --set-missing)
            set_missing_secrets
            ;;
        --deploy-secrets)
            set_deployment_secrets
            ;;
        --help|-h)
            show_help
            ;;
        "")
            # Default action: set secrets from .env
            set_secrets_with_gh ".env"
            ;;
        *)
            # If first argument doesn't start with --, treat it as env file
            if [[ "$1" == -* ]]; then
                log_error "Unknown option: $1"
                echo "Use --help for available options"
                exit 1
            else
                set_secrets_with_gh "$1"
            fi
            ;;
    esac
}
            if [[ ! "$1" =~ ^-- ]]; then
                set_secrets_with_gh "$1"
            else
                log_error "Unknown option: $1"
                echo
                show_help
                exit 1
            fi
            ;;
    esac
}

main "$@"
