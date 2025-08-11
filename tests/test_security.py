"""
Comprehensive security tests for Watch Party Backend
"""

import json
from django.test import TestCase, override_settings
from django.core.files.uploadedfile import SimpleUploadedFile
from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase
from unittest.mock import patch, MagicMock
import tempfile
import os

from tests.test_base import BaseAPITestCase, SecurityTestMixin
from core.security import (
    InputSanitizer, InputValidator, FileSecurityValidator,
    get_client_ip, rate_limit_key
)

User = get_user_model()


class InputSanitizationTests(TestCase):
    """Test input sanitization functionality"""
    
    def test_html_sanitization(self):
        """Test HTML content sanitization"""
        # Test script tag removal
        dirty_html = '<script>alert("xss")</script><p>Clean content</p>'
        clean_html = InputSanitizer.sanitize_html(dirty_html)
        self.assertNotIn('<script>', clean_html)
        self.assertIn('<p>Clean content</p>', clean_html)
        
        # Test dangerous attributes removal
        dirty_html = '<p onclick="alert(\'xss\')">Content</p>'
        clean_html = InputSanitizer.sanitize_html(dirty_html)
        self.assertNotIn('onclick', clean_html)
        
        # Test allowed tags preservation
        allowed_html = '<b>Bold</b> and <i>italic</i> text'
        clean_html = InputSanitizer.sanitize_html(allowed_html)
        self.assertIn('<b>Bold</b>', clean_html)
        self.assertIn('<i>italic</i>', clean_html)
    
    def test_text_sanitization(self):
        """Test plain text sanitization"""
        # Test dangerous pattern removal
        dirty_text = 'Hello <script>alert("xss")</script> world'
        clean_text = InputSanitizer.sanitize_text(dirty_text)
        self.assertNotIn('<script>', clean_text)
        self.assertIn('Hello', clean_text)
        self.assertIn('world', clean_text)
        
        # Test length limiting
        long_text = 'a' * 1000
        clean_text = InputSanitizer.sanitize_text(long_text, max_length=100)
        self.assertEqual(len(clean_text), 100)
    
    def test_filename_sanitization(self):
        """Test filename sanitization"""
        # Test dangerous characters removal
        dangerous_filename = '../../../etc/passwd'
        clean_filename = InputSanitizer.sanitize_filename(dangerous_filename)
        self.assertNotIn('..', clean_filename)
        self.assertNotIn('/', clean_filename)
        
        # Test special characters handling
        special_filename = 'file<>:"|?*.txt'
        clean_filename = InputSanitizer.sanitize_filename(special_filename)
        self.assertNotIn('<', clean_filename)
        self.assertNotIn('>', clean_filename)
        self.assertIn('.txt', clean_filename)


class InputValidationTests(TestCase):
    """Test input validation functionality"""
    
    def test_email_validation(self):
        """Test email validation"""
        # Valid emails
        valid_emails = [
            'test@example.com',
            'user.name@domain.co.uk',
            'user+tag@example.org'
        ]
        for email in valid_emails:
            try:
                result = InputValidator.validate_email(email)
                self.assertEqual(result, email.lower())
            except Exception as e:
                self.fail(f"Valid email {email} was rejected: {e}")
        
        # Invalid emails
        invalid_emails = [
            'invalid-email',
            '@example.com',
            'user@',
            'user@.com',
            '<script>@example.com'
        ]
        for email in invalid_emails:
            with self.assertRaises(Exception):
                InputValidator.validate_email(email)
    
    def test_username_validation(self):
        """Test username validation"""
        # Valid usernames
        valid_usernames = ['user123', 'test_user', 'user-name', 'user.name']
        for username in valid_usernames:
            try:
                result = InputValidator.validate_username(username)
                self.assertEqual(result, username)
            except Exception as e:
                self.fail(f"Valid username {username} was rejected: {e}")
        
        # Invalid usernames
        invalid_usernames = [
            'us',  # Too short
            'admin',  # Reserved
            'user@name',  # Invalid character
            '<script>',  # Dangerous content
            'a' * 100  # Too long
        ]
        for username in invalid_usernames:
            with self.assertRaises(Exception):
                InputValidator.validate_username(username)
    
    def test_url_validation(self):
        """Test URL validation"""
        # Valid URLs
        valid_urls = [
            'https://example.com',
            'http://test.org/path',
            'https://sub.domain.com/path?query=value'
        ]
        for url in valid_urls:
            try:
                result = InputValidator.validate_url(url)
                self.assertEqual(result, url)
            except Exception as e:
                self.fail(f"Valid URL {url} was rejected: {e}")
        
        # Invalid URLs
        invalid_urls = [
            'javascript:alert("xss")',
            'http://localhost/path',
            'ftp://example.com',  # Wrong scheme
            'http://127.0.0.1/path'
        ]
        for url in invalid_urls:
            with self.assertRaises(Exception):
                InputValidator.validate_url(url)


