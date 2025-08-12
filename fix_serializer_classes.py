#!/usr/bin/env python3
"""
Fix DRF Spectacular serializer_class warnings by adding serializer_class to APIViews
"""

import os
import re
import sys
from pathlib import Path


def find_apiview_classes(file_path):
    """Find all APIView classes in a file that need serializer_class"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Find class definitions that inherit from APIView
        apiview_pattern = r'class\s+(\w+)\([^)]*APIView[^)]*\):'
        matches = re.finditer(apiview_pattern, content)
        
        classes_found = []
        for match in matches:
            class_name = match.group(1)
            start_pos = match.start()
            
            # Get the line number
            lines_before = content[:start_pos].count('\n')
            line_number = lines_before + 1
            
            # Check if serializer_class is already defined in the class
            # Look for the class body (next 10-20 lines typically)
            class_start = match.end()
            class_content = content[class_start:class_start + 2000]  # Look ahead 2000 chars
            
            if 'serializer_class' not in class_content:
                classes_found.append({
                    'name': class_name,
                    'line': line_number,
                    'start_pos': start_pos,
                    'class_start': class_start
                })
        
        return classes_found
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
        return []


def suggest_serializer_class(class_name):
    """Suggest appropriate serializer_class based on class name"""
    # Common patterns and their serializers
    serializer_mappings = {
        'Register': 'UserRegistrationSerializer',
        'Login': 'UserLoginSerializer', 
        'Logout': 'serializers.Serializer',  # For simple views
        'PasswordChange': 'PasswordChangeSerializer',
        'ForgotPassword': 'PasswordResetRequestSerializer',
        'ResetPassword': 'PasswordResetSerializer',
        'VerifyEmail': 'EmailVerificationSerializer',
        'ResendVerification': 'EmailVerificationSerializer',
        'TwoFactorSetup': 'TwoFactorSetupRequestSerializer',
        'TwoFactorVerify': 'TwoFactorVerifyRequestSerializer',
        'TwoFactorDisable': 'TwoFactorDisableRequestSerializer',
        'GoogleAuth': 'GoogleAuthRequestSerializer',
        'GitHubAuth': 'GitHubAuthRequestSerializer',
        'SocialAuthRedirect': 'SocialAuthRedirectSerializer',
        'GoogleDriveAuth': 'GoogleDriveAuthRequestSerializer',
        'GoogleDriveDisconnect': 'GoogleDriveDisconnectSerializer',
        'GoogleDriveStatus': 'GoogleDriveStatusSerializer',
        'UserSessions': 'UserSessionsRequestSerializer',
    }
    
    # Try to match common patterns
    for pattern, serializer in serializer_mappings.items():
        if pattern in class_name:
            return serializer
    
    # Default fallback
    return 'serializers.Serializer'


def add_serializer_class_to_view(file_path, class_info, serializer_class):
    """Add serializer_class to a specific APIView class"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        # Find the class definition line
        class_line_idx = class_info['line'] - 1  # Convert to 0-based index
        
        # Find where to insert the serializer_class
        # Look for the first non-empty line after the class definition that contains attribute definitions
        insert_line_idx = class_line_idx + 1
        
        # Skip the docstring if present
        while insert_line_idx < len(lines):
            line = lines[insert_line_idx].strip()
            if line and not line.startswith('"""') and not line.startswith("'''"):
                if line.startswith('permission_classes') or line.startswith('authentication_classes') or line.startswith('rate_limit'):
                    # Insert before these common attributes
                    break
                elif line.startswith('def ') or line.startswith('@'):
                    # Insert before methods/decorators
                    break
                elif '=' in line and not line.startswith('#'):
                    # Insert after this attribute line
                    insert_line_idx += 1
                    break
            insert_line_idx += 1
        
        # Get the indentation from the line above or use 4 spaces
        if insert_line_idx > 0 and insert_line_idx < len(lines):
            prev_line = lines[insert_line_idx]
            indentation = len(prev_line) - len(prev_line.lstrip())
            if indentation == 0:
                indentation = 4  # Default indentation
        else:
            indentation = 4
        
        # Create the serializer_class line
        serializer_line = ' ' * indentation + f'serializer_class = {serializer_class}\n'
        
        # Insert the line
        lines.insert(insert_line_idx, serializer_line)
        
        # Write back to file
        with open(file_path, 'w', encoding='utf-8') as f:
            f.writelines(lines)
        
        return True
    except Exception as e:
        print(f"Error modifying {file_path}: {e}")
        return False


def process_file(file_path):
    """Process a single Python file"""
    print(f"\n📋 Processing: {file_path}")
    
    classes = find_apiview_classes(file_path)
    if not classes:
        print("  ✅ No APIView classes missing serializer_class found")
        return True
    
    print(f"  📝 Found {len(classes)} APIView classes missing serializer_class:")
    
    modified = False
    for class_info in classes:
        class_name = class_info['name']
        suggested_serializer = suggest_serializer_class(class_name)
        
        print(f"    - {class_name} -> {suggested_serializer}")
        
        if add_serializer_class_to_view(file_path, class_info, suggested_serializer):
            modified = True
        else:
            print(f"      ❌ Failed to add serializer_class to {class_name}")
            return False
    
    if modified:
        print(f"  ✅ Successfully modified {file_path}")
    
    return True


def main():
    """Main function to process all relevant files"""
    print("🔧 Fixing DRF Spectacular serializer_class warnings...")
    
    # Define the apps to process
    apps_to_process = [
        'apps/authentication/views.py',
        'apps/analytics/views_advanced.py', 
        'apps/billing/views.py',
        'apps/chat/views.py',
        'apps/events/views.py',
        'apps/integrations/views.py',
        'apps/interactive/views.py',
        'apps/messaging/views.py',
        'apps/mobile/views.py',
        'apps/moderation/views.py',
        'apps/notifications/views.py',
    ]
    
    # Process each file
    success_count = 0
    total_count = len(apps_to_process)
    
    for app_file in apps_to_process:
        file_path = Path(app_file)
        if file_path.exists():
            if process_file(file_path):
                success_count += 1
            else:
                print(f"❌ Failed to process {app_file}")
        else:
            print(f"⚠️ File not found: {app_file}")
    
    print(f"\n🎉 Processing complete: {success_count}/{total_count} files processed successfully")
    
    if success_count == total_count:
        print("✅ All files processed successfully!")
        return 0
    else:
        print("⚠️ Some files had issues - review the output above")
        return 1


if __name__ == "__main__":
    sys.exit(main())
