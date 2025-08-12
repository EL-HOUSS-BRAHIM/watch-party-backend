# 🚀 GitHub Actions Deployment Guide

This directory contains GitHub Actions workflows for automated deployment and monitoring of the Watch Party Backend project.

## 📋 Table of Contents

- [Overview](#overview)
- [Workflows](#workflows)
- [Setup Instructions](#setup-instructions)
- [Required Secrets](#required-secrets)
- [Deployment Types](#deployment-types)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)

## 🎯 Overview

The GitHub Actions workflows provide:

- **Automated deployment** to production servers
- **Health monitoring** of deployed applications
- **Automated backups** of application data
- **Fresh server setup** from scratch
- **Verification** of successful deployments

## 🔄 Workflows

### 1. Deploy to Production (`deploy.yml`)

**Triggers:**
- Push to `master`/`main` branch
- Manual trigger with deployment options

**Features:**
- Pre-deployment validation
- Optional testing
- Multiple deployment types (update, fresh_setup, full_rebuild)
- Environment file creation from secrets
- Deployment verification
- Rollback capability

### 2. Health Check (`health-check.yml`)

**Triggers:**
- Every 30 minutes (scheduled)
- Manual trigger with check types

**Features:**
- Quick, full, or deep health checks
- Service status monitoring
- Application endpoint testing
- Alert on failures

### 3. Backup (`backup.yml`)

**Triggers:**
- Daily at 2 AM UTC (scheduled)
- Manual trigger with backup options

**Features:**
- Database backups
- File system backups
- Full project backups
- Automatic cleanup of old backups

## 🛠️ Setup Instructions

### 1. Generate Secrets Template

Run the GitHub Actions setup script to generate a template:

```bash
./manage.sh github-setup --generate
```

This creates `github-secrets-template.txt` with all required secrets.

### 2. Configure Repository Secrets

Go to your GitHub repository:
1. Navigate to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add each secret from the template

### 3. Set Up SSH Access

Generate an SSH key pair for deployment:

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -C "github-actions@yourproject.com" -f ~/.ssh/github_actions_key

# Copy public key to your server
ssh-copy-id -i ~/.ssh/github_actions_key.pub user@your-server.com

# Add private key to GitHub secrets as SSH_PRIVATE_KEY
cat ~/.ssh/github_actions_key
```

### 4. Prepare Your Server

Ensure your production server has:
- Ubuntu 20.04+ or similar Linux distribution
- sudo access for the deployment user
- SSH access enabled
- Required ports open (80, 443, 22)

## 🔐 Required Secrets

### Essential Secrets (Required)

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `DEPLOY_HOST` | Production server IP/domain | `123.456.789.0` |
| `DEPLOY_USER` | SSH username | `ubuntu` |
| `SSH_PRIVATE_KEY` | SSH private key | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `SECRET_KEY` | Django secret key | `django-insecure-...` |
| `DATABASE_URL` | Database connection string | `postgresql://user:pass@host:5432/db` |

### Database Configuration

| Secret Name | Description | Default |
|-------------|-------------|---------|
| `DATABASE_HOST` | Database host | - |
| `DATABASE_NAME` | Database name | - |
| `DATABASE_USER` | Database username | - |
| `DATABASE_PASSWORD` | Database password | - |
| `DATABASE_PORT` | Database port | `5432` |

### Application Settings

| Secret Name | Description | Default |
|-------------|-------------|---------|
| `DEBUG` | Debug mode | `False` |
| `ALLOWED_HOSTS` | Allowed hostnames | - |
| `CORS_ALLOWED_ORIGINS` | CORS allowed origins | - |
| `CSRF_TRUSTED_ORIGINS` | CSRF trusted origins | - |

### Optional Secrets

| Secret Name | Description | Required |
|-------------|-------------|----------|
| `DEPLOY_PORT` | SSH port | No (22) |
| `REDIS_URL` | Redis connection string | No |
| `EMAIL_HOST` | SMTP server | No |
| `EMAIL_HOST_USER` | SMTP username | No |
| `EMAIL_HOST_PASSWORD` | SMTP password | No |
| `AWS_ACCESS_KEY_ID` | AWS access key | No |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | No |

## 🎚️ Deployment Types

### Update Deployment (Default)
- Updates existing installation
- Restarts services
- Minimal downtime

### Fresh Setup
- Complete server setup from scratch
- Installs all dependencies
- Configures services
- Use for new servers

### Full Rebuild
- Stops all services
- Cleans previous installation
- Rebuilds everything
- Use for major updates

## 📊 Monitoring

### Health Checks

The health check workflow monitors:
- Application responsiveness
- Database connectivity
- Service status
- System resources

### Alerts

Configure alerts by modifying the workflow files:
- Email notifications
- Slack webhooks
- PagerDuty integration
- Custom webhook endpoints

## 🔧 Troubleshooting

### Common Issues

#### 1. SSH Connection Failed
```bash
# Test SSH connection locally
ssh -p 22 ubuntu@your-server.com

# Check SSH key format
head -n 1 ~/.ssh/github_actions_key
# Should start with: -----BEGIN OPENSSH PRIVATE KEY-----
```

#### 2. Database Connection Failed
```bash
# Test database connection on server
./manage.sh check --database
```

#### 3. Service Start Failed
```bash
# Check service status
./manage.sh prod-status

# View service logs
./manage.sh prod-logs
```

#### 4. Health Check Failed
```bash
# Run manual health check
./manage.sh verify-deployment

# Check specific components
./manage.sh verify-deployment --application
./manage.sh verify-deployment --services
```

### Manual Deployment

If automated deployment fails, deploy manually:

```bash
# Connect to server
ssh user@your-server.com

# Navigate to project directory
cd /var/www/watchparty

# Update code
git pull origin master

# Restart services
sudo ./manage.sh prod-restart

# Verify deployment
./manage.sh verify-deployment
```

### Viewing Logs

Access deployment logs through:

1. **GitHub Actions logs**: Check the workflow run details
2. **Server logs**: 
   ```bash
   ./manage.sh prod-logs
   ./manage.sh logs
   ```
3. **System logs**:
   ```bash
   sudo journalctl -u watchparty-gunicorn
   sudo journalctl -u nginx
   ```

## 🚀 Advanced Configuration

### Custom Deployment Scripts

Modify existing scripts in the `scripts/` directory:
- `deployment.sh` - Main deployment logic
- `production.sh` - Production server management
- `server-setup.sh` - Server initialization
- `verify-deployment.sh` - Deployment verification

### Environment Variables

Override workflow behavior with repository variables:
- `BACKUP_RETENTION_DAYS` - How long to keep backups (default: 7)
- `ENABLE_HEALTH_CHECKS` - Enable/disable health monitoring (default: true)

### Workflow Customization

Modify workflow files to:
- Change trigger conditions
- Add custom checks
- Integrate with external services
- Customize notification methods

## 📞 Support

For issues with deployment:

1. Check the [troubleshooting section](#troubleshooting)
2. Review GitHub Actions logs
3. Check server logs with `./manage.sh prod-logs`
4. Run verification with `./manage.sh verify-deployment`

---

**Note**: Always test deployments on a staging environment before deploying to production.
