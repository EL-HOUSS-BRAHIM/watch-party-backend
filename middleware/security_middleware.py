"""
Enhanced security middleware for Watch Party Backend
"""

import time
import json
import logging
from django.http import JsonResponse
from django.core.cache import cache
from django.conf import settings
from django.utils.deprecation import MiddlewareMixin
from django.middleware.csrf import CsrfViewMiddleware
from django.views.decorators.csrf import csrf_exempt
from django.utils.functional import SimpleLazyObject
from core.security import SecurityHeaders, get_client_ip, rate_limit_key

logger = logging.getLogger(__name__)


class EnhancedSecurityMiddleware(MiddlewareMixin):
    """
    Enhanced security middleware with comprehensive protections
    """
    
    def __init__(self, get_response):
        self.get_response = get_response
        super().__init__(get_response)
    
    def process_request(self, request):
        """
        Process incoming requests for security checks
        """
        # Add client IP to request
        request.client_ip = get_client_ip(request)
        
        # Check for suspicious patterns in request
        if self._is_suspicious_request(request):
            logger.warning(f"Suspicious request detected from {request.client_ip}")
            return JsonResponse(
                {'error': 'Request blocked for security reasons'},
                status=403
            )
        
        # Validate request size
        if self._is_request_too_large(request):
            return JsonResponse(
                {'error': 'Request too large'},
                status=413
            )
        
        return None
    
    def process_response(self, request, response):
        """
        Process outgoing responses for security headers
        """
        # Add security headers
        response = SecurityHeaders.add_security_headers(response)
        
        # Add rate limit headers if applicable
        if hasattr(request, 'rate_limit_remaining'):
            response['X-RateLimit-Remaining'] = str(request.rate_limit_remaining)
            response['X-RateLimit-Reset'] = str(request.rate_limit_reset)
        
        return response
    
    def _is_suspicious_request(self, request):
        """
        Check if request contains suspicious patterns
        """
        suspicious_patterns = [
            # SQL injection patterns
            r'union\s+select',
            r'drop\s+table',
            r'insert\s+into',
            r'delete\s+from',
            
            # XSS patterns
            r'<script',
            r'javascript:',
            r'onload\s*=',
            r'onerror\s*=',
            
            # Path traversal
            r'\.\./.*\.\.',
            r'etc/passwd',
            r'windows/system32',
            
            # Command injection
            r';\s*cat\s+',
            r';\s*ls\s+',
            r'`.*`',
            r'\$\(.*\)',
        ]
        
        # Check query parameters
        query_string = request.META.get('QUERY_STRING', '').lower()
        for pattern in suspicious_patterns:
            import re
            if re.search(pattern, query_string, re.IGNORECASE):
                return True
        
        # Check headers
        for header_name, header_value in request.META.items():
            if isinstance(header_value, str):
                for pattern in suspicious_patterns:
                    if re.search(pattern, header_value.lower(), re.IGNORECASE):
                        return True
        
        return False
    
    def _is_request_too_large(self, request):
        """
        Check if request is too large
        """
        max_size = getattr(settings, 'MAX_REQUEST_SIZE', 10 * 1024 * 1024)  # 10MB default
        
        content_length = request.META.get('CONTENT_LENGTH')
        if content_length:
            try:
                if int(content_length) > max_size:
                    return True
            except (ValueError, TypeError):
                pass
        
        return False


