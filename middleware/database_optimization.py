"""
Database Query Optimization Middleware
"""

import time
import logging
from django.db import connection
from django.conf import settings
from django.core.cache import cache
from django.utils.deprecation import MiddlewareMixin

logger = logging.getLogger(__name__)


class QueryOptimizationMiddleware(MiddlewareMixin):
    """
    Middleware to optimize database queries and track performance
    """
    
    def __init__(self, get_response):
        self.get_response = get_response
        self.slow_query_threshold = getattr(settings, 'SLOW_QUERY_THRESHOLD_MS', 500)
        self.enable_query_logging = getattr(settings, 'ENABLE_QUERY_LOGGING', settings.DEBUG)
        super().__init__(get_response)
    
    def process_request(self, request):
        """Initialize query tracking"""
        request._query_start_time = time.time()
        request._queries_before = len(connection.queries)
        return None
    
    def process_response(self, request, response):
        """Track and optimize query performance"""
        if not hasattr(request, '_query_start_time'):
            return response
        
        # Calculate query metrics
        query_time = (time.time() - request._query_start_time) * 1000
        queries_count = len(connection.queries) - request._queries_before
        
        # Log performance metrics
        if self.enable_query_logging:
            self.log_query_performance(request, query_time, queries_count)
        
        # Check for slow queries
        if query_time > self.slow_query_threshold:
            self.handle_slow_request(request, query_time, queries_count)
        
        # Add performance headers for debugging
        if settings.DEBUG:
            response['X-Query-Count'] = str(queries_count)
            response['X-Query-Time'] = f"{query_time:.2f}ms"
        
        return response
    
    def log_query_performance(self, request, query_time, queries_count):
        """Log query performance metrics"""
        path = request.get_full_path()
        method = request.method
        
        logger.info(
            f"Query Performance: {method} {path} - "
            f"{queries_count} queries in {query_time:.2f}ms"
        )
        
        # Log individual slow queries if debug is enabled
        if settings.DEBUG and query_time > self.slow_query_threshold:
            for query in connection.queries[-queries_count:]:
                query_time_ms = float(query['time']) * 1000
                if query_time_ms > 100:  # Log queries > 100ms
                    logger.warning(
                        f"Slow Query ({query_time_ms:.2f}ms): {query['sql'][:200]}..."
                    )
    
    def handle_slow_request(self, request, query_time, queries_count):
        """Handle slow requests"""
        path = request.get_full_path()
        method = request.method
        user_id = getattr(request.user, 'id', None) if hasattr(request, 'user') else None
        
        # Log slow request
        logger.warning(
            f"Slow Request: {method} {path} - "
            f"{queries_count} queries in {query_time:.2f}ms (User: {user_id})"
        )
        
        # Store slow request data for analysis
        slow_request_data = {
            'path': path,
            'method': method,
            'query_time': query_time,
            'queries_count': queries_count,
            'user_id': user_id,
            'timestamp': time.time(),
        }
        
        # Cache slow request data for admin review
        cache_key = f"slow_request:{int(time.time())}"
        cache.set(cache_key, slow_request_data, timeout=86400)  # 24 hours


class DatabaseConnectionMiddleware(MiddlewareMixin):
    """
    Middleware to manage database connections efficiently
    """
    
    def process_request(self, request):
        """Ensure fresh database connection for each request"""
        # Close old connections to prevent connection leaks
        connection.ensure_connection()
        return None
    
    def process_response(self, request, response):
        """Clean up database connections"""
        # Close connection if it's been idle
        if hasattr(connection, 'close_if_unusable_or_obsolete'):
            connection.close_if_unusable_or_obsolete()
        return response


