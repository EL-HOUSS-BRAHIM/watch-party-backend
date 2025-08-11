"""
Comprehensive test configuration and utilities for Watch Party Backend
"""

import os
import tempfile
from django.test import TestCase, TransactionTestCase
from django.test.utils import override_settings
from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework.test import APITestCase, APIClient
from rest_framework_simplejwt.tokens import RefreshToken
from channels.testing import WebsocketCommunicator, ApplicationCommunicator
from channels.db import database_sync_to_async
import asyncio
import json
from unittest.mock import patch, MagicMock

User = get_user_model()


class BaseTestCase(TestCase):
    """
    Base test case with common setup and utilities
    """
    
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        # Create test media directory
        cls.test_media_root = tempfile.mkdtemp()
    
    def setUp(self):
        """Set up test data"""
        self.user = self.create_test_user()
        self.admin_user = self.create_test_user(
            email='admin@test.com',
            first_name='Admin',
            last_name='User',
            is_staff=True,
            is_superuser=True
        )
    
    def create_test_user(self, email='test@test.com', first_name='Test', 
                        last_name='User', password='testpass123', **kwargs):
        """Create a test user with default or custom attributes"""
        return User.objects.create_user(
            email=email,
            first_name=first_name,
            last_name=last_name,
            password=password,
            **kwargs
        )
    
    def create_test_video_file(self, filename='test_video.mp4', size=1024):
        """Create a test video file"""
        content = b'fake video content' * (size // 18)  # Approximate size
        return SimpleUploadedFile(
            filename,
            content,
            content_type='video/mp4'
        )
    
    def create_test_image_file(self, filename='test_image.jpg', size=1024):
        """Create a test image file"""
        content = b'fake image content' * (size // 18)  # Approximate size
        return SimpleUploadedFile(
            filename,
            content,
            content_type='image/jpeg'
        )


class BaseAPITestCase(APITestCase, BaseTestCase):
    """
    Base API test case with authentication and common utilities
    """
    
    def setUp(self):
        super().setUp()
        self.client = APIClient()
        self.auth_client = APIClient()
        self.admin_client = APIClient()
        
        # Set up authentication
        self.authenticate_user()
        self.authenticate_admin()
    
    def authenticate_user(self, user=None):
        """Authenticate a user for API requests"""
        user = user or self.user
        refresh = RefreshToken.for_user(user)
        self.auth_client.credentials(
            HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}'
        )
        return refresh.access_token
    
    def authenticate_admin(self):
        """Authenticate admin user for API requests"""
        refresh = RefreshToken.for_user(self.admin_user)
        self.admin_client.credentials(
            HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}'
        )
        return refresh.access_token
    
    def assert_response_success(self, response, status_code=200):
        """Assert that response is successful"""
        self.assertEqual(response.status_code, status_code)
        self.assertTrue(response.data.get('success', True))
    
    def assert_response_error(self, response, status_code=400):
        """Assert that response contains an error"""
        self.assertEqual(response.status_code, status_code)
        self.assertIn('error', response.data or {})
    
    def assert_pagination_response(self, response):
        """Assert that response has pagination structure"""
        self.assert_response_success(response)
        data = response.data
        self.assertIn('results', data)
        self.assertIn('count', data)
        self.assertIn('next', data)
        self.assertIn('previous', data)


class SecurityTestMixin:
    """
    Mixin for security-focused tests
    """
    
    def test_csrf_protection(self):
        """Test CSRF protection on state-changing endpoints"""
        if hasattr(self, 'create_url'):
            response = self.client.post(self.create_url, {})
            self.assertIn(response.status_code, [403, 401])  # CSRF or auth error
    
    def test_authentication_required(self):
        """Test that authentication is required"""
        if hasattr(self, 'protected_url'):
            response = self.client.get(self.protected_url)
            self.assertEqual(response.status_code, 401)
    
    def test_sql_injection_protection(self):
        """Test SQL injection protection"""
        malicious_payloads = [
            "'; DROP TABLE users; --",
            "1' OR '1'='1",
            "1; SELECT * FROM users",
            "'; UPDATE users SET password='hacked' WHERE id=1; --"
        ]
        
        for payload in malicious_payloads:
            if hasattr(self, 'search_url'):
                response = self.auth_client.get(
                    self.search_url,
                    {'q': payload}
                )
                # Should not return 500 error or leak sensitive data
                self.assertNotEqual(response.status_code, 500)
    
    def test_xss_protection(self):
        """Test XSS protection"""
        xss_payloads = [
            "<script>alert('xss')</script>",
            "javascript:alert('xss')",
            "<img src=x onerror=alert('xss')>",
            "<svg onload=alert('xss')>"
        ]
        
        for payload in xss_payloads:
            if hasattr(self, 'create_url'):
                response = self.auth_client.post(
                    self.create_url,
                    {'title': payload}
                )
                # Response should either reject or sanitize
                if response.status_code == 201:
                    # If created, check that dangerous content is sanitized
                    response_data = json.dumps(response.data)
                    self.assertNotIn('<script>', response_data)
                    self.assertNotIn('javascript:', response_data)
    
    def test_file_upload_security(self):
        """Test file upload security"""
        if hasattr(self, 'upload_url'):
            # Test malicious file upload
            malicious_file = SimpleUploadedFile(
                'malicious.php',
                b'<?php system($_GET["cmd"]); ?>',
                content_type='application/x-php'
            )
            
            response = self.auth_client.post(
                self.upload_url,
                {'file': malicious_file},
                format='multipart'
            )
            # Should reject malicious files
            self.assertNotEqual(response.status_code, 201)


