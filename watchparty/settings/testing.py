"""
Testing settings for Watch Party Backend
"""

from .base import *
import os

# Override any environment variables for testing
DEBUG = True

# Database configuration for testing
# Check if we have a DATABASE_URL from environment (GitHub Actions)
DATABASE_URL = os.environ.get('DATABASE_URL')

if DATABASE_URL:
    # Use the provided database URL (for GitHub Actions)
    import dj_database_url
    DATABASES = {
        'default': dj_database_url.parse(DATABASE_URL, conn_max_age=0)
    }
    
    # Override connection settings for PostgreSQL in CI
    DATABASES['default'].update({
        'CONN_MAX_AGE': 0,  # Don't persist connections in tests
        'CONN_HEALTH_CHECKS': False,
        'DISABLE_SERVER_SIDE_CURSORS': False,
        'TEST': {
            'NAME': 'test_watchparty',
        },
    })
    
    # If it's PostgreSQL, add specific options with proper isolation level
    if 'postgresql' in DATABASE_URL or 'postgres' in DATABASE_URL:
        DATABASES['default']['OPTIONS'] = {
            'options': '-c default_transaction_isolation="read committed"'
        }
else:
    # Use in-memory SQLite for local testing
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': ':memory:',
            'OPTIONS': {
                'timeout': 20,
            },
            'TEST': {
                'NAME': ':memory:',
            },
        }
    }

# Static and Media files for testing
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'test_static'
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'test_media'

# Force migrations to be enabled in CI environment
USE_MIGRATIONS = os.environ.get('USE_MIGRATIONS', 'false').lower() == 'true'

# Only disable migrations for local testing
if not USE_MIGRATIONS and not DATABASE_URL:
    class DisableMigrations:
        def __contains__(self, item):
            return True
        
        def __getitem__(self, item):
            return None

    MIGRATION_MODULES = DisableMigrations()

# Use simple password hasher for tests
PASSWORD_HASHERS = [
    'django.contrib.auth.hashers.MD5PasswordHasher',
]

# Disable logging during tests
LOGGING_CONFIG = None
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'null': {
            'class': 'logging.NullHandler',
        },
    },
    'root': {
        'handlers': ['null'],
    },
}

# Silence Django system check warnings for testing
SILENCED_SYSTEM_CHECKS = [
    'models.W042',  # Auto-created primary key warnings
]

# Use console email backend for tests
EMAIL_BACKEND = 'django.core.mail.backends.locmem.EmailBackend'

# Cache configuration for testing
REDIS_URL = os.environ.get('REDIS_URL')
if REDIS_URL:
    # Use Redis for CI
    CACHES = {
        'default': {
            'BACKEND': 'django_redis.cache.RedisCache',
            'LOCATION': REDIS_URL,
            'OPTIONS': {
                'CLIENT_CLASS': 'django_redis.client.DefaultClient',
            }
        }
    }
else:
    # Use dummy cache for local tests
    CACHES = {
        'default': {
            'BACKEND': 'django.core.cache.backends.dummy.DummyCache',
        }
    }

# Disable Celery for tests
CELERY_TASK_ALWAYS_EAGER = True
CELERY_TASK_EAGER_PROPAGATES = True

# Test-specific settings
SECRET_KEY = os.environ.get('SECRET_KEY', 'test-secret-key-for-testing')
CORS_ALLOW_ALL_ORIGINS = True

# Disable debug toolbar for tests
if 'debug_toolbar' in INSTALLED_APPS:
    INSTALLED_APPS.remove('debug_toolbar')

# Remove debug toolbar middleware if present
DEBUG_TOOLBAR_MIDDLEWARE = 'debug_toolbar.middleware.DebugToolbarMiddleware'
if DEBUG_TOOLBAR_MIDDLEWARE in MIDDLEWARE:
    MIDDLEWARE.remove(DEBUG_TOOLBAR_MIDDLEWARE)

# Test runner configuration
TEST_RUNNER = 'django.test.runner.DiscoverRunner'

# Security settings for testing
CSRF_COOKIE_SECURE = False
SESSION_COOKIE_SECURE = False
SECURE_SSL_REDIRECT = False
SECURE_PROXY_SSL_HEADER = None

# Disable some middleware for testing
TESTING_MIDDLEWARE_TO_REMOVE = [
    'middleware.security_middleware.EnhancedSecurityMiddleware',
    'middleware.security_middleware.AdvancedRateLimitMiddleware',
    'middleware.performance_middleware.RateLimitMiddleware',
]

for middleware in TESTING_MIDDLEWARE_TO_REMOVE:
    if middleware in MIDDLEWARE:
        MIDDLEWARE.remove(middleware)

# Channel layers for testing
CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels.layers.InMemoryChannelLayer',
    }
}