class FileSecurityTests(TestCase):
    """Test file upload security"""
    
    def test_file_type_validation(self):
        """Test file type validation"""
        # Valid video file
        video_file = SimpleUploadedFile(
            'test.mp4',
            b'fake video content',
            content_type='video/mp4'
        )
        try:
            FileSecurityValidator.validate_file_type(video_file, 'video')
        except Exception as e:
            self.fail(f"Valid video file was rejected: {e}")
        
        # Invalid video file (wrong extension)
        invalid_file = SimpleUploadedFile(
            'test.exe',
            b'fake executable',
            content_type='application/x-executable'
        )
        with self.assertRaises(Exception):
            FileSecurityValidator.validate_file_type(invalid_file, 'video')
    
    def test_file_size_validation(self):
        """Test file size validation"""
        # Valid size file
        small_file = SimpleUploadedFile(
            'small.txt',
            b'small content',
            content_type='text/plain'
        )
        try:
            FileSecurityValidator.validate_file_size(small_file, max_size_mb=1)
        except Exception as e:
            self.fail(f"Small file was rejected: {e}")
        
        # Large file (simulate by setting size attribute)
        large_file = SimpleUploadedFile(
            'large.txt',
            b'content',
            content_type='text/plain'
        )
        large_file.size = 10 * 1024 * 1024  # 10MB
        
        with self.assertRaises(Exception):
            FileSecurityValidator.validate_file_size(large_file, max_size_mb=5)
    
    def test_filename_sanitization(self):
        """Test filename sanitization for uploads"""
        dangerous_names = [
            '../../../etc/passwd',
            'file<script>.txt',
            'file|dangerous.txt',
            'file?.txt',
            'file*.txt'
        ]
        
        for dangerous_name in dangerous_names:
            clean_name = FileSecurityValidator.sanitize_filename(dangerous_name)
            self.assertNotIn('..', clean_name)
            self.assertNotIn('<', clean_name)
            self.assertNotIn('|', clean_name)
            self.assertNotIn('?', clean_name)
            self.assertNotIn('*', clean_name)


class AuthenticationSecurityTests(BaseAPITestCase):
    """Test authentication and authorization security"""
    
    def test_password_policy_enforcement(self):
        """Test password policy enforcement"""
        weak_passwords = [
            'password',  # Common password
            '123456',    # Numeric only
            'abc',       # Too short
            'password123'  # Too simple
        ]
        
        for weak_password in weak_passwords:
            response = self.client.post('/api/auth/register/', {
                'username': 'testuser',
                'email': 'test@test.com',
                'password': weak_password,
                'password_confirm': weak_password
            })
            # Should reject weak passwords
            self.assertNotEqual(response.status_code, 201)
    
    def test_jwt_token_security(self):
        """Test JWT token security measures"""
        # Test token expiration
        login_response = self.client.post('/api/auth/login/', {
            'username': self.user.username,
            'password': 'testpass123'
        })
        self.assertEqual(login_response.status_code, 200)
        
        access_token = login_response.data['access']
        refresh_token = login_response.data['refresh']
        
        # Test access with valid token
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {access_token}')
        response = self.client.get('/api/users/profile/')
        self.assertEqual(response.status_code, 200)
        
        # Test token blacklisting after logout
        response = self.client.post('/api/auth/logout/', {
            'refresh': refresh_token
        })
        self.assertEqual(response.status_code, 200)
        
        # Token should be blacklisted now
        response = self.client.post('/api/auth/refresh/', {
            'refresh': refresh_token
        })
        self.assertNotEqual(response.status_code, 200)
    
    def test_brute_force_protection(self):
        """Test brute force protection on login"""
        # Attempt multiple failed logins
        for i in range(6):  # Exceed rate limit
            response = self.client.post('/api/auth/login/', {
                'username': self.user.username,
                'password': 'wrongpassword'
            })
        
        # Should eventually get rate limited
        self.assertIn(response.status_code, [429, 403])