class PerformanceTestMixin:
    """
    Mixin for performance testing
    """
    
    def test_response_time(self, max_time=1.0):
        """Test that endpoints respond within acceptable time"""
        import time
        
        if hasattr(self, 'list_url'):
            start_time = time.time()
            response = self.auth_client.get(self.list_url)
            end_time = time.time()
            
            response_time = end_time - start_time
            self.assertLess(
                response_time, 
                max_time, 
                f"Response time {response_time}s exceeds maximum {max_time}s"
            )
    
    def test_pagination_performance(self):
        """Test pagination performance with large datasets"""
        if hasattr(self, 'list_url'):
            # Test with different page sizes
            for page_size in [10, 50, 100]:
                response = self.auth_client.get(
                    self.list_url,
                    {'page_size': page_size}
                )
                self.assertEqual(response.status_code, 200)
    
    @patch('django.db.connection.queries_log')
    def test_query_count(self, mock_queries):
        """Test that endpoints don't generate excessive database queries"""
        if hasattr(self, 'detail_url'):
            mock_queries.return_value = []
            response = self.auth_client.get(self.detail_url)
            
            # Should not generate more than 10 queries for a detail view
            query_count = len(mock_queries.return_value)
            self.assertLess(
                query_count, 
                10, 
                f"Detail view generated {query_count} queries (max: 10)"
            )


class WebSocketTestCase(TransactionTestCase):
    """
    Base test case for WebSocket functionality
    """
    
    def setUp(self):
        super().setUp()
        self.user = User.objects.create_user(
            email='test@test.com',
            first_name='Test',
            last_name='User',
            password='testpass123'
        )
    
    async def connect_websocket(self, path, user=None):
        """Connect to WebSocket with authentication"""
        from watchparty.routing import application
        
        user = user or self.user
        
        # Create communicator
        communicator = WebsocketCommunicator(application, path)
        
        # Add authentication headers
        refresh = RefreshToken.for_user(user)
        communicator.scope['headers'] = [
            (b'authorization', f'Bearer {refresh.access_token}'.encode())
        ]
        
        connected, subprotocol = await communicator.connect()
        self.assertTrue(connected)
        
        return communicator
    
    async def test_websocket_authentication(self):
        """Test WebSocket authentication"""
        communicator = await self.connect_websocket('/ws/party/test/')
        
        # Send a test message
        await communicator.send_json_to({
            'type': 'test_message',
            'data': {'content': 'Hello, WebSocket!'}
        })
        
        # Should receive response
        response = await communicator.receive_json_from()
        self.assertIn('type', response)
        
        await communicator.disconnect()


class IntegrationTestCase(BaseAPITestCase):
    """
    Test case for integration tests across multiple components
    """
    
    def test_full_user_workflow(self):
        """Test complete user workflow from registration to party participation"""
        # 1. User registration
        register_data = {
            'username': 'newuser',
            'email': 'new@test.com',
            'password': 'newpass123',
            'password_confirm': 'newpass123'
        }
        response = self.client.post('/api/auth/register/', register_data)
        self.assert_response_success(response, 201)
        
        # 2. User login
        login_data = {
            'username': 'newuser',
            'password': 'newpass123'
        }
        response = self.client.post('/api/auth/login/', login_data)
        self.assert_response_success(response)
        
        # Get access token
        access_token = response.data['access']
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION=f'Bearer {access_token}')
        
        # 3. Create a party
        party_data = {
            'title': 'Test Party',
            'description': 'Integration test party'
        }
        response = client.post('/api/parties/', party_data)
        self.assert_response_success(response, 201)
        party_id = response.data['id']
        
        # 4. Upload a video
        video_file = self.create_test_video_file()
        video_data = {
            'title': 'Test Video',
            'file': video_file
        }
        response = client.post('/api/videos/', video_data, format='multipart')
        self.assert_response_success(response, 201)
        video_id = response.data['id']
        
        # 5. Add video to party
        response = client.post(f'/api/parties/{party_id}/videos/', {'video_id': video_id})
        self.assert_response_success(response, 201)


