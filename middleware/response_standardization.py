"""
Response Standardization Middleware (Task 12)
Automatically applies standardized response formats and request tracking
"""

import uuid
import json
import logging
from django.http import JsonResponse
from django.utils.deprecation import MiddlewareMixin
from django.utils import timezone
from rest_framework.response import Response

logger = logging.getLogger(__name__)


class ResponseStandardizationMiddleware(MiddlewareMixin):
    """
    Middleware to standardize API responses and add request tracking
    """
    
    def process_request(self, request):
        """Add request ID to all requests"""
        request.request_id = str(uuid.uuid4())
        request.start_time = timezone.now()
        
        # Log API request
        if request.path.startswith('/api/'):
            logger.info(
                f"API Request: {request.method} {request.path} "
                f"[Request ID: {request.request_id}] "
                f"[User: {getattr(request.user, 'username', 'Anonymous') if hasattr(request, 'user') else 'Unknown'}]"
            )
    
    def process_response(self, request, response):
        """Standardize API responses"""
        
        # Only process API responses
        if not request.path.startswith('/api/'):
            return response
        
        # Calculate response time
        if hasattr(request, 'start_time'):
            response_time = (timezone.now() - request.start_time).total_seconds() * 1000
        else:
            response_time = 0
        
        # Get request ID
        request_id = getattr(request, 'request_id', str(uuid.uuid4()))
        
        # Handle different response types
        if isinstance(response, (JsonResponse, Response)):
            try:
                # Parse existing response data
                if hasattr(response, 'data'):
                    # DRF Response object
                    data = response.data if response.data is not None else {}
                else:
                    # Django JsonResponse
                    data = json.loads(response.content.decode('utf-8')) if response.content else {}
                
                # Check if response is already standardized
                if not self._is_standardized_response(data):
                    # Standardize the response
                    standardized_data = self._standardize_response(
                        data, response.status_code, request_id, response_time
                    )
                    
                    # Update response data
                    if isinstance(response, Response):
                        response.data = standardized_data
                    else:
                        response = JsonResponse(standardized_data, status=response.status_code)
                else:
                    # Add missing metadata to already standardized responses
                    if 'request_id' not in data:
                        data['request_id'] = request_id
                    if 'metadata' not in data:
                        data['metadata'] = {}
                    data['metadata']['response_time_ms'] = round(response_time, 2)
                    
                    if isinstance(response, Response):
                        response.data = data
                    else:
                        response = JsonResponse(data, status=response.status_code)
                
            except (json.JSONDecodeError, AttributeError, TypeError) as e:
                logger.warning(f"Failed to standardize response: {str(e)}")
        
        # Log API response
        logger.info(
            f"API Response: {request.method} {request.path} "
            f"[Status: {response.status_code}] "
            f"[Request ID: {request_id}] "
            f"[Response Time: {response_time:.2f}ms]"
        )
        
        return response
    
    def process_exception(self, request, exception):
        """Handle exceptions with standardized error responses"""
        
        # Only process API exceptions
        if not request.path.startswith('/api/'):
            return None
        
        request_id = getattr(request, 'request_id', str(uuid.uuid4()))
        
        # Log the exception
        logger.error(
            f"API Exception: {request.method} {request.path} "
            f"[Request ID: {request_id}] "
            f"[Exception: {str(exception)}]",
            exc_info=True
        )
        
        # Return standardized error response
        error_data = {
            "success": False,
            "status": "error",
            "message": "Internal server error",
            "timestamp": timezone.now().isoformat(),
            "request_id": request_id,
            "error_code": "INTERNAL_ERROR"
        }
        
        # Add debug info in development
        from django.conf import settings
        if settings.DEBUG:
            error_data["debug_info"] = {
                "exception_type": type(exception).__name__,
                "exception_message": str(exception)
            }
        
        return JsonResponse(error_data, status=500)
    
    def _is_standardized_response(self, data):
        """Check if response is already in standardized format"""
        if not isinstance(data, dict):
            return False
        
        # Check for required standardized fields
        required_fields = ['success', 'status', 'message', 'timestamp']
        return all(field in data for field in required_fields)
    
    def _standardize_response(self, data, status_code, request_id, response_time):
        """Convert response to standardized format"""
        
        # Determine if it's a success or error response
        is_success = 200 <= status_code < 300
        
        standardized = {
            "success": is_success,
            "status": "success" if is_success else "error",
            "message": self._get_default_message(status_code),
            "timestamp": timezone.now().isoformat(),
            "request_id": request_id,
            "metadata": {
                "response_time_ms": round(response_time, 2)
            }
        }
        
        # Handle data field
        if data:
            if is_success:
                # For success responses, check if data has a message
                if isinstance(data, dict) and 'message' in data:
                    standardized['message'] = data.pop('message')
                
                # If there's remaining data, add it to data field
                if data:
                    standardized['data'] = data
            else:
                # For error responses, check for error details
                if isinstance(data, dict):
                    if 'detail' in data:
                        standardized['message'] = data['detail']
                    elif 'error' in data:
                        standardized['message'] = data['error']
                    elif 'message' in data:
                        standardized['message'] = data['message']
                    
                    # Add any additional error details
                    if 'errors' in data:
                        standardized['errors'] = data['errors']
                    if 'details' in data:
                        standardized['details'] = data['details']
                else:
                    standardized['details'] = data
        
        return standardized
    
    def _get_default_message(self, status_code):
        """Get default message for status code"""
        messages = {
            200: "Success",
            201: "Created successfully",
            202: "Accepted",
            204: "No content",
            400: "Bad request",
            401: "Authentication required",
            403: "Access forbidden",
            404: "Resource not found",
            405: "Method not allowed",
            409: "Conflict",
            422: "Validation failed",
            429: "Too many requests",
            500: "Internal server error",
            502: "Bad gateway",
            503: "Service unavailable"
        }
        
        return messages.get(status_code, f"HTTP {status_code}")


class APIVersionMiddleware(MiddlewareMixin):
    """
    Middleware to handle API versioning in responses
    """
    
    def process_response(self, request, response):
        """Add API version to responses"""
        
        # Only process API responses
        if not request.path.startswith('/api/'):
            return response
        
        # Add API version header
        response['X-API-Version'] = '1.0'
        
        # Add to response body if it's a JSON response
        if isinstance(response, (JsonResponse, Response)) and hasattr(response, 'data'):
            try:
                if isinstance(response.data, dict):
                    if 'metadata' not in response.data:
                        response.data['metadata'] = {}
                    response.data['metadata']['api_version'] = '1.0'
            except:
                pass
        
        return response


class CorsStandardizationMiddleware(MiddlewareMixin):
    """
    Middleware to add standardized CORS headers
    """
    
    def process_response(self, request, response):
        """Add standardized CORS headers"""
        
        # Only for API responses
        if request.path.startswith('/api/'):
            response['Access-Control-Allow-Headers'] = (
                'Accept, Content-Type, Authorization, X-Requested-With, '
                'X-API-Version, X-Request-ID'
            )
            response['Access-Control-Expose-Headers'] = (
                'X-API-Version, X-Request-ID, X-Rate-Limit-Remaining'
            )
        
        return response