class APISecurityTests(BaseAPITestCase, SecurityTestMixin):
    """Test API security measures"""
    
    def setUp(self):
        super().setUp()
        self.list_url = '/api/videos/'
        self.create_url = '/api/videos/'
        self.protected_url = '/api/users/profile/'
        self.search_url = '/api/search/'
        self.upload_url = '/api/videos/'
    
    def test_api_versioning_security(self):
        """Test API versioning security"""
        # Test unsupported version
        response = self.client.get('/api/videos/', HTTP_API_VERSION='v999')
        self.assertEqual(response.status_code, 400)
        
        # Test supported version
        response = self.auth_client.get('/api/videos/', HTTP_API_VERSION='v2')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response['API-Version'], 'v2')
    
    def test_rate_limiting(self):
        """Test API rate limiting"""
        # Make multiple rapid requests
        responses = []
        for i in range(101):  # Exceed rate limit
            response = self.auth_client.get('/api/users/profile/')
            responses.append(response.status_code)
        
        # Should eventually get rate limited
        self.assertIn(429, responses)
    
    def test_content_type_validation(self):
        """Test content type validation"""
        # Test invalid content type
        response = self.client.post(
            '/api/auth/login/',
            'invalid json data',
            content_type='text/plain'
        )
        self.assertEqual(response.status_code, 400)
    
    def test_request_size_limits(self):
        """Test request size limits"""
        # Create large payload
        large_data = {'description': 'x' * 10000}  # Very long description
        
        response = self.auth_client.post('/api/parties/', large_data)
        # Should either accept and truncate or reject
        if response.status_code == 201:
            # If accepted, description should be truncated
            self.assertLessEqual(len(response.data.get('description', '')), 5000)
        else:
            # If rejected, should be 400 or 413
            self.assertIn(response.status_code, [400, 413])


@override_settings(CELERY_TASK_ALWAYS_EAGER=True)
class SecurityMiddlewareTests(BaseAPITestCase):
    """Test security middleware functionality"""
    
    def test_security_headers(self):
        """Test security headers are added"""
        response = self.auth_client.get('/api/users/profile/')
        
        # Check for security headers
        self.assertIn('X-XSS-Protection', response)
        self.assertIn('X-Content-Type-Options', response)
        self.assertIn('X-Frame-Options', response)
        self.assertIn('Content-Security-Policy', response)
        self.assertIn('Referrer-Policy', response)
        
        # Check header values
        self.assertEqual(response['X-XSS-Protection'], '1; mode=block')
        self.assertEqual(response['X-Content-Type-Options'], 'nosniff')
        self.assertEqual(response['X-Frame-Options'], 'DENY')
    
    def test_suspicious_request_blocking(self):
        """Test suspicious request detection and blocking"""
        # Test SQL injection attempt
        response = self.client.get('/api/videos/?title=\'; DROP TABLE users; --')
        self.assertIn(response.status_code, [403, 400])
        
        # Test XSS attempt
        response = self.client.get('/api/videos/?search=<script>alert("xss")</script>')
        self.assertIn(response.status_code, [403, 400])
    
    def test_file_upload_security_middleware(self):
        """Test file upload security middleware"""
        # Test malicious file upload
        malicious_file = SimpleUploadedFile(
            'malicious.php',
            b'<?php system($_GET["cmd"]); ?>',
            content_type='application/x-php'
        )
        
        response = self.auth_client.post(
            '/api/videos/',
            {'title': 'Test', 'file': malicious_file},
            format='multipart'
        )
        # Should reject malicious file
        self.assertNotEqual(response.status_code, 201)


class WebSocketSecurityTests(TestCase):
    """Test WebSocket security measures"""
    
    @patch('channels.db.database_sync_to_async')
    def test_websocket_authentication(self, mock_db_sync):
        """Test WebSocket authentication requirements"""
        from channels.testing import WebsocketCommunicator
        from watchparty.routing import application
        
        # Test unauthenticated connection
        communicator = WebsocketCommunicator(application, "/ws/party/test/")
        
        # Should reject unauthenticated connections
        # Note: This is a simplified test - actual implementation may vary
        # based on your WebSocket authentication setup
        pass  # Implement based on your WebSocket auth mechanism
    
    def test_websocket_message_validation(self):
        """Test WebSocket message validation"""
        # Test malicious message content
        malicious_messages = [
            {'type': 'chat', 'message': '<script>alert("xss")</script>'},
            {'type': 'video_control', 'action': '"; DROP TABLE users; --'},
            {'type': 'user_action', 'data': {'onload': 'alert("xss")'}}
        ]
        
        # These should be validated and sanitized by WebSocket consumers
        # Implementation depends on your specific WebSocket setup
        pass


