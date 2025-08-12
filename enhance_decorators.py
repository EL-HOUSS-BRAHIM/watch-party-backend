#!/usr/bin/env python3
"""
Enhanced fix for W002 warnings with proper response schemas
"""

import os
import re
from pathlib import Path

# Common response schemas for different types of views
RESPONSE_SCHEMAS = {
    'health': '''@extend_schema(
        summary="Health check endpoint",
        responses={
            200: OpenApiResponse(
                description="Health status",
                examples=[OpenApiExample(
                    name="healthy_response",
                    value={"status": "healthy", "timestamp": "2024-01-01T00:00:00Z"}
                )]
            ),
            503: OpenApiResponse(description="Service unavailable")
        }
    )''',
    'dashboard': '''@extend_schema(
        summary="Dashboard data endpoint",
        responses={
            200: OpenApiResponse(description="Dashboard data")
        }
    )''',
    'analytics': '''@extend_schema(
        summary="Analytics data endpoint", 
        responses={
            200: OpenApiResponse(description="Analytics data")
        }
    )''',
    'upload': '''@extend_schema(
        summary="File upload endpoint",
        request={"multipart/form-data": {"type": "object", "properties": {"file": {"type": "string", "format": "binary"}}}},
        responses={
            200: OpenApiResponse(description="Upload successful"),
            400: OpenApiResponse(description="Upload failed")
        }
    )''',
    'generic': '''@extend_schema(
        summary="API endpoint",
        responses={200: OpenApiResponse(description="Success")}
    )'''
}

def get_enhanced_decorator(class_name, method_name):
    """Get appropriate decorator based on class/method names"""
    class_lower = class_name.lower()
    method_lower = method_name.lower()
    
    # Determine the type of endpoint
    if 'health' in class_lower or 'status' in class_lower:
        return RESPONSE_SCHEMAS['health']
    elif 'dashboard' in class_lower:
        return RESPONSE_SCHEMAS['dashboard']
    elif 'analytics' in class_lower or 'stats' in class_lower:
        return RESPONSE_SCHEMAS['analytics']
    elif 'upload' in class_lower or method_lower == 'post':
        return RESPONSE_SCHEMAS['upload']
    else:
        return RESPONSE_SCHEMAS['generic']

def fix_file_with_enhanced_decorators(filepath):
    """Fix a specific file with enhanced decorators"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    modified = False
    
    # Ensure we have the necessary imports
    imports_needed = [
        'from drf_spectacular.utils import extend_schema',
        'from drf_spectacular.openapi import OpenApiResponse, OpenApiExample'
    ]
    
    # Find import section
    import_line = -1
    for i, line in enumerate(lines):
        if line.startswith('from django') or line.startswith('from rest_framework'):
            import_line = i
            break
    
    # Add missing imports
    for import_stmt in imports_needed:
        if import_stmt not in content:
            if import_line >= 0:
                lines.insert(import_line + 1, import_stmt)
                import_line += 1
                modified = True
    
    # Find and fix simple @extend_schema decorators
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        
        # Look for our simple decorators that need enhancement
        if line.startswith('@extend_schema(summary="') and 'View' in line and '")"' in line:
            # Extract class and method info
            summary = re.search(r'summary="(\w+View)\s+(\w+)"', line)
            if summary:
                class_name = summary.group(1)
                method_name = summary.group(2)
                
                # Get enhanced decorator
                enhanced_decorator = get_enhanced_decorator(class_name, method_name)
                
                # Replace the simple decorator with enhanced one
                indent = len(lines[i]) - len(lines[i].lstrip())
                enhanced_lines = enhanced_decorator.split('\n')
                enhanced_lines = [' ' * indent + line for line in enhanced_lines]
                
                # Replace the line
                lines[i:i+1] = enhanced_lines
                modified = True
                i += len(enhanced_lines) - 1
        
        i += 1
    
    if modified:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines))
        return True
    
    return False

def main():
    """Main function to enhance decorators"""
    print("🔧 Enhancing @extend_schema decorators with response schemas...")
    
    files_processed = 0
    files_modified = 0
    
    # Focus on files that were just modified
    target_files = [
        'apps/admin_panel/health_views.py',
        'apps/admin_panel/monitoring_views.py', 
        'apps/admin_panel/views.py',
        'apps/analytics/views.py',
        'apps/analytics/advanced_views.py'
    ]
    
    for filepath in target_files:
        if os.path.exists(filepath):
            try:
                print(f"📁 Processing {filepath}...")
                if fix_file_with_enhanced_decorators(filepath):
                    files_modified += 1
                    print(f"  ✅ Enhanced decorators")
                else:
                    print(f"  ℹ️  No changes needed")
                
                files_processed += 1
                
            except Exception as e:
                print(f"❌ Error processing {filepath}: {e}")
    
    print(f"\n📊 Summary:")
    print(f"Files processed: {files_processed}")
    print(f"Files modified: {files_modified}")

if __name__ == '__main__':
    main()
