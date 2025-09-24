# Watch Party Backend Deployment Script

This deployment script (`deploy.sh`) provides automated setup and management for the Watch Party backend application with PM2, Nginx, and SSL support optimized for Cloudflare.

## Features

- **PM2 Process Management**: Django (Gunicorn), WebSocket (Daphne), Celery Worker, and Celery Beat
- **Nginx Configuration**: HTTP and HTTPS configurations with Cloudflare optimization
- **SSL Support**: Cloudflare Origin SSL certificate integration
- **Service Management**: Start, stop, and monitor all services
- **Security**: Rate limiting, security headers, and attack prevention

## Domains

- **Backend API**: `https://be-watch-party.brahim-elhouss.me`
- **Frontend**: `https://watch-party.brahim-elhouss.me`

## Prerequisites

- Ubuntu/Debian server with root access
- Python 3.8+ with pip
- Git repository cloned to `/workspaces/watch-party-backend`
- Domain configured with Cloudflare

## Usage

Run the script as root:

```bash
sudo ./deploy.sh
```

## Menu Options

### 1. Initialize PM2
- Installs Node.js and PM2 if not present
- Creates Python virtual environment
- Installs Python dependencies
- Runs Django migrations
- Collects static files
- Starts all PM2 processes (Django, WebSocket, Celery)

**Services started:**
- `watchparty-django`: Gunicorn server (port 8000)
- `watchparty-daphne`: WebSocket server (port 8002)
- `watchparty-celery-worker`: Background task worker
- `watchparty-celery-beat`: Periodic task scheduler

### 2. Install Nginx with HTTP
- Installs Nginx if not present
- Configures HTTP-only setup for development/testing
- Includes Cloudflare IP forwarding
- Sets up rate limiting and security headers
- Enables static file serving

**Use for:**
- Development environments
- Testing before SSL setup
- Initial domain validation

### 3. Install Nginx with HTTPS
- Configures production HTTPS setup
- Requires Cloudflare Origin SSL certificates
- Full security headers and HSTS
- HTTP to HTTPS redirect
- Production-ready configuration

**SSL Certificate Setup:**
1. Go to Cloudflare Dashboard → SSL/TLS → Origin Server
2. Create certificate for your domains
3. Save certificate as: `/etc/ssl/certs/cloudflare-origin.pem`
4. Save private key as: `/etc/ssl/private/cloudflare-origin.key`
5. Set permissions: `chmod 600 /etc/ssl/private/cloudflare-origin.key`

### 4. Stop All Services
- Stops all PM2 processes
- Stops Nginx
- Optionally stops Redis and PostgreSQL
- Clean shutdown of all components

### 5. Show Service Status
- PM2 process status
- Nginx service status
- SSL certificate status
- System resource usage

## File Structure

```
/workspaces/watch-party-backend/
├── deploy.sh              # Main deployment script
├── ecosystem.config.js    # PM2 configuration
├── nginx.conf            # HTTPS Nginx configuration
└── ...

/var/log/watchparty/       # Log directory
├── nginx_access.log
├── nginx_error.log
├── gunicorn_access.log
├── pm2_*.log
└── ...

/var/www/watchparty/       # Static files
├── staticfiles/
└── media/
```

## Configuration Details

### PM2 Ecosystem
- **Django**: 4 Gunicorn workers with gevent
- **WebSocket**: Daphne ASGI server
- **Celery**: Worker with 2 concurrent processes
- **Beat**: Scheduler for periodic tasks

### Nginx Features
- **Cloudflare Integration**: Real IP forwarding, headers
- **Security**: Rate limiting, security headers, attack prevention
- **Performance**: Gzip compression, static file caching, keepalive
- **SSL**: Strong ciphers, HSTS, secure protocols

### Security Features
- Rate limiting on API endpoints (30/min) and login (5/min)
- Security headers (HSTS, XSS, CSRF protection)
- Blocked file extensions and common attack patterns
- Real IP detection through Cloudflare

## Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   sudo chmod +x deploy.sh
   sudo ./deploy.sh
   ```

2. **SSL Certificate Not Found**
   - Ensure certificates are in correct paths
   - Check file permissions (600 for private key)
   - Verify certificate format

3. **PM2 Processes Not Starting**
   - Check Python virtual environment
   - Verify Django settings
   - Review PM2 logs: `pm2 logs`

4. **Nginx Configuration Errors**
   - Test configuration: `nginx -t`
   - Check log files in `/var/log/watchparty/`
   - Verify upstream servers are running

### Log Files
- **Nginx**: `/var/log/watchparty/nginx_*.log`
- **Django**: `/var/log/watchparty/gunicorn_*.log`
- **PM2**: `/var/log/watchparty/pm2_*.log`

### Monitoring Commands
```bash
# PM2 status
pm2 status
pm2 logs

# Nginx status
systemctl status nginx
nginx -t

# Resource usage
htop
df -h
free -h
```

## Environment Variables

Ensure these are set in your `.env` file:
- `DJANGO_SETTINGS_MODULE=config.settings.production`
- Database settings
- Redis/Celery settings
- Secret keys and security settings

## Support

For issues or questions:
1. Check log files for errors
2. Verify all prerequisites are met
3. Ensure proper file permissions
4. Review Cloudflare DNS settings

## Updates

To update the deployment:
1. Pull latest code changes
2. Run option 1 to restart PM2 processes
3. Run option 3 to reload Nginx if configs changed