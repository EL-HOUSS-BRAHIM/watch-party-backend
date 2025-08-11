"""
Enhanced Performance monitoring middleware for API endpoints with rate limiting and compression
"""

import time
import json
import gzip
import hashlib
from io import BytesIO
import logging
from django.core.cache import cache
from django.utils.deprecation import MiddlewareMixin
from django.http import JsonResponse, HttpResponse
from django.conf import settings
from django.contrib.auth.models import AnonymousUser
from rest_framework import status

logger = logging.getLogger('watchparty.performance')


class RateLimitMiddleware(MiddlewareMixin):
    """
    Advanced rate limiting middleware with multiple strategies
    """
    
    def __init__(self, get_response):
        self.get_response = get_response
        
        # Rate limit configurations
        self.rate_limits = {
            'default': {'requests': 100, 'window': 3600},  # 100 requests per hour
            'search': {'requests': 50, 'window': 600},     # 50 searches per 10 minutes
            'upload': {'requests': 10, 'window': 3600},    # 10 uploads per hour
            'auth': {'requests': 20, 'window': 900},       # 20 auth attempts per 15 minutes
            'api': {'requests': 1000, 'window': 3600},     # 1000 API calls per hour
        }
        
        # Path patterns for different rate limits
        self.rate_limit_patterns = {
            'search': ['/api/search/', '/api/discover/'],
            'upload': ['/api/videos/upload/', '/api/videos/'],
            'auth': ['/api/auth/', '/api/authentication/'],
            'api': ['/api/'],
        }
        
        super().__init__(get_response)
    
    def process_request(self, request):
        """Apply rate limiting"""
        if not getattr(settings, 'ENABLE_RATE_LIMITING', True):
            return None
        
        # Skip rate limiting for admin users
        if hasattr(request, 'user') and request.user.is_staff:
            return None
        
        # Determine rate limit type
        rate_limit_type = self.get_rate_limit_type(request.path)
        
        # Get user identifier
        user_id = self.get_user_identifier(request)
        
        # Check rate limit
        if self.is_rate_limited(user_id, rate_limit_type, request.method):
            return self.rate_limit_response(rate_limit_type)
        
        return None
    
    def get_rate_limit_type(self, path):
        """Determine rate limit type based on path"""
        for limit_type, patterns in self.rate_limit_patterns.items():
            if any(path.startswith(pattern) for pattern in patterns):
                return limit_type
        return 'default'
    
    def get_user_identifier(self, request):
        """Get unique identifier for rate limiting"""
        if hasattr(request, 'user') and not isinstance(request.user, AnonymousUser):
            return f"user:{request.user.id}"
        else:
            # Use IP address for anonymous users
            ip = self.get_client_ip(request)
            return f"ip:{ip}"
    
    def get_client_ip(self, request):
        """Get client IP address"""
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip = x_forwarded_for.split(',')[0].strip()
        else:
            ip = request.META.get('REMOTE_ADDR', '127.0.0.1')
        return ip
    
    def is_rate_limited(self, user_id, rate_limit_type, method):
        """Check if user is rate limited"""
        config = self.rate_limits.get(rate_limit_type, self.rate_limits['default'])
        
        # Different limits for different HTTP methods
        if method in ['POST', 'PUT', 'PATCH', 'DELETE']:
            config = {
                'requests': config['requests'] // 2,  # Stricter for write operations
                'window': config['window']
            }
        
        cache_key = f"rate_limit:{rate_limit_type}:{user_id}"
        current_time = int(time.time())
        window_start = current_time - config['window']
        
        # Get request timestamps from cache
        request_times = cache.get(cache_key, [])
        
        # Remove old requests outside the window
        request_times = [t for t in request_times if t > window_start]
        
        # Check if limit exceeded
        if len(request_times) >= config['requests']:
            return True
        
        # Add current request time
        request_times.append(current_time)
        
        # Update cache
        cache.set(cache_key, request_times, timeout=config['window'])
        
        return False
    
    def rate_limit_response(self, rate_limit_type):
        """Return rate limit exceeded response"""
        config = self.rate_limits.get(rate_limit_type, self.rate_limits['default'])
        
        return JsonResponse({
            'error': 'Rate limit exceeded',
            'message': f'Too many requests. Limit: {config["requests"]} per {config["window"]} seconds',
            'retry_after': config['window']
        }, status=status.HTTP_429_TOO_MANY_REQUESTS)