class AdvancedRateLimitMiddleware(MiddlewareMixin):
    """
    Advanced rate limiting with multiple strategies
    """
    
    def __init__(self, get_response):
        self.get_response = get_response
        super().__init__(get_response)
        
        # Rate limit configurations
        self.rate_limits = {
            'default': {'requests': 1000, 'period': 3600},  # 1000 requests per hour
            'auth': {'requests': 5, 'period': 300},          # 5 auth attempts per 5 minutes
            'upload': {'requests': 10, 'period': 3600},      # 10 uploads per hour
            'api': {'requests': 100, 'period': 3600},        # 100 API calls per hour
        }
    
    def process_request(self, request):
        """
        Check rate limits for incoming requests
        """
        if not getattr(settings, 'ENABLE_RATE_LIMITING', True):
            return None
        
        # Determine rate limit category
        category = self._get_rate_limit_category(request)
        
        # Get rate limit configuration
        config = self.rate_limits.get(category, self.rate_limits['default'])
        
        # Generate cache key
        cache_key = f"rate_limit:{category}:{rate_limit_key(request)}"
        
        # Check current usage
        current_usage = cache.get(cache_key, 0)
        
        if current_usage >= config['requests']:
            logger.warning(f"Rate limit exceeded for {request.client_ip} in category {category}")
            return JsonResponse(
                {
                    'error': 'Rate limit exceeded',
                    'retry_after': config['period']
                },
                status=429
            )
        
        # Increment usage
        cache.set(cache_key, current_usage + 1, config['period'])
        
        # Add rate limit info to request
        request.rate_limit_remaining = config['requests'] - current_usage - 1
        request.rate_limit_reset = time.time() + config['period']
        
        return None
    
    def _get_rate_limit_category(self, request):
        """
        Determine rate limit category based on request
        """
        path = request.path.lower()
        
        if '/auth/' in path:
            return 'auth'
        elif request.method in ['POST', 'PUT'] and ('upload' in path or 'video' in path):
            return 'upload'
        elif path.startswith('/api/'):
            return 'api'
        else:
            return 'default'


class CSRFProtectionMiddleware(CsrfViewMiddleware):
    """
    Enhanced CSRF protection middleware
    """
    
    def process_request(self, request):
        """
        Enhanced CSRF token processing
        """
        # Skip CSRF for certain API endpoints with proper authentication
        if self._should_skip_csrf(request):
            setattr(request, '_dont_enforce_csrf_checks', True)
        
        return super().process_request(request)
    
    def process_response(self, request, response):
        """
        Add CSRF token to response headers for SPA
        """
        response = super().process_response(request, response)
        
        # Add CSRF token to response headers for JavaScript apps
        if hasattr(request, 'META') and request.path.startswith('/api/'):
            from django.middleware.csrf import get_token
            csrf_token = get_token(request)
            response['X-CSRFToken'] = csrf_token
        
        return response
    
    def _should_skip_csrf(self, request):
        """
        Determine if CSRF should be skipped for this request
        """
        # Skip for OPTIONS requests (CORS preflight)
        if request.method == 'OPTIONS':
            return True
        
        # Skip for properly authenticated API requests
        if (request.path.startswith('/api/') and 
            hasattr(request, 'user') and 
            request.user.is_authenticated and
            'Bearer' in request.META.get('HTTP_AUTHORIZATION', '')):
            return True
        
        # Skip for webhook endpoints
        webhook_paths = ['/api/webhooks/', '/api/billing/webhook/']
        if any(request.path.startswith(path) for path in webhook_paths):
            return True
        
        return False