class CacheOptimizationMiddleware(MiddlewareMixin):
    """
    Middleware to optimize caching strategies
    """
    
    def __init__(self, get_response):
        self.get_response = get_response
        self.cacheable_paths = [
            '/api/search/',
            '/api/videos/',
            '/api/analytics/',
            '/api/discover/',
        ]
        super().__init__(get_response)
    
    def process_request(self, request):
        """Check for cached responses"""
        if request.method == 'GET' and self.is_cacheable_path(request.path):
            cache_key = self.generate_cache_key(request)
            cached_response = cache.get(cache_key)
            
            if cached_response:
                # Return cached response
                request._cache_hit = True
                return cached_response
        
        request._cache_hit = False
        return None
    
    def process_response(self, request, response):
        """Cache appropriate responses"""
        if (hasattr(request, '_cache_hit') and not request._cache_hit and 
            request.method == 'GET' and 
            response.status_code == 200 and
            self.is_cacheable_path(request.path)):
            
            cache_key = self.generate_cache_key(request)
            timeout = self.get_cache_timeout(request.path)
            cache.set(cache_key, response, timeout=timeout)
        
        return response
    
    def is_cacheable_path(self, path):
        """Check if path is cacheable"""
        return any(path.startswith(cacheable_path) for cacheable_path in self.cacheable_paths)
    
    def generate_cache_key(self, request):
        """Generate cache key for request"""
        path = request.get_full_path()
        user_id = getattr(request.user, 'id', 'anon') if hasattr(request, 'user') else 'anon'
        return f"response:{user_id}:{hash(path)}"
    
    def get_cache_timeout(self, path):
        """Get cache timeout based on path"""
        if '/search/' in path:
            return 300  # 5 minutes
        elif '/analytics/' in path:
            return 1800  # 30 minutes
        elif '/videos/' in path:
            return 600  # 10 minutes
        else:
            return 300  # Default 5 minutes


class QueryCountLimitMiddleware(MiddlewareMixin):
    """
    Middleware to prevent queries from getting out of control
    """
    
    def __init__(self, get_response):
        self.get_response = get_response
        self.max_queries = getattr(settings, 'MAX_QUERIES_PER_REQUEST', 50)
        super().__init__(get_response)
    
    def process_request(self, request):
        """Track initial query count"""
        request._initial_query_count = len(connection.queries)
        return None
    
    def process_response(self, request, response):
        """Check query count and warn if too high"""
        if hasattr(request, '_initial_query_count'):
            query_count = len(connection.queries) - request._initial_query_count
            
            if query_count > self.max_queries:
                logger.warning(
                    f"High query count: {query_count} queries for "
                    f"{request.method} {request.get_full_path()}"
                )
                
                # Add warning header
                response['X-Query-Warning'] = f"High query count: {query_count}"
        
        return response


class DatabaseIndexHintMiddleware(MiddlewareMixin):
    """
    Middleware to suggest database indexes for slow queries
    """
    
    def process_response(self, request, response):
        """Analyze queries and suggest indexes"""
        if not settings.DEBUG:
            return response
        
        # Analyze recent queries for index opportunities
        for query in connection.queries[-10:]:  # Last 10 queries
            query_time = float(query['time']) * 1000
            if query_time > 200:  # Queries slower than 200ms
                self.analyze_query_for_indexes(query)
        
        return response
    
    def analyze_query_for_indexes(self, query):
        """Analyze a query and suggest indexes"""
        sql = query['sql'].lower()
        
        # Simple heuristics for index suggestions
        suggestions = []
        
        if 'where' in sql and 'order by' in sql:
            suggestions.append("Consider composite index on WHERE + ORDER BY columns")
        
        if sql.count('join') > 2:
            suggestions.append("Consider indexes on JOIN conditions")
        
        if 'like' in sql:
            suggestions.append("Consider full-text search index for LIKE queries")
        
        if suggestions:
            logger.info(f"Index suggestions for query: {suggestions}")


# Utility functions for query optimization
def optimize_queryset(queryset, optimization_type='default'):
    """
    Apply common optimizations to querysets
    """
    from core.database_optimization import QUERY_HINTS
    
    if optimization_type in QUERY_HINTS:
        hints = QUERY_HINTS[optimization_type]
        
        if 'select_related' in hints:
            queryset = queryset.select_related(*hints['select_related'])
        
        if 'prefetch_related' in hints:
            queryset = queryset.prefetch_related(*hints['prefetch_related'])
        
        if 'only' in hints:
            queryset = queryset.only(*hints['only'])
    
    return queryset


def cache_queryset_result(cache_key, queryset, timeout=300):
    """
    Cache queryset results with serialization
    """
    cached_result = cache.get(cache_key)
    if cached_result:
        return cached_result
    
    # Execute queryset and cache results
    result = list(queryset)
    cache.set(cache_key, result, timeout=timeout)
    return result


def get_or_cache_count(queryset, cache_key, timeout=300):
    """
    Get count with caching to avoid expensive COUNT queries
    """
    cached_count = cache.get(cache_key)
    if cached_count is not None:
        return cached_count
    
    count = queryset.count()
    cache.set(cache_key, count, timeout=timeout)
    return count
