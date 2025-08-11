#!/bin/bash

# Health Check Script for Watch Party Backend
# This script checks the health of all services and components

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="/var/www/watch-party-backend"
DOMAIN="${DOMAIN:-localhost}"
CHECK_EXTERNAL=${CHECK_EXTERNAL:-false}

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Function to print status
print_status() {
    local service="$1"
    local status="$2"
    local message="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ "$status" = "OK" ]; then
        echo -e "${GREEN}✅ $service: $status${NC} $message"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    elif [ "$status" = "WARNING" ]; then
        echo -e "${YELLOW}⚠️  $service: $status${NC} $message"
    else
        echo -e "${RED}❌ $service: $status${NC} $message"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

# Function to check service status
check_service() {
    local service="$1"
    
    if systemctl is-active --quiet "$service"; then
        print_status "$service" "OK" "(Active)"
    else
        print_status "$service" "FAILED" "(Inactive)"
    fi
}

# Function to check supervisor program
check_supervisor_program() {
    local program="$1"
    
    local status=$(supervisorctl status "$program" 2>/dev/null | awk '{print $2}')
    
    if [ "$status" = "RUNNING" ]; then
        print_status "$program" "OK" "(Running)"
    else
        print_status "$program" "FAILED" "($status)"
    fi
}

# Function to check HTTP endpoint
check_http() {
    local url="$1"
    local name="$2"
    local expected_code="${3:-200}"
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    
    if [ "$response" = "$expected_code" ]; then
        print_status "$name" "OK" "(HTTP $response)"
    else
        print_status "$name" "FAILED" "(HTTP $response)"
    fi
}

# Function to check database connection
check_database() {
    if [ -f "$PROJECT_DIR/.env" ]; then
        source "$PROJECT_DIR/.env"
        
        # Extract database info from DATABASE_URL
        if [ -n "$DATABASE_URL" ]; then
            # Try to connect to database
            if sudo -u postgres psql "$DATABASE_URL" -c "SELECT 1;" >/dev/null 2>&1; then
                print_status "PostgreSQL Connection" "OK" ""
            else
                print_status "PostgreSQL Connection" "FAILED" ""
            fi
        else
            print_status "PostgreSQL Connection" "FAILED" "(No DATABASE_URL)"
        fi
    else
        print_status "PostgreSQL Connection" "FAILED" "(No .env file)"
    fi
}

# Function to check Redis connection
check_redis() {
    if [ -f "$PROJECT_DIR/.env" ]; then
        source "$PROJECT_DIR/.env"
        
        # Extract Redis password from REDIS_URL
        if [ -n "$REDIS_URL" ]; then
            local redis_password=$(echo "$REDIS_URL" | grep -o ':[^@]*@' | sed 's/://g' | sed 's/@//g')
            
            if [ -n "$redis_password" ]; then
                if redis-cli -a "$redis_password" ping >/dev/null 2>&1; then
                    print_status "Redis Connection" "OK" ""
                else
                    print_status "Redis Connection" "FAILED" ""
                fi
            else
                if redis-cli ping >/dev/null 2>&1; then
                    print_status "Redis Connection" "OK" ""
                else
                    print_status "Redis Connection" "FAILED" ""
                fi
            fi
        else
            print_status "Redis Connection" "FAILED" "(No REDIS_URL)"
        fi
    else
        print_status "Redis Connection" "FAILED" "(No .env file)"
    fi
}

# Function to check disk space
check_disk_space() {
    local usage=$(df "$PROJECT_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$usage" -lt 80 ]; then
        print_status "Disk Space" "OK" "($usage% used)"
    elif [ "$usage" -lt 90 ]; then
        print_status "Disk Space" "WARNING" "($usage% used)"
    else
        print_status "Disk Space" "CRITICAL" "($usage% used)"
    fi
}

# Function to check memory usage
check_memory() {
    local mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    
    if [ "$mem_usage" -lt 80 ]; then
        print_status "Memory Usage" "OK" "($mem_usage% used)"
    elif [ "$mem_usage" -lt 90 ]; then
        print_status "Memory Usage" "WARNING" "($mem_usage% used)"
    else
        print_status "Memory Usage" "CRITICAL" "($mem_usage% used)"
    fi
}

# Function to check log file sizes
check_log_sizes() {
    local log_dir="$PROJECT_DIR/logs"
    local large_logs=""
    
    if [ -d "$log_dir" ]; then
        # Check for log files larger than 100MB
        while IFS= read -r -d '' file; do
            local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
            if [ "$size" -gt 104857600 ]; then  # 100MB
                large_logs="$large_logs $(basename "$file")"
            fi
        done < <(find "$log_dir" -name "*.log" -print0 2>/dev/null)
        
        if [ -z "$large_logs" ]; then
            print_status "Log File Sizes" "OK" ""
        else
            print_status "Log File Sizes" "WARNING" "(Large files:$large_logs)"
        fi
    else
        print_status "Log File Sizes" "FAILED" "(Log directory not found)"
    fi
}

# Function to check SSL certificate
check_ssl_certificate() {
    if [ "$CHECK_EXTERNAL" = "true" ] && [ "$DOMAIN" != "localhost" ]; then
        local cert_info=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
        
        if [ -n "$cert_info" ]; then
            local not_after=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
            local expiry_date=$(date -d "$not_after" +%s 2>/dev/null)
            local current_date=$(date +%s)
            local days_until_expiry=$(( (expiry_date - current_date) / 86400 ))
            
            if [ "$days_until_expiry" -gt 30 ]; then
                print_status "SSL Certificate" "OK" "($days_until_expiry days until expiry)"
            elif [ "$days_until_expiry" -gt 7 ]; then
                print_status "SSL Certificate" "WARNING" "($days_until_expiry days until expiry)"
            else
                print_status "SSL Certificate" "CRITICAL" "($days_until_expiry days until expiry)"
            fi
        else
            print_status "SSL Certificate" "FAILED" "(Cannot retrieve certificate)"
        fi
    else
        print_status "SSL Certificate" "SKIPPED" "(External check disabled)"
    fi
}

# Main health check function
main() {
    echo -e "${BLUE}"
    echo "================================================"
    echo "  Watch Party Backend - Health Check"
    echo "  $(date)"
    echo "================================================"
    echo -e "${NC}"
    
    echo -e "${YELLOW}Checking System Services...${NC}"
    check_service "nginx"
    check_service "postgresql"
    check_service "redis-server"
    check_service "supervisor"
    
    echo ""
    echo -e "${YELLOW}Checking Application Services...${NC}"
    check_supervisor_program "gunicorn"
    check_supervisor_program "daphne"
    check_supervisor_program "celery"
    check_supervisor_program "celerybeat"
    
    echo ""
    echo -e "${YELLOW}Checking External Dependencies...${NC}"
    check_database
    check_redis
    
    echo ""
    echo -e "${YELLOW}Checking HTTP Endpoints...${NC}"
    check_http "http://localhost:8000/health/" "Django App (Internal)"
    check_http "http://localhost:8001/" "Daphne WebSocket (Internal)" "404"
    
    if [ "$CHECK_EXTERNAL" = "true" ] && [ "$DOMAIN" != "localhost" ]; then
        check_http "https://$DOMAIN/health/" "External HTTPS"
        check_http "http://$DOMAIN/" "HTTP Redirect" "301"
    fi
    
    echo ""
    echo -e "${YELLOW}Checking System Resources...${NC}"
    check_disk_space
    check_memory
    check_log_sizes
    
    echo ""
    echo -e "${YELLOW}Checking Security...${NC}"
    check_ssl_certificate
    
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  Health Check Summary${NC}"
    echo -e "${BLUE}================================================${NC}"
    
    if [ "$FAILED_CHECKS" -eq 0 ]; then
        echo -e "${GREEN}✅ All systems operational${NC}"
        echo -e "${GREEN}   Passed: $PASSED_CHECKS/$TOTAL_CHECKS${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some checks failed${NC}"
        echo -e "${RED}   Failed: $FAILED_CHECKS/$TOTAL_CHECKS${NC}"
        echo -e "${GREEN}   Passed: $PASSED_CHECKS/$TOTAL_CHECKS${NC}"
        exit 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --external)
            CHECK_EXTERNAL=true
            shift
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --external              Check external endpoints and SSL"
            echo "  --domain DOMAIN         Set domain for external checks"
            echo "  --help                  Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                      # Basic health check"
            echo "  $0 --external --domain api.yoursite.com"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main function
main
