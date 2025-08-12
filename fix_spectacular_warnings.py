#!/usr/bin/env python3
"""
Automated fix script for drf-spectacular warnings
This script will automatically fix common patterns in the codebase
"""

import os
import re
import glob

def fix_serializer_method_fields():
    """Fix SerializerMethodField with missing type hints"""
    
    # Common type mappings
    type_mappings = {
        'get_is_': 'OpenApiTypes.BOOL',
        'get_total_': 'OpenApiTypes.INT', 
        'get_count_': 'OpenApiTypes.INT',
        'get_active_': 'OpenApiTypes.INT',
        'get_display_': 'OpenApiTypes.STR',
        'get_status_': 'OpenApiTypes.STR',
        'get_name_': 'OpenApiTypes.STR',
        'get_time_': 'OpenApiTypes.STR',
        'get_days_': 'OpenApiTypes.INT',
        'is_expired': 'OpenApiTypes.BOOL',
        'is_active': 'OpenApiTypes.BOOL',
        'is_visible': 'OpenApiTypes.BOOL',
    }
    
    serializer_files = glob.glob('apps/*/serializers.py')
    
    for file_path in serializer_files:
        try:
            with open(file_path, 'r') as f:
                content = f.read()
            
            # Check if already has imports
            has_spectacular_imports = 'from drf_spectacular.utils import extend_schema_field' in content
            
            if not has_spectacular_imports:
                # Add imports after existing imports
                imports_pattern = r'(from rest_framework import serializers[^\n]*\n)'
                replacement = r'\1from drf_spectacular.utils import extend_schema_field\nfrom drf_spectacular.types import OpenApiTypes\n'
                content = re.sub(imports_pattern, replacement, content)
            
            # Find method definitions that need decorators
            method_pattern = r'(\s+)(def (get_[a-zA-Z_]+)\(self, obj\):)'
            
            def add_decorator(match):
                indent = match.group(1)
                method_def = match.group(2)
                method_name = match.group(3)
                
                # Determine the appropriate type
                api_type = 'OpenApiTypes.STR'  # default
                for pattern, type_name in type_mappings.items():
                    if pattern in method_name:
                        api_type = type_name
                        break
                
                # Check if decorator already exists
                if '@extend_schema_field' in content[:match.start()]:
                    # Find the last occurrence to see if it's for this method
                    lines_before = content[:match.start()].split('\n')
                    if lines_before and '@extend_schema_field' in lines_before[-2]:
                        return match.group(0)  # Already has decorator
                
                decorator = f'{indent}@extend_schema_field({api_type})\n'
                return decorator + match.group(0)
            
            content = re.sub(method_pattern, add_decorator, content)
            
            with open(file_path, 'w') as f:
                f.write(content)
                
            print(f"Fixed: {file_path}")
            
        except Exception as e:
            print(f"Error processing {file_path}: {e}")

def fix_queryset_methods():
    """Fix queryset methods that don't handle swagger_fake_view"""
    
    view_files = glob.glob('apps/*/views.py')
    
    for file_path in view_files:
        try:
            with open(file_path, 'r') as f:
                content = f.read()
            
            # Find get_queryset methods that don't have swagger_fake_view check
            queryset_pattern = r'(\s+def get_queryset\(self\):\s*\n)((?:(?!\s+def ).)*?)(self\.request\.user)'
            
            def add_swagger_check(match):
                indent = match.group(1)
                method_body = match.group(2)
                user_access = match.group(3)
                
                # Check if already has swagger_fake_view check
                if 'swagger_fake_view' in method_body:
                    return match.group(0)
                
                # Add the check
                model_name = 'Model'  # Default, could be improved
                if 'User.objects' in method_body:
                    model_name = 'User'
                elif 'Invoice.objects' in method_body:
                    model_name = 'Invoice'
                elif 'PaymentMethod.objects' in method_body:
                    model_name = 'PaymentMethod'
                
                swagger_check = f'        # Handle schema generation when there\'s no user\n        if getattr(self, \'swagger_fake_view\', False):\n            return {model_name}.objects.none()\n        \n'
                
                return indent + swagger_check + method_body + user_access
            
            content = re.sub(queryset_pattern, add_swagger_check, content, flags=re.DOTALL)
            
            with open(file_path, 'w') as f:
                f.write(content)
                
            print(f"Fixed queryset: {file_path}")
            
        except Exception as e:
            print(f"Error processing {file_path}: {e}")

def add_serializer_classes():
    """Add serializer_class to views that need them"""
    
    view_files = glob.glob('apps/*/views.py') + glob.glob('apps/*/health_views.py')
    
    for file_path in view_files:
        try:
            with open(file_path, 'r') as f:
                content = f.read()
            
            # Check if needs spectacular imports
            if 'APIView' in content and 'extend_schema' not in content:
                # Add extend_schema import
                if 'from rest_framework' in content:
                    content = content.replace(
                        'from rest_framework import',
                        'from drf_spectacular.utils import extend_schema\nfrom rest_framework import'
                    )
            
            # Find class-based APIViews without serializer_class
            class_pattern = r'class (\w+)\(.*APIView\):\s*\n((?:(?!class ).)*?)def (get|post|put|delete)\('
            
            def add_serializer_class(match):
                class_name = match.group(1)
                class_body = match.group(2)
                method_name = match.group(3)
                
                if 'serializer_class' in class_body:
                    return match.group(0)  # Already has serializer_class
                
                # Add a generic serializer class
                serializer_line = f'    serializer_class = None  # TODO: Add appropriate serializer\n'
                
                return f'class {class_name}(APIView):\n{serializer_line}{class_body}def {method_name}('
            
            # This is complex to implement safely, so we'll skip for now
            
        except Exception as e:
            print(f"Error processing {file_path}: {e}")

if __name__ == '__main__':
    print("Starting automated fixes...")
    fix_serializer_method_fields()
    print("Completed!")
