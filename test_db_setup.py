#!/usr/bin/env python
"""
Quick test to verify database setup is working in CI environment.
"""
import os
import django
from django.conf import settings

# Set the settings module
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'watchparty.settings.testing')

# Setup Django
django.setup()

# Test imports and database connection
from django.db import connection
from django.core.management import execute_from_command_line
from django.test.utils import get_runner

def test_database_connection():
    """Test that we can connect to the database."""
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            result = cursor.fetchone()
            assert result == (1,), f"Expected (1,), got {result}"
        print("✓ Database connection test passed")
        return True
    except Exception as e:
        print(f"✗ Database connection test failed: {e}")
        return False

def test_django_setup():
    """Test that Django is properly configured."""
    try:
        # Check that we're using the testing settings
        assert 'testing' in settings.SETTINGS_MODULE
        print("✓ Django testing settings loaded")
        
        # Check database configuration
        db_config = settings.DATABASES['default']
        print(f"✓ Database engine: {db_config['ENGINE']}")
        
        # Check cache configuration
        cache_config = settings.CACHES['default']
        print(f"✓ Cache backend: {cache_config['BACKEND']}")
        
        return True
    except Exception as e:
        print(f"✗ Django setup test failed: {e}")
        return False

def test_apps_loading():
    """Test that all Django apps can be loaded."""
    try:
        from django.apps import apps
        app_configs = apps.get_app_configs()
        app_count = len(app_configs)
        print(f"✓ Successfully loaded {app_count} Django apps")
        return True
    except Exception as e:
        print(f"✗ Apps loading test failed: {e}")
        return False

def main():
    """Run all tests."""
    print("Running database setup tests...")
    print("=" * 50)
    
    tests = [
        test_django_setup,
        test_database_connection,
        test_apps_loading,
    ]
    
    passed = 0
    failed = 0
    
    for test in tests:
        try:
            if test():
                passed += 1
            else:
                failed += 1
        except Exception as e:
            print(f"✗ Test {test.__name__} crashed: {e}")
            failed += 1
    
    print("=" * 50)
    print(f"Tests passed: {passed}")
    print(f"Tests failed: {failed}")
    
    if failed == 0:
        print("🎉 All tests passed!")
        return True
    else:
        print("❌ Some tests failed!")
        return False

if __name__ == '__main__':
    success = main()
    exit(0 if success else 1)
