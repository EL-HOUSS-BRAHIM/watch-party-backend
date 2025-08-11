#!/usr/bin/env python
"""
Test validation script to ensure the test configuration is working properly.
"""

import os
import sys
import django

# Add the project directory to the Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Set up Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'watchparty.settings.testing')
django.setup()

from django.test.utils import get_runner
from django.conf import settings
from django.core.management import execute_from_command_line


def validate_test_setup():
    """Validate that the test setup is working correctly."""
    print("🔍 Validating test setup...")
    
    # Check Django configuration
    print(f"✓ Django settings module: {settings.SETTINGS_MODULE}")
    print(f"✓ Database engine: {settings.DATABASES['default']['ENGINE']}")
    print(f"✓ Database name: {settings.DATABASES['default']['NAME']}")
    
    # Check if we're using PostgreSQL or SQLite
    if 'postgresql' in settings.DATABASES['default']['ENGINE']:
        print("✓ Using PostgreSQL for testing")
        test_db_name = settings.DATABASES['default'].get('TEST', {}).get('NAME')
        if test_db_name:
            print(f"✓ Custom test database name: {test_db_name}")
        else:
            print("✓ Using Django's automatic test database naming")
    else:
        print("✓ Using SQLite for testing")
    
    # Test Django's system check
    print("\n🔧 Running Django system check...")
    try:
        execute_from_command_line(['manage.py', 'check', '--settings=watchparty.settings.testing'])
        print("✓ Django system check passed")
    except Exception as e:
        print(f"❌ Django system check failed: {e}")
        return False
    
    print("\n🎉 Test setup validation completed successfully!")
    print("\nTo run tests:")
    print("  Local: python manage.py test --settings=watchparty.settings.testing")
    print("  CI:    coverage run --source='.' manage.py test --settings=watchparty.settings.testing")
    
    return True


if __name__ == '__main__':
    success = validate_test_setup()
    sys.exit(0 if success else 1)