class LoadTestCase(BaseAPITestCase):
    """
    Test case for load testing critical endpoints
    """
    
    def test_concurrent_user_load(self):
        """Test system behavior under concurrent user load"""
        import threading
        import time
        
        results = []
        
        def make_request():
            try:
                response = self.auth_client.get('/api/users/profile/')
                results.append(response.status_code == 200)
            except Exception as e:
                results.append(False)
        
        # Create 10 concurrent threads
        threads = []
        for i in range(10):
            thread = threading.Thread(target=make_request)
            threads.append(thread)
        
        # Start all threads
        start_time = time.time()
        for thread in threads:
            thread.start()
        
        # Wait for all threads to complete
        for thread in threads:
            thread.join()
        
        end_time = time.time()
        
        # Check results
        success_rate = sum(results) / len(results)
        total_time = end_time - start_time
        
        self.assertGreater(success_rate, 0.8)  # 80% success rate
        self.assertLess(total_time, 5.0)  # Complete within 5 seconds


# Test utilities for mocking external services
class MockExternalServices:
    """Mock external services for testing"""
    
    @staticmethod
    def mock_stripe():
        """Mock Stripe service - returns a decorator"""
        def decorator(func):
            def wrapper(*args, **kwargs):
                with patch('stripe.Customer.create') as mock_create, \
                     patch('stripe.Subscription.create') as mock_sub_create:
                    
                    mock_create.return_value = MagicMock(id='cus_test123')
                    mock_sub_create.return_value = MagicMock(
                        id='sub_test123',
                        status='active'
                    )
                    # Pass mocks as the last argument
                    return func(*args, (mock_create, mock_sub_create), **kwargs)
            return wrapper
        return decorator
    
    @staticmethod
    def mock_aws_s3():
        """Mock AWS S3 service"""
        with patch('boto3.client') as mock_boto3:
            mock_s3 = MagicMock()
            mock_boto3.return_value = mock_s3
            
            mock_s3.upload_fileobj.return_value = None
            mock_s3.generate_presigned_url.return_value = 'https://test-url.com'
            
            yield mock_s3
    
    @staticmethod
    def mock_firebase():
        """Mock Firebase service"""
        with patch('firebase_admin.messaging.send') as mock_send:
            mock_send.return_value = 'projects/test/messages/123'
            yield mock_send


# Performance benchmarking utilities
class PerformanceBenchmark:
    """Utilities for performance benchmarking"""
    
    @staticmethod
    def benchmark_endpoint(client, url, method='GET', data=None, iterations=100):
        """Benchmark an endpoint over multiple iterations"""
        import time
        import statistics
        
        times = []
        
        for i in range(iterations):
            start_time = time.time()
            
            if method == 'GET':
                response = client.get(url)
            elif method == 'POST':
                response = client.post(url, data)
            elif method == 'PUT':
                response = client.put(url, data)
            
            end_time = time.time()
            times.append(end_time - start_time)
        
        return {
            'mean': statistics.mean(times),
            'median': statistics.median(times),
            'min': min(times),
            'max': max(times),
            'stdev': statistics.stdev(times) if len(times) > 1 else 0
        }
    
    @staticmethod
    def benchmark_database_queries(operation_func, iterations=100):
        """Benchmark database operations"""
        from django.db import connection, reset_queries
        import time
        
        query_counts = []
        times = []
        
        for i in range(iterations):
            reset_queries()
            start_time = time.time()
            
            operation_func()
            
            end_time = time.time()
            query_count = len(connection.queries)
            
            times.append(end_time - start_time)
            query_counts.append(query_count)
        
        return {
            'avg_time': sum(times) / len(times),
            'avg_queries': sum(query_counts) / len(query_counts),
            'max_queries': max(query_counts),
            'min_queries': min(query_counts)
        }
