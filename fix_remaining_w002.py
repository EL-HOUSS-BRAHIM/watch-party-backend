#!/usr/bin/env python3
"""
Fix remaining W002 warnings for APIViews without serializer classes
"""

import os
import re
from pathlib import Path

def find_python_files():
    """Find all Python files in the apps directory"""
    files = []
    for root, dirs, filenames in os.walk('apps'):
        for filename in filenames:
            if filename.endswith('.py'):
                files.append(os.path.join(root, filename))
    return files

def analyze_views_for_w002(content):
    """Analyze view file for APIViews that might need serializer classes"""
    issues = []
    lines = content.split('\n')
    
    # Look for class definitions that inherit from APIView or similar
    for i, line in enumerate(lines):
        # Match class definitions
        class_match = re.search(r'class\s+(\w+)\s*\([^)]*(?:APIView|GenericAPIView|ViewSet|ListAPIView|CreateAPIView|RetrieveAPIView|UpdateAPIView|DestroyAPIView)[^)]*\):', line)
        if class_match:
            class_name = class_match.group(1)
            
            # Look ahead to see if this class already has serializer_class
            has_serializer = False
            has_schema_decorator = False
            
            # Check next 20 lines for existing serializer_class or @extend_schema
            for j in range(i+1, min(i+20, len(lines))):
                if 'serializer_class' in lines[j]:
                    has_serializer = True
                    break
                if '@extend_schema' in lines[j]:
                    has_schema_decorator = True
                    break
                # Stop if we hit another class or method definition
                if re.match(r'\s*class\s+|^\s*def\s+', lines[j]) and j > i+1:
                    break
            
            if not has_serializer and not has_schema_decorator:
                issues.append({
                    'class_name': class_name,
                    'line_num': i + 1,
                    'line': line.strip()
                })
    
    return issues

def add_schema_decorators(filepath, issues):
    """Add @extend_schema decorators to methods that need them"""
    if not issues:
        return False
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    modified = False
    
    # Check if we need to add imports
    has_extend_schema_import = 'from drf_spectacular.utils import extend_schema' in content
    has_openapi_import = 'from drf_spectacular.openapi import AutoSchema' in content
    
    if not has_extend_schema_import:
        # Find import section and add our import
        import_line = -1
        for i, line in enumerate(lines):
            if line.startswith('from django') or line.startswith('from rest_framework'):
                import_line = i
        
        if import_line >= 0:
            lines.insert(import_line + 1, 'from drf_spectacular.utils import extend_schema')
            modified = True
    
    # Add @extend_schema decorators to classes that need them
    for issue in issues:
        class_name = issue['class_name']
        
        # Find the class definition
        for i, line in enumerate(lines):
            if f'class {class_name}' in line and 'APIView' in line:
                # Look for methods that might need decorators
                j = i + 1
                while j < len(lines) and not (lines[j].strip().startswith('class ') and j > i + 1):
                    line_content = lines[j].strip()
                    
                    # Check for HTTP methods that need schema
                    if re.match(r'def\s+(get|post|put|patch|delete|head|options|trace)\s*\(', line_content):
                        method_name = re.match(r'def\s+(\w+)', line_content).group(1)
                        
                        # Check if this method already has @extend_schema
                        has_decorator = False
                        for k in range(max(0, j-5), j):
                            if '@extend_schema' in lines[k]:
                                has_decorator = True
                                break
                        
                        if not has_decorator:
                            # Add the decorator
                            indent = len(lines[j]) - len(lines[j].lstrip())
                            decorator = ' ' * indent + f'@extend_schema(summary="{class_name} {method_name.upper()}")'
                            lines.insert(j, decorator)
                            modified = True
                            j += 1  # Account for the inserted line
                    
                    j += 1
                break
    
    if modified:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines))
        return True
    
    return False

def main():
    """Main function to fix W002 warnings"""
    print("🔍 Analyzing views for W002 warnings...")
    
    files_processed = 0
    files_modified = 0
    total_issues = 0
    
    for filepath in find_python_files():
        if 'views.py' in filepath or 'viewsets.py' in filepath:
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                issues = analyze_views_for_w002(content)
                if issues:
                    total_issues += len(issues)
                    print(f"\n📁 {filepath}: Found {len(issues)} potential W002 issues")
                    for issue in issues:
                        print(f"  - Line {issue['line_num']}: {issue['class_name']}")
                    
                    if add_schema_decorators(filepath, issues):
                        files_modified += 1
                        print(f"  ✅ Added @extend_schema decorators")
                
                files_processed += 1
                
            except Exception as e:
                print(f"❌ Error processing {filepath}: {e}")
    
    print(f"\n📊 Summary:")
    print(f"Files processed: {files_processed}")
    print(f"Files modified: {files_modified}")
    print(f"Total issues found: {total_issues}")
    print(f"\n🔧 Run 'python manage.py check --deploy' to verify fixes")

if __name__ == '__main__':
    main()
