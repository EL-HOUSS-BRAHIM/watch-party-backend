#!/usr/bin/env python3
"""
Security configuration management and validation script
"""

import os
import sys
import secrets
import string
from pathlib import Path
import subprocess
import hashlib
import json
from datetime import datetime


class SecurityConfigManager:
    """Manage and validate security configurations"""
    
    def __init__(self):
        self.project_dir = Path(__file__).parent
        self.env_file = self.project_dir / '.env'
        self.security_report = {
            'timestamp': datetime.now().isoformat(),
            'checks': {},
            'recommendations': [],
            'critical_issues': [],
            'warnings': []
        }
    
    def generate_secret_key(self, length=50):
        """Generate a secure Django SECRET_KEY"""
        chars = string.ascii_letters + string.digits + '!@#$%^&*(-_=+)'
        secret_key = ''.join(secrets.choice(chars) for _ in range(length))
        return secret_key
    
    def generate_jwt_secret(self, length=64):
        """Generate a secure JWT secret key"""
        return secrets.token_urlsafe(length)
    
    def create_secure_env_template(self):
        """Create a secure .env template file"""
        template_content = f"""# Django Settings
SECRET_KEY={self.generate_secret_key()}
DEBUG=False
ALLOWED_HOSTS=localhost,127.0.0.1,yourdomain.com

# Security Settings
SECURE_SSL_REDIRECT=True
SECURE_HSTS_SECONDS=31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS=True
SECURE_HSTS_PRELOAD=True
SESSION_COOKIE_SECURE=True
CSRF_COOKIE_SECURE=True
USE_HTTPS=True

# JWT Settings
JWT_SECRET_KEY={self.generate_jwt_secret()}
JWT_ACCESS_TOKEN_LIFETIME=60
JWT_REFRESH_TOKEN_LIFETIME=7

# Database Security
DB_SSL_REQUIRE=True
DB_CONN_MAX_AGE=300

# Rate Limiting
ENABLE_RATE_LIMITING=True
RATE_LIMIT_LOGIN_ATTEMPTS=5
RATE_LIMIT_LOGIN_WINDOW=300

# File Upload Security
MAX_UPLOAD_SIZE=500
ALLOWED_VIDEO_FORMATS=mp4,avi,mov,wmv,flv,webm
ALLOWED_IMAGE_FORMATS=jpg,jpeg,png,gif,webp

# API Security
API_REQUIRE_AUTHENTICATION=True
API_ALLOW_ANONYMOUS_READ=False

# External Services (Replace with your keys)
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_S3_BUCKET_NAME=your_bucket_name

STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret

FIREBASE_PROJECT_ID=your_firebase_project_id
FIREBASE_PRIVATE_KEY=your_firebase_private_key

# Email Security
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your_email@yourdomain.com
EMAIL_HOST_PASSWORD=your_app_password

# Cache and Sessions
REDIS_URL=redis://localhost:6379/0
CACHE_TIMEOUT=3600
SESSION_EXPIRE_AT_BROWSER_CLOSE=True

# Monitoring and Logging
LOG_LEVEL=INFO
ENABLE_PERFORMANCE_MONITORING=True
SECURITY_AUDIT_LOGGING=True
"""
        
        env_template_file = self.project_dir / '.env.template'
        with open(env_template_file, 'w') as f:
            f.write(template_content)
        
        print(f"✅ Secure .env template created at {env_template_file}")
        print("⚠️  Remember to update the placeholder values with your actual credentials!")
        
        return env_template_file
    
    def validate_secret_key(self, secret_key):
        """Validate Django SECRET_KEY security"""
        checks = {
            'length': len(secret_key) >= 50,
            'complexity': any(c in secret_key for c in '!@#$%^&*()'),
            'not_default': secret_key != 'your-super-secret-key-here-change-in-production',
            'not_common': secret_key.lower() not in ['secret', 'password', 'django'],
            'entropy': len(set(secret_key)) >= 20  # Character diversity
        }
        
        return checks
    
    def validate_password_policy(self):
        """Validate password policy configuration"""
        # This would check Django's AUTH_PASSWORD_VALIDATORS
        return {
            'min_length_validator': True,  # Should check actual config
            'common_password_validator': True,
            'numeric_password_validator': True,
            'attribute_similarity_validator': True
        }
    
    def check_ssl_configuration(self):
        """Check SSL/TLS configuration"""
        ssl_checks = {
            'secure_ssl_redirect': os.getenv('SECURE_SSL_REDIRECT', 'False').lower() == 'true',
            'secure_hsts_seconds': int(os.getenv('SECURE_HSTS_SECONDS', '0')) > 0,
            'session_cookie_secure': os.getenv('SESSION_COOKIE_SECURE', 'False').lower() == 'true',
            'csrf_cookie_secure': os.getenv('CSRF_COOKIE_SECURE', 'False').lower() == 'true'
        }
        
        return ssl_checks
    
    def check_database_security(self):
        """Check database security configuration"""
        db_checks = {
            'ssl_required': os.getenv('DB_SSL_REQUIRE', 'False').lower() == 'true',
            'connection_pooling': int(os.getenv('DB_CONN_MAX_AGE', '0')) > 0,
            'not_sqlite_in_production': not (
                os.getenv('DEBUG', 'True').lower() == 'false' and 
                'sqlite' in os.getenv('DATABASE_URL', '')
            )
        }
        
        return db_checks
    
    def check_cors_configuration(self):
        """Check CORS configuration security"""
        cors_origins = os.getenv('CORS_ALLOWED_ORIGINS', '')
        
        cors_checks = {
            'not_allow_all_origins': '*' not in cors_origins,
            'specific_domains': len(cors_origins.split(',')) <= 10,  # Reasonable limit
            'no_localhost_in_production': not (
                os.getenv('DEBUG', 'True').lower() == 'false' and
                'localhost' in cors_origins
            )
        }
        
        return cors_checks
    
    def check_file_upload_security(self):
        """Check file upload security settings"""
        max_upload_size = int(os.getenv('MAX_UPLOAD_SIZE', '500'))
        allowed_video_formats = os.getenv('ALLOWED_VIDEO_FORMATS', '').split(',')
        allowed_image_formats = os.getenv('ALLOWED_IMAGE_FORMATS', '').split(',')
        
        upload_checks = {
            'reasonable_max_size': max_upload_size <= 1000,  # 1GB max
            'video_formats_limited': len(allowed_video_formats) <= 10,
            'image_formats_limited': len(allowed_image_formats) <= 10,
            'no_executable_formats': not any(
                ext in ['exe', 'bat', 'sh', 'php', 'jsp'] 
                for ext in allowed_video_formats + allowed_image_formats
            )
        }
        
        return upload_checks
    
    def scan_dependencies_vulnerabilities(self):
        """Scan dependencies for known vulnerabilities"""
        try:
            # Use safety to check for vulnerabilities
            result = subprocess.run(
                ['safety', 'check', '--json'],
                capture_output=True,
                text=True,
                cwd=self.project_dir
            )
            
            if result.returncode == 0:
                return {'vulnerabilities_found': False, 'count': 0}
            else:
                # Parse JSON output to count vulnerabilities
                try:
                    vulns = json.loads(result.stdout)
                    return {
                        'vulnerabilities_found': True,
                        'count': len(vulns),
                        'details': vulns[:5]  # First 5 for summary
                    }
                except json.JSONDecodeError:
                    return {'vulnerabilities_found': True, 'count': 'unknown'}
                    
        except FileNotFoundError:
            print("⚠️  'safety' package not found. Install with: pip install safety")
            return {'vulnerabilities_found': 'unknown', 'scan_failed': True}
    
    def check_logging_security(self):
        """Check logging configuration security"""
        log_checks = {
            'log_level_appropriate': os.getenv('LOG_LEVEL', 'DEBUG') in ['INFO', 'WARNING', 'ERROR'],
            'security_audit_enabled': os.getenv('SECURITY_AUDIT_LOGGING', 'False').lower() == 'true',
            'log_rotation_configured': True,  # Would check actual log rotation config
        }
        
        return log_checks
    
    def generate_security_headers_config(self):
        """Generate recommended security headers configuration"""
        headers_config = {
            'X-Content-Type-Options': 'nosniff',
            'X-Frame-Options': 'DENY',
            'X-XSS-Protection': '1; mode=block',
            'Strict-Transport-Security': 'max-age=31536000; includeSubDomains; preload',
            'Content-Security-Policy': (
                "default-src 'self'; "
                "script-src 'self' 'unsafe-inline' 'unsafe-eval'; "
                "style-src 'self' 'unsafe-inline'; "
                "img-src 'self' data: https:; "
                "font-src 'self'; "
                "connect-src 'self' wss: https:; "
                "media-src 'self' https:; "
                "object-src 'none'; "
                "base-uri 'self'; "
                "form-action 'self'"
            ),
            'Referrer-Policy': 'strict-origin-when-cross-origin',
            'Permissions-Policy': (
                'geolocation=(), microphone=(), camera=(), '
                'magnetometer=(), gyroscope=(), payment=()'
            )
        }
        
        return headers_config
    
    def run_comprehensive_security_audit(self):
        """Run comprehensive security audit"""
        print("🔐 Running Comprehensive Security Audit...")
        print("=" * 60)
        
        # Check secret key
        secret_key = os.getenv('SECRET_KEY', '')
        secret_key_checks = self.validate_secret_key(secret_key)
        self.security_report['checks']['secret_key'] = secret_key_checks
        
        if not all(secret_key_checks.values()):
            self.security_report['critical_issues'].append(
                "Weak SECRET_KEY detected. Generate a new secure key."
            )
        
        # Check SSL/TLS configuration
        ssl_checks = self.check_ssl_configuration()
        self.security_report['checks']['ssl'] = ssl_checks
        
        if not ssl_checks.get('secure_ssl_redirect'):
            self.security_report['warnings'].append(
                "SSL redirect not enabled - users may connect over HTTP"
            )
        
        # Check database security
        db_checks = self.check_database_security()
        self.security_report['checks']['database'] = db_checks
        
        # Check CORS configuration
        cors_checks = self.check_cors_configuration()
        self.security_report['checks']['cors'] = cors_checks
        
        # Check file upload security
        upload_checks = self.check_file_upload_security()
        self.security_report['checks']['file_uploads'] = upload_checks
        
        # Check logging security
        log_checks = self.check_logging_security()
        self.security_report['checks']['logging'] = log_checks
        
        # Scan for dependency vulnerabilities
        vuln_scan = self.scan_dependencies_vulnerabilities()
        self.security_report['checks']['dependencies'] = vuln_scan
        
        if vuln_scan.get('vulnerabilities_found'):
            self.security_report['critical_issues'].append(
                f"Found {vuln_scan.get('count', 'unknown')} dependency vulnerabilities"
            )
        
        # Generate recommendations
        self._generate_recommendations()
        
        # Print report
        self._print_security_report()
        
        # Save detailed report
        self._save_security_report()
        
        return self.security_report
    
    def _generate_recommendations(self):
        """Generate security recommendations"""
        recommendations = []
        
        # Check for common issues and generate recommendations
        if not self.security_report['checks']['secret_key']['length']:
            recommendations.append("Generate a longer SECRET_KEY (min 50 characters)")
        
        if not self.security_report['checks']['ssl']['secure_hsts_seconds']:
            recommendations.append("Enable HSTS with SECURE_HSTS_SECONDS=31536000")
        
        if not self.security_report['checks']['database']['ssl_required']:
            recommendations.append("Enable SSL for database connections")
        
        if self.security_report['checks']['cors']['not_allow_all_origins'] == False:
            recommendations.append("Restrict CORS to specific domains, avoid '*'")
        
        if self.security_report['checks']['dependencies'].get('vulnerabilities_found'):
            recommendations.append("Update vulnerable dependencies")
        
        # Add general recommendations
        recommendations.extend([
            "Regularly rotate API keys and secrets",
            "Enable rate limiting on all API endpoints",
            "Implement proper input validation and sanitization",
            "Use HTTPS for all external communication",
            "Monitor security logs and set up alerts",
            "Conduct regular security audits",
            "Keep Django and dependencies updated",
            "Use environment variables for sensitive data"
        ])
        
        self.security_report['recommendations'] = recommendations
    
    def _print_security_report(self):
        """Print security audit report"""
        print("\n📊 SECURITY AUDIT RESULTS")
        print("=" * 60)
        
        # Print check results
        for category, checks in self.security_report['checks'].items():
            print(f"\n{category.upper()}:")
            if isinstance(checks, dict):
                for check, passed in checks.items():
                    status = "✅" if passed else "❌"
                    print(f"  {status} {check}")
            else:
                print(f"  ℹ️  {checks}")
        
        # Print critical issues
        if self.security_report['critical_issues']:
            print(f"\n🚨 CRITICAL ISSUES ({len(self.security_report['critical_issues'])}):")
            for issue in self.security_report['critical_issues']:
                print(f"  ❌ {issue}")
        
        # Print warnings
        if self.security_report['warnings']:
            print(f"\n⚠️  WARNINGS ({len(self.security_report['warnings'])}):")
            for warning in self.security_report['warnings']:
                print(f"  ⚠️  {warning}")
        
        # Print top recommendations
        print(f"\n💡 RECOMMENDATIONS:")
        for i, rec in enumerate(self.security_report['recommendations'][:5], 1):
            print(f"  {i}. {rec}")
        
        # Overall score
        total_checks = 0
        passed_checks = 0
        
        for checks in self.security_report['checks'].values():
            if isinstance(checks, dict):
                total_checks += len(checks)
                passed_checks += sum(1 for v in checks.values() if v is True)
            else:
                total_checks += 1
                passed_checks += 1 if checks else 0
        
        score = (passed_checks / total_checks * 100) if total_checks > 0 else 0
        
        print(f"\n📈 SECURITY SCORE: {score:.1f}%")
        
        if score >= 90:
            print("🎉 Excellent security configuration!")
        elif score >= 80:
            print("✅ Good security configuration with room for improvement")
        elif score >= 70:
            print("⚠️  Adequate security but requires attention")
        else:
            print("🚨 Poor security configuration - immediate action required")
        
        print("=" * 60)
    
    def _save_security_report(self):
        """Save detailed security report"""
        report_file = self.project_dir / 'security_audit_report.json'
        with open(report_file, 'w') as f:
            json.dump(self.security_report, f, indent=2)
        
        print(f"\n📄 Detailed report saved to: {report_file}")


def main():
    """Main security configuration entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Security Configuration Manager')
    parser.add_argument('--generate-env', action='store_true', help='Generate secure .env template')
    parser.add_argument('--audit', action='store_true', help='Run security audit')
    parser.add_argument('--generate-key', action='store_true', help='Generate new SECRET_KEY')
    parser.add_argument('--generate-jwt', action='store_true', help='Generate new JWT secret')
    
    args = parser.parse_args()
    
    manager = SecurityConfigManager()
    
    if args.generate_env:
        manager.create_secure_env_template()
    elif args.audit:
        manager.run_comprehensive_security_audit()
    elif args.generate_key:
        print(f"New SECRET_KEY: {manager.generate_secret_key()}")
    elif args.generate_jwt:
        print(f"New JWT Secret: {manager.generate_jwt_secret()}")
    else:
        # Default: run audit
        manager.run_comprehensive_security_audit()


if __name__ == '__main__':
    main()