class ResponseCompressionMiddleware(MiddlewareMixin):
    """
    Compress HTTP responses to improve performance
    """
    
    def __init__(self, get_response):
        self.get_response = get_response
        self.min_length = 200  # Minimum response size to compress
        self.compressible_types = [
            'application/json',
            'text/html',
            'text/css',
            'text/javascript',
            'application/javascript',
            'text/xml',
            'application/xml',
        ]
        super().__init__(get_response)
    
    def process_response(self, request, response):
        """Compress response if appropriate"""
        if not self.should_compress(request, response):
            return response
        
        # Check if client accepts gzip
        accept_encoding = request.META.get('HTTP_ACCEPT_ENCODING', '')
        if 'gzip' not in accept_encoding:
            return response
        
        # Compress the response
        compressed_content = self.compress_content(response.content)
        
        if len(compressed_content) < len(response.content):
            response.content = compressed_content
            response['Content-Encoding'] = 'gzip'
            response['Content-Length'] = str(len(compressed_content))
            response['Vary'] = 'Accept-Encoding'
        
        return response
    
    def should_compress(self, request, response):
        """Determine if response should be compressed"""
        # Don't compress if already compressed
        if response.get('Content-Encoding'):
            return False
        
        # Don't compress small responses
        if len(response.content) < self.min_length:
            return False
        
        # Check content type
        content_type = response.get('Content-Type', '').split(';')[0]
        if content_type not in self.compressible_types:
            return False
        
        # Don't compress for certain status codes
        if response.status_code < 200 or response.status_code >= 300:
            return False
        
        return True
    
    def compress_content(self, content):
        """Compress content using gzip"""
        if isinstance(content, str):
            content = content.encode('utf-8')
        
        buffer = BytesIO()
        with gzip.GzipFile(fileobj=buffer, mode='wb') as f:
            f.write(content)
        
        return buffer.getvalue()


class APIPerformanceMiddleware(MiddlewareMixin):
    """
    Enhanced middleware to monitor API performance and implement caching strategies
    """
    
    # Cache configuration for different endpoint types
    CACHE_CONFIGS = {
        '/api/store/items/': {'timeout': 300, 'cache_key': 'store_items'},  # 5 minutes
        '/api/search/discover/': {'timeout': 600, 'cache_key': 'discover_content'},  # 10 minutes
        '/api/analytics/platform-overview/': {'timeout': 120, 'cache_key': 'platform_overview'},  # 2 minutes
        '/api/support/faqs/': {'timeout': 3600, 'cache_key': 'faqs_list'},  # 1 hour
        '/api/users/leaderboard/': {'timeout': 300, 'cache_key': 'leaderboard'},  # 5 minutes
        '/api/videos/': {'timeout': 600, 'cache_key': 'videos'},  # 10 minutes
        '/api/search/': {'timeout': 300, 'cache_key': 'search'},  # 5 minutes
        '/api/notifications/': {'timeout': 60, 'cache_key': 'notifications'},  # 1 minute
    }
    
    def __init__(self, get_response):
        self.get_response = get_response
        self.performance_thresholds = {
            'slow_request_ms': 1000,
            'very_slow_request_ms': 5000,
            'max_response_size_mb': 10,
        }
        super().__init__(get_response)
    
    def process_request(self, request):
        """Start performance timing and check cache"""
        request._performance_start_time = time.time()
        request._performance_path = request.get_full_path()
        
        # Check for cached responses for GET requests
        if request.method == 'GET' and hasattr(settings, 'USE_CACHE') and settings.USE_CACHE:
            cache_config = self.get_cache_config(request.path)
            if cache_config:
                cache_key = self.generate_cache_key(request, cache_config)
                cached_response = cache.get(cache_key)
                if cached_response:
                    logger.info(f"Cache hit for {request.path}")
                    response = HttpResponse(
                        content=cached_response['content'],
                        content_type=cached_response['content_type'],
                        status=cached_response['status']
                    )
                    response['X-Cache'] = 'HIT'
                    return response
        
        return None
    
    def process_response(self, request, response):
        """Log performance metrics and cache responses"""
        if not hasattr(request, '_performance_start_time'):
            return response
        
        # Calculate metrics
        response_time_ms = (time.time() - request._performance_start_time) * 1000
        response_size_bytes = len(response.content) if hasattr(response, 'content') else 0
        response_size_mb = response_size_bytes / (1024 * 1024)
        
        # Add performance headers
        response['X-Response-Time'] = f"{response_time_ms:.2f}ms"
        response['X-Response-Size'] = f"{response_size_bytes} bytes"
        
        # Log performance metrics
        self.log_performance_metrics(request, response, response_time_ms, response_size_mb)
        
        # Cache successful GET responses
        if (request.method == 'GET' and response.status_code == 200 and 
            hasattr(settings, 'USE_CACHE') and settings.USE_CACHE):
            cache_config = self.get_cache_config(request.path)
            if cache_config:
                self.cache_response(request, response, cache_config)
        
        # Track performance metrics
        self.track_performance_metrics(request, response_time_ms, response_size_bytes)
        
        return response
    
    def get_cache_config(self, path):
        """Get cache configuration for a path"""
        for pattern, config in self.CACHE_CONFIGS.items():
            if path.startswith(pattern):
                return config
        return None
    
    def generate_cache_key(self, request, cache_config):
        """Generate cache key for request"""
        key_parts = [cache_config['cache_key'], request.get_full_path()]
        
        # Add user-specific caching if authenticated
        if hasattr(request, 'user') and not isinstance(request.user, AnonymousUser):
            key_parts.append(f"user:{request.user.id}")
        
        # Create hash of key parts
        key_string = '|'.join(key_parts)
        key_hash = hashlib.md5(key_string.encode()).hexdigest()
        
        return f"api_cache:{key_hash}"
    
    def cache_response(self, request, response, cache_config):
        """Cache the response"""
        cache_key = self.generate_cache_key(request, cache_config)
        cached_data = {
            'content': response.content,
            'content_type': response.get('Content-Type', 'application/json'),
            'status': response.status_code,
        }
        
        cache.set(cache_key, cached_data, timeout=cache_config['timeout'])
        response['X-Cache'] = 'MISS'
    
    def log_performance_metrics(self, request, response, response_time_ms, response_size_mb):
        """Log performance metrics and issues"""
        method = request.method
        path = request._performance_path
        status_code = response.status_code
        
        # Log slow requests
        if response_time_ms > self.performance_thresholds['very_slow_request_ms']:
            logger.error(
                f"Very slow API request: {method} {path} - "
                f"{response_time_ms:.2f}ms (Status: {status_code})"
            )
        elif response_time_ms > self.performance_thresholds['slow_request_ms']:
            logger.warning(
                f"Slow API request: {method} {path} - "
                f"{response_time_ms:.2f}ms (Status: {status_code})"
            )
        
        # Log large responses
        if response_size_mb > self.performance_thresholds['max_response_size_mb']:
            logger.warning(
                f"Large API response: {method} {path} - "
                f"{response_size_mb:.2f}MB (Status: {status_code})"
            )
        
        # Log general performance info for debugging
        if settings.DEBUG:
            logger.info(
                f"API Performance: {method} {path} - "
                f"{response_time_ms:.2f}ms, {response_size_mb:.3f}MB, Status: {status_code}"
            )
    
    def track_performance_metrics(self, request, response_time_ms, response_size_bytes):
        """Track performance metrics for analytics"""
        # Create performance metrics entry
        metrics_key = f"api_metrics:{int(time.time() // 300)}"  # 5-minute buckets
        
        metrics = cache.get(metrics_key, {
            'request_count': 0,
            'total_response_time': 0,
            'total_response_size': 0,
            'slow_requests': 0,
        })
        
        metrics['request_count'] += 1
        metrics['total_response_time'] += response_time_ms
        metrics['total_response_size'] += response_size_bytes
        
        if response_time_ms > self.performance_thresholds['slow_request_ms']:
            metrics['slow_requests'] += 1
        
        cache.set(metrics_key, metrics, timeout=1800)  # 30 minutes
        
        # Convert milliseconds to seconds for logging
        duration_seconds = response_time_ms / 1000.0
        
        if duration_seconds > 1.0:  # Log requests taking more than 1 second
            logger.warning(
                f"Slow request: {request.method} {request.path} took {duration_seconds:.2f}s"
            )
        
        # Log performance metrics
        logger.info(
            f"API Performance: {request.method} {request.path} "
            f"- {duration_seconds:.3f}s - Response size: {response_size_bytes} bytes"
        )
    
    def get_cache_config(self, path):
        """Get cache configuration for a given path"""
        for endpoint, config in self.CACHE_CONFIGS.items():
            if path.startswith(endpoint):
                return config
        return None


