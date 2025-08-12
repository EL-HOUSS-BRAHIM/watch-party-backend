#!/usr/bin/env python3
"""
Fix missing serializers imports in views that use serializers.Serializer
"""

import os
import re
from pathlib import Path

def fix_serializers_import(file_path):
    """Add serializers import if missing when serializers.Serializer is used"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check if file uses serializers.Serializer
        if 'serializers.Serializer' not in content:
            return False, "No serializers.Serializer usage found"
        
        # Check if serializers is already imported
        if re.search(r'from rest_framework import.*serializers', content):
            return False, "serializers already imported"
        
        if 'from rest_framework import serializers' in content:
            return False, "serializers already imported"
        
        # Find the rest_framework import line
        rest_framework_import_pattern = r'(from rest_framework import [^\\n]+)'
        match = re.search(rest_framework_import_pattern, content)
        
        if match:
            # Add serializers to existing import
            existing_import = match.group(1)
            if 'serializers' not in existing_import:
                new_import = existing_import.rstrip() + ', serializers'
                content = content.replace(existing_import, new_import)
                
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                
                return True, f"Added serializers to existing import: {new_import}"
        else:
            # Add new import line after other rest_framework imports
            lines = content.split('\n')
            insert_idx = -1
            
            for i, line in enumerate(lines):
                if line.startswith('from rest_framework'):
                    insert_idx = i + 1
            
            if insert_idx > -1:
                lines.insert(insert_idx, 'from rest_framework import serializers')
                content = '\n'.join(lines)
                
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                
                return True, "Added new serializers import line"
        
        return False, "Could not find place to add import"
        
    except Exception as e:
        return False, f"Error processing file: {e}"

def main():
    """Fix serializers imports in all relevant files"""
    print("🔧 Fixing missing serializers imports...")
    
    # Files that might need fixing based on our previous script
    files_to_check = [
        'apps/billing/views.py',
        'apps/events/views.py', 
        'apps/integrations/views.py',
        'apps/messaging/views.py',
        'apps/mobile/views.py',
        'apps/notifications/views.py',
    ]
    
    fixed_count = 0
    
    for file_path in files_to_check:
        path = Path(file_path)
        if path.exists():
            success, message = fix_serializers_import(path)
            if success:
                print(f"✅ Fixed {file_path}: {message}")
                fixed_count += 1
            else:
                print(f"ℹ️ {file_path}: {message}")
        else:
            print(f"⚠️ File not found: {file_path}")
    
    print(f"\n🎉 Fixed {fixed_count} files")
    return fixed_count

if __name__ == "__main__":
    main()