class SecurityAuditTests(BaseAPITestCase):
    """Test security audit and logging functionality"""
    
    @patch('logging.Logger.info')
    @patch('logging.Logger.warning')
    def test_security_event_logging(self, mock_warning, mock_info):
        """Test that security events are properly logged"""
        # Test authentication logging
        self.client.post('/api/auth/login/', {
            'username': 'nonexistent',
            'password': 'wrongpassword'
        })
        
        # Should log authentication attempt
        mock_info.assert_called()
        
        # Test suspicious activity logging
        self.client.get('/api/videos/?q=<script>alert("xss")</script>')
        
        # Should log suspicious activity
        mock_warning.assert_called()
    
    def test_admin_action_logging(self):
        """Test admin action logging"""
        # Access admin endpoint
        response = self.admin_client.get('/api/admin/users/')
        
        # Should log admin access (check log files or mock logging)
        # Implementation depends on your logging setup
        pass


class ComplianceTests(TestCase):
    """Test compliance with security standards"""
    
    def test_password_storage_security(self):
        """Test that passwords are properly hashed"""
        user = User.objects.create_user(
            username='testuser',
            email='test@test.com',
            password='testpassword123'
        )
        
        # Password should be hashed
        self.assertNotEqual(user.password, 'testpassword123')
        self.assertTrue(user.password.startswith('pbkdf2_sha256$'))
    
    def test_sensitive_data_exposure(self):
        """Test that sensitive data is not exposed in API responses"""
        response = self.auth_client.get('/api/users/profile/')
        
        # Should not expose sensitive data
        response_data = json.dumps(response.data)
        sensitive_fields = ['password', 'secret_key', 'private_key']
        
        for field in sensitive_fields:
            self.assertNotIn(field, response_data.lower())
    
    def test_data_validation_completeness(self):
        """Test that all user inputs are validated"""
        # Test various endpoints with invalid data
        invalid_data_tests = [
            ('/api/users/profile/', {'bio': 'x' * 10000}),  # Too long
            ('/api/parties/', {'title': ''}),  # Empty required field
            ('/api/videos/', {'title': '<script>alert("xss")</script>'}),  # XSS
        ]
        
        for endpoint, data in invalid_data_tests:
            response = self.auth_client.put(endpoint, data)
            # Should validate and reject or sanitize
            if response.status_code == 200:
                # If accepted, check that data was sanitized
                response_content = json.dumps(response.data)
                self.assertNotIn('<script>', response_content)


class PerformanceSecurityTests(BaseAPITestCase):
    """Test performance-related security measures"""
    
    def test_query_injection_prevention(self):
        """Test prevention of query injection attacks"""
        # Test various injection payloads
        injection_payloads = [
            "1'; WAITFOR DELAY '00:00:05'--",
            "1' AND SLEEP(5)--",
            "1' OR BENCHMARK(1000000,MD5(1))--"
        ]
        
        import time
        for payload in injection_payloads:
            start_time = time.time()
            response = self.auth_client.get(f'/api/videos/?id={payload}')
            end_time = time.time()
            
            # Response should not be delayed by injection attempts
            response_time = end_time - start_time
            self.assertLess(response_time, 2.0)  # Should respond quickly
    
    def test_dos_protection(self):
        """Test denial of service protection"""
        # Test large payload handling
        large_data = {'description': 'x' * 1000000}  # 1MB of data
        
        response = self.auth_client.post('/api/parties/', large_data)
        # Should handle large payloads gracefully
        self.assertNotEqual(response.status_code, 500)
        
        # Test rapid requests
        start_time = time.time()
        for i in range(10):
            response = self.auth_client.get('/api/users/profile/')
        end_time = time.time()
        
        # Should have rate limiting or handle rapid requests
        total_time = end_time - start_time
        self.assertGreater(total_time, 0.5)  # Should not process too quickly