class APIRateLimitingMiddleware(MiddlewareMixin):
    """
    Enhanced rate limiting middleware with different limits per endpoint type
    """
    
    RATE_LIMITS = {
        'default': {'requests': 100, 'window': 60},  # 100 requests per minute
        'auth': {'requests': 5, 'window': 60},       # 5 auth requests per minute
        'upload': {'requests': 10, 'window': 60},    # 10 uploads per minute
        'search': {'requests': 30, 'window': 60},    # 30 searches per minute
        'messaging': {'requests': 50, 'window': 60}, # 50 messages per minute
    }
    
    def get_client_ip(self, request):
        """Get client IP address"""
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip = x_forwarded_for.split(',')[0]
        else:
            ip = request.META.get('REMOTE_ADDR')
        return ip
    
    def get_rate_limit_key(self, request):
        """Determine rate limit category based on endpoint"""
        path = request.path
        
        if '/api/auth/' in path:
            return 'auth'
        elif '/api/videos/' in path and request.method == 'POST':
            return 'upload'
        elif '/api/search/' in path:
            return 'search'
        elif '/api/messaging/' in path:
            return 'messaging'
        else:
            return 'default'
    
    def process_request(self, request):
        """Check rate limits"""
        if not hasattr(settings, 'ENABLE_RATE_LIMITING') or not settings.ENABLE_RATE_LIMITING:
            return None
        
        client_ip = self.get_client_ip(request)
        rate_limit_key = self.get_rate_limit_key(request)
        rate_config = self.RATE_LIMITS[rate_limit_key]
        
        cache_key = f"rate_limit_{rate_limit_key}_{client_ip}"
        current_requests = cache.get(cache_key, 0)
        
        if current_requests >= rate_config['requests']:
            logger.warning(f"Rate limit exceeded for {client_ip} on {request.path}")
            return JsonResponse({
                'error': 'Rate limit exceeded',
                'limit': rate_config['requests'],
                'window': rate_config['window']
            }, status=429)
        
        # Increment counter
        cache.set(cache_key, current_requests + 1, rate_config['window'])
        
        return None
