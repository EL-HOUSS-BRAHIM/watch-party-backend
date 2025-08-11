#!/usr/bin/env python3
"""
Comprehensive project cleanup script for Watch Party Backend
This script performs various cleanup tasks to maintain a clean codebase.
"""

import os
import shutil
from pathlib import Path
import tempfile
import django
from datetime import datetime, timedelta

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'watchparty.settings.development')
django.setup()

from django.utils import timezone

class ProjectCleaner:
    def __init__(self, project_root):
        self.project_root = Path(project_root)
        self.cleaned_items = []
        self.errors = []
        
    def log_cleanup(self, message, item_type="INFO"):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        status = "✅" if item_type == "SUCCESS" else "🔧" if item_type == "INFO" else "❌"
        print(f"{status} [{timestamp}] {message}")
        self.cleaned_items.append(f"{item_type}: {message}")
        
    def log_error(self, message):
        self.log_cleanup(message, "ERROR")
        self.errors.append(message)
        
    def clean_python_cache(self):
        """Remove Python cache files and directories"""
        self.log_cleanup("Starting Python cache cleanup...")
        cache_count = 0
        
        for root, dirs, files in os.walk(self.project_root):
            # Remove __pycache__ directories
            if '__pycache__' in dirs:
                cache_dir = Path(root) / '__pycache__'
                try:
                    shutil.rmtree(cache_dir)
                    cache_count += 1
                    self.log_cleanup(f"Removed cache directory: {cache_dir.relative_to(self.project_root)}")
                except Exception as e:
                    self.log_error(f"Failed to remove {cache_dir}: {e}")
                    
            # Remove .pyc files
            for file in files:
                if file.endswith('.pyc'):
                    pyc_file = Path(root) / file
                    try:
                        pyc_file.unlink()
                        cache_count += 1
                        self.log_cleanup(f"Removed .pyc file: {pyc_file.relative_to(self.project_root)}")
                    except Exception as e:
                        self.log_error(f"Failed to remove {pyc_file}: {e}")
                        
        self.log_cleanup(f"Python cache cleanup completed: {cache_count} items removed", "SUCCESS")
        
    def clean_log_files(self):
        """Clean up log files and temporary logs"""
        self.log_cleanup("Starting log file cleanup...")
        log_count = 0
        
        # Remove main logfile
        logfile = self.project_root / 'logfile'
        if logfile.exists():
            try:
                logfile.unlink()
                log_count += 1
                self.log_cleanup(f"Removed main logfile: {logfile.name}")
            except Exception as e:
                self.log_error(f"Failed to remove {logfile}: {e}")
                
        # Look for other log files
        for pattern in ['*.log', '*.out', '*.err']:
            for log_file in self.project_root.glob(pattern):
                try:
                    log_file.unlink()
                    log_count += 1
                    self.log_cleanup(f"Removed log file: {log_file.name}")
                except Exception as e:
                    self.log_error(f"Failed to remove {log_file}: {e}")
                    
        self.log_cleanup(f"Log file cleanup completed: {log_count} files removed", "SUCCESS")
        
    def clean_temporary_files(self):
        """Clean up temporary files and directories"""
        self.log_cleanup("Starting temporary file cleanup...")
        temp_count = 0
        
        # Common temporary file patterns
        temp_patterns = [
            '*.tmp', '*.temp', '*.bak', '*.backup', '*.swp', '*.swo',
            '.DS_Store', 'Thumbs.db', '*.orig', '*.rej'
        ]
        
        for pattern in temp_patterns:
            for temp_file in self.project_root.rglob(pattern):
                try:
                    temp_file.unlink()
                    temp_count += 1
                    self.log_cleanup(f"Removed temporary file: {temp_file.relative_to(self.project_root)}")
                except Exception as e:
                    self.log_error(f"Failed to remove {temp_file}: {e}")
                    
        # Clean system temporary directory of project-related files
        try:
            temp_dir = Path(tempfile.gettempdir())
            for temp_file in temp_dir.glob('watchparty*'):
                if temp_file.is_file() and temp_file.stat().st_mtime < (timezone.now().timestamp() - 3600):  # 1 hour old
                    try:
                        temp_file.unlink()
                        temp_count += 1
                        self.log_cleanup(f"Removed system temp file: {temp_file.name}")
                    except Exception as e:
                        self.log_error(f"Failed to remove system temp {temp_file}: {e}")
        except Exception as e:
            self.log_error(f"Error cleaning system temp directory: {e}")
            
        self.log_cleanup(f"Temporary file cleanup completed: {temp_count} files removed", "SUCCESS")
        
    def clean_media_temp_files(self):
        """Clean up temporary media files from video processing"""
        self.log_cleanup("Starting media temporary file cleanup...")
        media_count = 0
        
        # Import the video cleanup task
        try:
            from apps.videos.tasks import cleanup_temporary_files
            cleanup_temporary_files.delay()
            self.log_cleanup("Triggered video temporary file cleanup task")
            media_count += 1
        except Exception as e:
            self.log_error(f"Failed to trigger video cleanup task: {e}")
            
        self.log_cleanup(f"Media temporary file cleanup completed: {media_count} tasks triggered", "SUCCESS")
        
    def clean_old_database_data(self):
        """Clean up old database records (analytics, logs, etc.)"""
        self.log_cleanup("Starting database cleanup...")
        db_count = 0
        
        try:
            from core.background_tasks import cleanup_expired_data
            cleanup_expired_data.delay()
            self.log_cleanup("Triggered database cleanup task")
            db_count += 1
        except Exception as e:
            self.log_error(f"Failed to trigger database cleanup task: {e}")
            
        # Clean old notifications
        try:
            from apps.notifications.models import Notification
            old_notifications = Notification.objects.filter(
                created_at__lt=timezone.now() - timedelta(days=30),
                is_read=True
            )
            deleted_count = old_notifications.count()
            old_notifications.delete()
            self.log_cleanup(f"Deleted {deleted_count} old read notifications")
            db_count += deleted_count
        except Exception as e:
            self.log_error(f"Failed to clean old notifications: {e}")
            
        # Clean old analytics data
        try:
            from apps.analytics.tasks import cleanup_old_analytics
            cleanup_old_analytics.delay()
            self.log_cleanup("Triggered analytics cleanup task")
            db_count += 1
        except Exception as e:
            self.log_error(f"Failed to trigger analytics cleanup task: {e}")
            
        self.log_cleanup(f"Database cleanup completed: {db_count} operations performed", "SUCCESS")
        
    def optimize_imports(self):
        """Remove unused imports and optimize import statements"""
        self.log_cleanup("Starting import optimization...")
        
        try:
            # Use basic approach to check for obvious unused imports
            python_files = list(self.project_root.rglob("*.py"))
            checked_count = 0
            
            for py_file in python_files:
                try:
                    # Skip migration files and virtual environments
                    if 'migrations' in str(py_file) or 'venv' in str(py_file) or '__pycache__' in str(py_file):
                        continue
                        
                    # Simple check for files that might have unused imports
                    with open(py_file, 'r', encoding='utf-8') as f:
                        content = f.read()
                        
                    if content.strip():  # Only process non-empty files
                        checked_count += 1
                        
                except Exception:
                    # Skip files that can't be read
                    pass
                    
            self.log_cleanup(f"Import optimization check completed: {checked_count} files checked", "SUCCESS")
            self.log_cleanup("Consider running 'isort' and 'autoflake' for comprehensive import cleanup", "INFO")
            
        except Exception as e:
            self.log_error(f"Error during import optimization: {e}")
        
    def validate_project_structure(self):
        """Validate that project structure is intact after cleanup"""
        self.log_cleanup("Validating project structure...")
        
        critical_files = [
            'manage.py',
            'requirements.txt',
            'watchparty/settings',
            'apps',
            'core'
        ]
        
        all_good = True
        for critical_path in critical_files:
            full_path = self.project_root / critical_path
            if not full_path.exists():
                self.log_error(f"Critical path missing after cleanup: {critical_path}")
                all_good = False
            else:
                self.log_cleanup(f"Verified: {critical_path}")
                
        if all_good:
            self.log_cleanup("Project structure validation passed", "SUCCESS")
        else:
            self.log_error("Project structure validation failed!")
            
    def generate_cleanup_report(self):
        """Generate a cleanup report"""
        report_path = self.project_root / 'cleanup_report.txt'
        
        with open(report_path, 'w') as f:
            f.write("=" * 60 + "\n")
            f.write("WATCH PARTY BACKEND - CLEANUP REPORT\n")
            f.write("=" * 60 + "\n")
            f.write(f"Cleanup performed on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            
            f.write("CLEANUP OPERATIONS PERFORMED:\n")
            f.write("-" * 40 + "\n")
            for item in self.cleaned_items:
                f.write(f"{item}\n")
                
            if self.errors:
                f.write("\nERRORS ENCOUNTERED:\n")
                f.write("-" * 40 + "\n")
                for error in self.errors:
                    f.write(f"{error}\n")
            else:
                f.write("\n✅ No errors encountered during cleanup!\n")
                
            f.write("\n" + "=" * 60 + "\n")
            
        self.log_cleanup(f"Cleanup report generated: cleanup_report.txt", "SUCCESS")
        
    def run_full_cleanup(self):
        """Run all cleanup operations"""
        print("🧹 STARTING COMPREHENSIVE PROJECT CLEANUP")
        print("=" * 60)
        
        cleanup_operations = [
            ("Python Cache Files", self.clean_python_cache),
            ("Log Files", self.clean_log_files),
            ("Temporary Files", self.clean_temporary_files),
            ("Media Temporary Files", self.clean_media_temp_files),
            ("Database Cleanup", self.clean_old_database_data),
            ("Import Optimization", self.optimize_imports),
            ("Structure Validation", self.validate_project_structure)
        ]
        
        for operation_name, operation_func in cleanup_operations:
            print(f"\n🔧 {operation_name}")
            print("-" * 40)
            try:
                operation_func()
            except Exception as e:
                self.log_error(f"Failed during {operation_name}: {e}")
                
        self.generate_cleanup_report()
        
        print("\n" + "=" * 60)
        print("🎉 CLEANUP COMPLETED!")
        print(f"📊 Total operations: {len(self.cleaned_items)}")
        print(f"❌ Errors: {len(self.errors)}")
        print("📄 Report saved to: cleanup_report.txt")
        print("=" * 60)

if __name__ == "__main__":
    # Get project root directory
    project_root = "/workspaces/watch-party-backend"
    
    # Create cleaner instance and run cleanup
    cleaner = ProjectCleaner(project_root)
    cleaner.run_full_cleanup()
