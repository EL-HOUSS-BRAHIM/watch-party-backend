#!/bin/bash

# Quick Setup Script for Watch Party Backend
# This script helps you set up the deployment quickly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "================================================"
echo "  Watch Party Backend - Quick Setup"
echo "================================================"
echo -e "${NC}"

# Function to prompt for input with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local result
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " result
        echo "${result:-$default}"
    else
        read -p "$prompt: " result
        echo "$result"
    fi
}

# Function to prompt for password
prompt_password() {
    local prompt="$1"
    local result
    
    read -s -p "$prompt: " result
    echo ""
    echo "$result"
}

echo -e "${GREEN}This script will help you deploy the Watch Party Backend.${NC}"
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${GREEN}✅ Running as root${NC}"
else
    echo -e "${RED}❌ This script must be run as root. Please run with sudo.${NC}"
    exit 1
fi

# Get configuration from user
echo -e "${YELLOW}Please provide the following information:${NC}"
echo ""

DOMAIN=$(prompt_with_default "Domain name (e.g., api.yoursite.com)" "")
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}❌ Domain name is required${NC}"
    exit 1
fi

EMAIL=$(prompt_with_default "Email for SSL certificates" "admin@$DOMAIN")

# Optional custom passwords
echo ""
echo -e "${YELLOW}You can set custom passwords or press Enter to auto-generate secure ones:${NC}"

DB_PASSWORD=$(prompt_password "Database password (press Enter to auto-generate)")
if [ -z "$DB_PASSWORD" ]; then
    DB_PASSWORD=$(openssl rand -base64 32)
    echo -e "${GREEN}✅ Database password auto-generated${NC}"
fi

REDIS_PASSWORD=$(prompt_password "Redis password (press Enter to auto-generate)")
if [ -z "$REDIS_PASSWORD" ]; then
    REDIS_PASSWORD=$(openssl rand -base64 32)
    echo -e "${GREEN}✅ Redis password auto-generated${NC}"
fi

# Check if deploy script exists
if [ ! -f "./deploy.sh" ]; then
    echo -e "${RED}❌ deploy.sh not found in current directory${NC}"
    echo "Please run this script from the project root directory."
    exit 1
fi

# Make deploy script executable
chmod +x deploy.sh

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Deployment Configuration${NC}"
echo -e "${BLUE}================================================${NC}"
echo "Domain: $DOMAIN"
echo "Email: $EMAIL"
echo "Database Password: [HIDDEN]"
echo "Redis Password: [HIDDEN]"
echo ""

# Confirm deployment
echo -e "${YELLOW}Are you ready to start the deployment? This will:${NC}"
echo "• Install system dependencies"
echo "• Set up PostgreSQL and Redis"
echo "• Configure Nginx with SSL"
echo "• Deploy the Django application"
echo "• Set up process monitoring"
echo ""

read -p "Continue with deployment? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}🚀 Starting deployment...${NC}"

# Export environment variables for the deploy script
export DOMAIN="$DOMAIN"
export DB_PASSWORD="$DB_PASSWORD"
export REDIS_PASSWORD="$REDIS_PASSWORD"

# Run the deployment script
if ./deploy.sh; then
    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}  🎉 Deployment Successful!${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo -e "${BLUE}Your Watch Party Backend is now live at:${NC}"
    echo -e "${GREEN}https://$DOMAIN${NC}"
    echo ""
    echo -e "${BLUE}Admin Interface:${NC}"
    echo -e "${GREEN}https://$DOMAIN/admin/${NC}"
    echo -e "${YELLOW}Username: admin${NC}"
    echo -e "${YELLOW}Password: admin123${NC}"
    echo ""
    echo -e "${RED}⚠️  IMPORTANT: Change the default admin password immediately!${NC}"
    echo ""
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "• Check services: sudo supervisorctl status"
    echo "• View logs: sudo tail -f /var/www/watch-party-backend/logs/*.log"
    echo "• Backup: sudo /usr/local/bin/backup-watchparty.sh"
    echo ""
    echo -e "${BLUE}Configuration saved to:${NC}"
    echo "• Environment: /var/www/watch-party-backend/.env"
    echo "• Nginx: /etc/nginx/sites-available/watch-party-backend"
    echo ""
    echo -e "${GREEN}✅ Setup complete! Your application is ready for GitHub Actions CI/CD.${NC}"
    echo -e "${YELLOW}📖 See DEPLOYMENT.md for GitHub Actions setup instructions.${NC}"
else
    echo ""
    echo -e "${RED}================================================${NC}"
    echo -e "${RED}  ❌ Deployment Failed${NC}"
    echo -e "${RED}================================================${NC}"
    echo ""
    echo -e "${YELLOW}Please check the error messages above and try again.${NC}"
    echo "You can also run the deployment script manually with:"
    echo "sudo DOMAIN=$DOMAIN DB_PASSWORD='[hidden]' REDIS_PASSWORD='[hidden]' ./deploy.sh"
    exit 1
fi
