#!/usr/bin/env python
"""
Test script to verify database connection with the fixed settings
"""
import os
import sys
import django

# Set environment variables for testing
os.environ.setdefault('DATABASE_URL', 'postgresql://postgres:postgres@localhost:5432/test_watchparty')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'watchparty.settings.testing')
os.environ.setdefault('SECRET_KEY', 'test-secret-key')
os.environ.setdefault('DEBUG', 'True')
os.environ.setdefault('REDIS_URL', 'redis://localhost:6379/0')
os.environ.setdefault('USE_MIGRATIONS', 'true')

def test_database_connection():
    """Test database connection with the fixed settings"""
    try:
        django.setup()
        from django.db import connection
        from django.conf import settings
        
        print("✓ Django setup successful")
        print(f"✓ Database engine: {settings.DATABASES['default']['ENGINE']}")
        print(f"✓ Database options: {settings.DATABASES['default'].get('OPTIONS', {})}")
        
        # Test connection
        with connection.cursor() as cursor:
            cursor.execute("SELECT version();")
            version = cursor.fetchone()[0]
            print(f"✓ Database connection successful: {version}")
            
        # Test transaction isolation level
        with connection.cursor() as cursor:
            cursor.execute("SHOW default_transaction_isolation;")
            isolation_level = cursor.fetchone()[0]
            print(f"✓ Transaction isolation level: {isolation_level}")
            
        print("\n🎉 All database connection tests passed!")
        return True
        
    except Exception as e:
        print(f"❌ Database connection test failed: {e}")
        return False

if __name__ == "__main__":
    success = test_database_connection()
    sys.exit(0 if success else 1)