class FileUploadSecurityMiddleware(MiddlewareMixin):
    """
    Enhanced file upload security middleware
    """
    
    def __init__(self, get_response):
        self.get_response = get_response
        super().__init__(get_response)
        
        # Maximum file sizes by type
        self.max_file_sizes = {
            'video': 500 * 1024 * 1024,  # 500MB
            'image': 10 * 1024 * 1024,   # 10MB
            'document': 5 * 1024 * 1024,  # 5MB
        }
    
    def process_request(self, request):
        """
        Process file upload requests
        """
        if request.method not in ['POST', 'PUT', 'PATCH']:
            return None
        
        # Check if request contains files
        if not hasattr(request, 'FILES') or not request.FILES:
            return None
        
        # Validate uploaded files
        for field_name, uploaded_file in request.FILES.items():
            try:
                self._validate_uploaded_file(uploaded_file, request)
            except ValueError as e:
                logger.warning(f"File upload validation failed: {e}")
                return JsonResponse(
                    {'error': f'File validation failed: {str(e)}'},
                    status=400
                )
        
        return None
    
    def _validate_uploaded_file(self, uploaded_file, request):
        """
        Validate individual uploaded file
        """
        from core.security import FileSecurityValidator
        
        # Determine file type based on upload context
        file_type = self._determine_file_type(request.path, uploaded_file.name)
        
        # Validate file type and signature
        FileSecurityValidator.validate_file_type(uploaded_file, file_type)
        
        # Validate file size
        max_size_mb = self.max_file_sizes.get(file_type, 5 * 1024 * 1024) // (1024 * 1024)
        FileSecurityValidator.validate_file_size(uploaded_file, max_size_mb)
        
        # Sanitize filename
        uploaded_file.name = FileSecurityValidator.sanitize_filename(uploaded_file.name)
        
        # Check for malicious content (basic scan)
        self._scan_file_content(uploaded_file)
    
    def _determine_file_type(self, path, filename):
        """
        Determine expected file type based on upload context
        """
        if '/video' in path:
            return 'video'
        elif '/avatar' in path or '/profile' in path or '/thumbnail' in path:
            return 'image'
        else:
            # Determine by file extension
            ext = filename.lower().split('.')[-1] if '.' in filename else ''
            if ext in ['mp4', 'avi', 'mov', 'wmv', 'flv', 'webm', 'mkv']:
                return 'video'
            elif ext in ['jpg', 'jpeg', 'png', 'gif', 'webp']:
                return 'image'
            else:
                return 'document'
    
    def _scan_file_content(self, uploaded_file):
        """
        Basic malicious content scanning
        """
        try:
            # Read first chunk to scan for malicious patterns
            uploaded_file.seek(0)
            content_sample = uploaded_file.read(1024).decode('utf-8', errors='ignore')
            uploaded_file.seek(0)
            
            # Check for script content in non-script files
            suspicious_patterns = [
                '<script', 'javascript:', 'vbscript:', 'onload=', 'onerror=',
                '<?php', '<%', 'eval(', 'exec(', 'system('
            ]
            
            content_lower = content_sample.lower()
            for pattern in suspicious_patterns:
                if pattern in content_lower:
                    raise ValueError(f"Suspicious content detected: {pattern}")
                    
        except UnicodeDecodeError:
            # Binary files are expected to not be UTF-8 decodable
            pass
        except Exception as e:
            logger.warning(f"File content scan error: {e}")


class APIVersioningMiddleware(MiddlewareMixin):
    """
    API versioning middleware
    """
    
    def __init__(self, get_response):
        self.get_response = get_response
        super().__init__(get_response)
        self.default_version = 'v2'
        self.supported_versions = ['v1', 'v2']
    
    def process_request(self, request):
        """
        Process API version from request
        """
        if not request.path.startswith('/api/'):
            return None
        
        # Get version from header
        version = request.META.get('HTTP_API_VERSION')
        
        # Get version from query parameter
        if not version:
            version = request.GET.get('version')
        
        # Get version from URL path
        if not version:
            path_parts = request.path.strip('/').split('/')
            if len(path_parts) > 1 and path_parts[1].startswith('v'):
                version = path_parts[1]
        
        # Use default version if none specified
        if not version:
            version = self.default_version
        
        # Validate version
        if version not in self.supported_versions:
            return JsonResponse(
                {
                    'error': f'Unsupported API version: {version}',
                    'supported_versions': self.supported_versions
                },
                status=400
            )
        
        # Add version to request
        request.api_version = version
        
        return None
    
    def process_response(self, request, response):
        """
        Add API version to response headers
        """
        if hasattr(request, 'api_version'):
            response['API-Version'] = request.api_version
            response['Supported-Versions'] = ', '.join(self.supported_versions)
        
        return response


class SecurityAuditMiddleware(MiddlewareMixin):
    """
    Security audit and logging middleware
    """
    
    def __init__(self, get_response):
        self.get_response = get_response
        super().__init__(get_response)
        self.logger = logging.getLogger('security_audit')
    
    def process_request(self, request):
        """
        Log security-relevant events
        """
        # Log authentication attempts
        if '/auth/' in request.path:
            self.logger.info(f"Auth attempt from {get_client_ip(request)} to {request.path}")
        
        # Log admin access
        if '/admin/' in request.path and hasattr(request, 'user') and request.user.is_authenticated:
            self.logger.info(f"Admin access by {request.user.username} from {get_client_ip(request)}")
        
        # Log file uploads
        if request.method in ['POST', 'PUT'] and hasattr(request, 'FILES') and request.FILES:
            self.logger.info(f"File upload from {get_client_ip(request)} - {len(request.FILES)} files")
        
        return None
    
    def process_exception(self, request, exception):
        """
        Log security exceptions
        """
        if isinstance(exception, (PermissionError, ValueError)):
            self.logger.warning(
                f"Security exception from {get_client_ip(request)}: {type(exception).__name__}: {exception}"
            )
        
        return None
