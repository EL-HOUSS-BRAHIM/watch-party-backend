# Watch Party Backend

A comprehensive Django REST API backend for a collaborative video watching platform.

## 🔧 Recent Deployment Fixes (August 2025)

✅ **Deployment issues resolved!** The following critical fixes have been implemented:

- **Virtual Environment**: Fixed corrupted venv recreation during deployment
- **Service Configuration**: Fixed systemd service files with proper single-line commands
- **Port Management**: 
  - Gunicorn (Django app): Port 8001
  - Daphne (WebSockets): Port 8002
  - Nginx routing updated accordingly
- **Cloudflare Integration**: Optimized nginx configuration for Cloudflare proxy
  - `nginx.conf` - Default Cloudflare-compatible configuration
  - `nginx-ssl.conf` - Direct SSL version for non-Cloudflare setups
- **Log Permissions**: Fixed Django log file permission issues
- **Process Cleanup**: Added automatic cleanup of conflicting processes
- **Automatic Recovery**: Enhanced error handling and service recovery

**For deployments**: Simply push to master branch - all fixes are now automated! 🎉

### 📋 Configuration Files
- **[DEPLOYMENT_FIXES_COMPLETE.md](DEPLOYMENT_FIXES_COMPLETE.md)** - Complete deployment fix summary
- **[NGINX_CONFIG_GUIDE.md](NGINX_CONFIG_GUIDE.md)** - Nginx configuration options guide

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/EL-HOUSS-BRAHIM/watch-party-backend.git
cd watch-party-backend

# Set up the environment
./setup.sh

# Run the development server
./run_dev_server.sh
```

## 📚 Documentation

Comprehensive documentation is available in the [`docs/`](docs/) directory:

- **[📖 Full Documentation](docs/README.md)** - Complete documentation overview
- **[📋 Documentation Index](docs/INDEX.md)** - Quick reference and navigation
- **[🔗 API Reference](docs/api/backend-api.md)** - Complete API endpoint listing
- **[🚀 Deployment Guide](docs/deployment/DEPLOYMENT.md)** - Server setup and deployment
- **[🛠️ Development Guide](docs/development/ERD.md)** - Database schema and development resources

## 🏗️ Project Structure

```
watch-party-backend/
├── apps/                           # Django applications
├── core/                           # Core utilities and base classes
├── docs/                           # 📚 All documentation
│   ├── api/                       # API documentation
│   ├── deployment/                # Deployment guides
│   ├── development/               # Development resources
│   └── maintenance/               # Maintenance guides
├── middleware/                     # Custom Django middleware
├── services/                       # Business logic services
├── templates/                      # Email and other templates
├── utils/                          # Utility functions
├── watchparty/                     # Main Django project settings
├── scripts/                        # 🚀 Deployment and utility scripts
│   └── production.sh              # Main production deployment script
├── nginx.conf                      # 🌐 Nginx config (Cloudflare-compatible)
├── nginx-ssl.conf                  # 🔒 Nginx config (SSL version)
├── DEPLOYMENT_FIXES_COMPLETE.md    # 📋 Complete deployment fixes summary
├── NGINX_CONFIG_GUIDE.md           # 📖 Nginx configuration guide
├── FINAL_DEPLOYMENT_SUMMARY.md     # 🎯 Overall project status
├── manage.py                       # Django management script
└── requirements.txt                # Python dependencies
```

## ⚡ Key Features

- **🎥 Video Management** - Upload, stream, and manage video content
- **🎉 Watch Parties** - Real-time synchronized video watching
- **💬 Live Chat** - Real-time messaging during watch parties
- **👥 User Management** - Authentication, profiles, and friend systems
- **📊 Analytics** - Comprehensive usage and performance tracking
- **📱 Mobile Support** - Mobile-optimized APIs and push notifications
- **🔔 Notifications** - Real-time notifications system
- **🎮 Interactive Features** - Polls, reactions, and voice chat
- **💳 Billing** - Subscription and payment management
- **🛡️ Security** - Comprehensive security measures and monitoring

## 🛠️ Tech Stack

- **Backend**: Django 4.2+ with Django REST Framework
- **Database**: PostgreSQL with Redis for caching
- **Real-time**: WebSocket support with Django Channels
- **Authentication**: JWT-based authentication
- **File Storage**: Support for local and cloud storage
- **Task Queue**: Celery for background tasks
- **API Documentation**: Swagger/OpenAPI integration

## 📋 Prerequisites

- Python 3.8+
- PostgreSQL 12+
- Redis 6+
- Node.js 16+ (for some build tools)

## 🚀 Getting Started

### 1. Environment Setup

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Database Configuration

```bash
# Create PostgreSQL database
createdb watchparty

# Run migrations
python manage.py migrate
```

### 3. Create Superuser

```bash
python manage.py createsuperuser
```

### 4. Run Development Server

```bash
python manage.py runserver
```

Visit `http://localhost:8000/api/` for the API and `http://localhost:8000/admin/` for the admin interface.

## 🧪 Testing

```bash
# Run all tests
python manage.py test

# Run specific app tests
python manage.py test apps.videos

# Run with coverage
coverage run --source='.' manage.py test
coverage report
```

## 🧹 Maintenance

Regular maintenance tasks:

```bash
# Run cleanup script
./cleanup.sh

# Check project health
python check_todo_status.py

# Update dependencies
pip install -r requirements.txt --upgrade
```

## 📊 API Documentation

- **Interactive API Docs**: `http://localhost:8000/swagger/`
- **ReDoc Interface**: `http://localhost:8000/redoc/`
- **Complete API Reference**: [docs/api/backend-api.md](docs/api/backend-api.md)

## 🚀 Deployment

See the [Deployment Guide](docs/deployment/DEPLOYMENT.md) for detailed deployment instructions including:

- Server setup and configuration
- Environment variables
- Database setup
- SSL/TLS configuration
- Performance optimization
- Monitoring and logging

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new features
5. Update documentation
6. Submit a pull request

See the [development documentation](docs/development/) for coding standards and guidelines.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

- **Documentation**: [docs/](docs/)
- **Issues**: [GitHub Issues](https://github.com/EL-HOUSS-BRAHIM/watch-party-backend/issues)
- **API Questions**: See [API Documentation](docs/api/)
- **Deployment Help**: See [Deployment Guide](docs/deployment/DEPLOYMENT.md)

## 🎯 Project Status

✅ **Active Development** - This project is actively maintained and developed.

- All major features implemented
- Comprehensive test coverage
- Production-ready deployment
- Extensive documentation
- Regular updates and maintenance

---

**Last Updated**: August 11, 2025  
**Version**: Latest  
**Documentation**: [docs/README.md](docs/README.md)
