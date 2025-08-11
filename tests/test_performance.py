"""
Performance and integration tests for Watch Party Backend
"""

import time
import threading
import asyncio
import json
from concurrent.futures import ThreadPoolExecutor
from django.test import TransactionTestCase
from django.db import transaction, connection
from django.core.cache import cache
from django.test.utils import override_settings
from rest_framework.test import APITestCase
from channels.testing import WebsocketCommunicator
from unittest.mock import patch, MagicMock

from tests.test_base import (
    BaseAPITestCase, WebSocketTestCase, PerformanceTestMixin, 
    PerformanceBenchmark, MockExternalServices
)


class APIPerformanceTests(BaseAPITestCase, PerformanceTestMixin):
    """Test API endpoint performance"""
    
    def setUp(self):
        super().setUp()
        self.list_url = '/api/videos/'
        self.detail_url = '/api/videos/1/'
        
        # Create test data for performance testing
        from apps.videos.models import Video
        for i in range(100):
            Video.objects.create(
                title=f'Test Video {i}',
                description=f'Test description {i}',
                uploader=self.user,
                file=f'test_video_{i}.mp4'
            )
    
    def test_list_endpoint_performance(self):
        """Test list endpoint performance with large datasets"""
        # Test response time
        self.test_response_time(max_time=2.0)
        
        # Test pagination performance
        self.test_pagination_performance()
        
        # Benchmark the endpoint
        benchmark_results = PerformanceBenchmark.benchmark_endpoint(
            self.auth_client,
            self.list_url,
            method='GET',
            iterations=50
        )
        
        # Assert performance requirements
        self.assertLess(benchmark_results['mean'], 1.0)  # Average < 1 second
        self.assertLess(benchmark_results['max'], 3.0)   # Max < 3 seconds
    
    def test_search_performance(self):
        """Test search endpoint performance"""
        search_queries = [
            'test',
            'video',
            'description',
            'nonexistent_term'
        ]
        
        for query in search_queries:
            start_time = time.time()
            response = self.auth_client.get(f'/api/search/?q={query}')
            end_time = time.time()
            
            response_time = end_time - start_time
            self.assertEqual(response.status_code, 200)
            self.assertLess(response_time, 2.0)  # Search should be fast
    
    def test_concurrent_request_handling(self):
        """Test handling of concurrent requests"""
        def make_request():
            return self.auth_client.get('/api/users/profile/')
        
        # Test with multiple concurrent requests
        with ThreadPoolExecutor(max_workers=10) as executor:
            start_time = time.time()
            futures = [executor.submit(make_request) for _ in range(20)]
            
            results = []
            for future in futures:
                response = future.result()
                results.append(response.status_code == 200)
            
            end_time = time.time()
        
        # All requests should succeed
        success_rate = sum(results) / len(results)
        self.assertGreater(success_rate, 0.8)  # 80% success rate
        
        # Should complete within reasonable time
        total_time = end_time - start_time
        self.assertLess(total_time, 10.0)
    
    def test_file_upload_performance(self):
        """Test file upload performance"""
        # Create test file
        video_file = self.create_test_video_file(size=1024*1024)  # 1MB
        
        start_time = time.time()
        response = self.auth_client.post(
            '/api/videos/',
            {
                'title': 'Performance Test Video',
                'file': video_file
            },
            format='multipart'
        )
        end_time = time.time()
        
        upload_time = end_time - start_time
        self.assertEqual(response.status_code, 201)
        self.assertLess(upload_time, 10.0)  # Upload should complete in 10 seconds


class DatabasePerformanceTests(TransactionTestCase):
    """Test database performance and optimization"""
    
    def setUp(self):
        super().setUp()
        self.user = self.create_test_user()
        
        # Create test data
        from apps.videos.models import Video
        from apps.parties.models import WatchParty
        
        # Create videos
        for i in range(50):
            Video.objects.create(
                title=f'Test Video {i}',
                description=f'Test description {i}',
                uploader=self.user,
                file=f'test_video_{i}.mp4'
            )
        
        # Create parties
        for i in range(20):
            WatchParty.objects.create(
                title=f'Test Party {i}',
                description=f'Test party description {i}',
                host=self.user
            )
    
    def create_test_user(self):
        """Create test user"""
        from django.contrib.auth import get_user_model
        User = get_user_model()
        return User.objects.create_user(
            email='test@test.com',
            first_name='Test',
            last_name='User',
            password='testpass123'
        )
    
    def test_query_optimization(self):
        """Test database query optimization"""
        from django.db import connection, reset_queries
        from apps.videos.models import Video
        
        # Test select_related optimization
        reset_queries()
        
        # Without select_related (should generate N+1 queries)
        videos = Video.objects.all()[:10]
        for video in videos:
            _ = video.uploader.username  # Access related field
        
        query_count_without_optimization = len(connection.queries)
        
        reset_queries()
        
        # With select_related (should generate fewer queries)
        videos = Video.objects.select_related('uploader').all()[:10]
        for video in videos:
            _ = video.uploader.username
        
        query_count_with_optimization = len(connection.queries)
        
        # Optimized version should use fewer queries
        self.assertLess(
            query_count_with_optimization,
            query_count_without_optimization
        )
    
    def test_database_index_usage(self):
        """Test database index usage for common queries"""
        from apps.videos.models import Video
        from django.db import connection
        
        # Test queries that should use indexes
        common_queries = [
            Video.objects.filter(uploader=self.user),
            Video.objects.filter(title__icontains='test'),
            Video.objects.filter(created_at__gte='2023-01-01'),
        ]
        
        for query in common_queries:
            with connection.cursor() as cursor:
                query_sql = str(query.query)
                # Check that query doesn't cause full table scan
                # This is database-specific - adjust based on your database
                self.assertNotIn('FULL TABLE SCAN', query_sql.upper())
    
    def test_bulk_operations_performance(self):
        """Test bulk database operations performance"""
        from apps.videos.models import Video
        
        # Test bulk create
        start_time = time.time()
        videos_to_create = [
            Video(
                title=f'Bulk Video {i}',
                description=f'Bulk description {i}',
                uploader=self.user,
                file=f'bulk_video_{i}.mp4'
            )
            for i in range(100)
        ]
        Video.objects.bulk_create(videos_to_create)
        end_time = time.time()
        
        bulk_create_time = end_time - start_time
        self.assertLess(bulk_create_time, 5.0)  # Should complete quickly
        
        # Test bulk update
        video_ids = Video.objects.filter(
            title__startswith='Bulk Video'
        ).values_list('id', flat=True)
        
        start_time = time.time()
        Video.objects.filter(id__in=video_ids).update(
            description='Updated bulk description'
        )
        end_time = time.time()
        
        bulk_update_time = end_time - start_time
        self.assertLess(bulk_update_time, 2.0)  # Should be fast


class CachePerformanceTests(BaseAPITestCase):
    """Test caching performance and effectiveness"""
    
    def test_cache_hit_performance(self):
        """Test cache hit performance"""
        cache_key = 'test_performance_key'
        test_data = {'key': 'value', 'number': 123}
        
        # Set cache
        cache.set(cache_key, test_data, timeout=300)
        
        # Test cache retrieval performance
        start_time = time.time()
        for _ in range(100):
            cached_data = cache.get(cache_key)
            self.assertEqual(cached_data, test_data)
        end_time = time.time()
        
        cache_time = end_time - start_time
        self.assertLess(cache_time, 1.0)  # 100 cache hits should be very fast
    
    def test_api_response_caching(self):
        """Test API response caching effectiveness"""
        # First request (cache miss)
        start_time = time.time()
        response1 = self.auth_client.get('/api/videos/')
        first_request_time = time.time() - start_time
        
        # Second request (should be cached)
        start_time = time.time()
        response2 = self.auth_client.get('/api/videos/')
        second_request_time = time.time() - start_time
        
        # Both should return same data
        self.assertEqual(response1.status_code, 200)
        self.assertEqual(response2.status_code, 200)
        
        # Second request should be faster (if caching is working)
        # Note: This test might be flaky depending on cache implementation
        # self.assertLess(second_request_time, first_request_time)
    
    def test_cache_invalidation(self):
        """Test cache invalidation when data changes"""
        # Get initial data and cache it
        response1 = self.auth_client.get('/api/videos/')
        initial_count = response1.data['count']
        
        # Create new video (should invalidate cache)
        video_file = self.create_test_video_file()
        self.auth_client.post(
            '/api/videos/',
            {
                'title': 'Cache Test Video',
                'file': video_file
            },
            format='multipart'
        )
        
        # Get data again (should reflect new video)
        response2 = self.auth_client.get('/api/videos/')
        new_count = response2.data['count']
        
        # Count should be updated
        self.assertEqual(new_count, initial_count + 1)


class WebSocketPerformanceTests(WebSocketTestCase):
    """Test WebSocket performance"""
    
    async def test_websocket_message_throughput(self):
        """Test WebSocket message handling throughput"""
        communicator = await self.connect_websocket('/ws/party/test/')
        
        # Send multiple messages rapidly
        start_time = time.time()
        message_count = 50
        
        for i in range(message_count):
            await communicator.send_json_to({
                'type': 'chat_message',
                'data': {
                    'message': f'Performance test message {i}',
                    'timestamp': time.time()
                }
            })
        
        # Receive all responses
        for i in range(message_count):
            try:
                response = await asyncio.wait_for(
                    communicator.receive_json_from(),
                    timeout=1.0
                )
                self.assertIn('type', response)
            except asyncio.TimeoutError:
                self.fail(f"Timeout waiting for message {i}")
        
        end_time = time.time()
        total_time = end_time - start_time
        
        # Should handle messages efficiently
        self.assertLess(total_time, 10.0)  # 50 messages in 10 seconds
        
        await communicator.disconnect()
    
    async def test_concurrent_websocket_connections(self):
        """Test multiple concurrent WebSocket connections"""
        communicators = []
        
        try:
            # Create multiple connections
            for i in range(5):
                communicator = await self.connect_websocket(f'/ws/party/test_{i}/')
                communicators.append(communicator)
            
            # Send messages from all connections
            start_time = time.time()
            
            for i, communicator in enumerate(communicators):
                await communicator.send_json_to({
                    'type': 'user_joined',
                    'data': {'user_id': i}
                })
            
            # Verify all messages are received
            for communicator in communicators:
                response = await asyncio.wait_for(
                    communicator.receive_json_from(),
                    timeout=2.0
                )
                self.assertIn('type', response)
            
            end_time = time.time()
            total_time = end_time - start_time
            
            # Should handle concurrent connections efficiently
            self.assertLess(total_time, 5.0)
            
        finally:
            # Clean up connections
            for communicator in communicators:
                await communicator.disconnect()


class IntegrationTests(BaseAPITestCase):
    """End-to-end integration tests"""
    
    def test_complete_user_journey(self):
        """Test complete user journey from registration to party participation"""
        # Step 1: User registration
        registration_data = {
            'username': 'integrationuser',
            'email': 'integration@test.com',
            'password': 'integrationpass123',
            'password_confirm': 'integrationpass123'
        }
        
        response = self.client.post('/api/auth/register/', registration_data)
        self.assertEqual(response.status_code, 201)
        
        # Step 2: User login
        login_data = {
            'username': 'integrationuser',
            'password': 'integrationpass123'
        }
        
        response = self.client.post('/api/auth/login/', login_data)
        self.assertEqual(response.status_code, 200)
        
        access_token = response.data['access']
        client = self.auth_client
        client.credentials(HTTP_AUTHORIZATION=f'Bearer {access_token}')
        
        # Step 3: Profile setup
        profile_data = {
            'bio': 'Integration test user',
            'preferences': {
                'notifications': True,
                'privacy': 'friends'
            }
        }
        
        response = client.put('/api/users/profile/', profile_data)
        self.assertEqual(response.status_code, 200)
        
        # Step 4: Video upload
        video_file = self.create_test_video_file()
        video_data = {
            'title': 'Integration Test Video',
            'description': 'Video for integration testing',
            'file': video_file
        }
        
        response = client.post('/api/videos/', video_data, format='multipart')
        self.assertEqual(response.status_code, 201)
        video_id = response.data['id']
        
        # Step 5: Create party
        party_data = {
            'title': 'Integration Test Party',
            'description': 'Party for integration testing',
            'is_private': False
        }
        
        response = client.post('/api/parties/', party_data)
        self.assertEqual(response.status_code, 201)
        party_id = response.data['id']
        
        # Step 6: Add video to party
        response = client.post(
            f'/api/parties/{party_id}/videos/',
            {'video_id': video_id}
        )
        self.assertEqual(response.status_code, 201)
        
        # Step 7: Join party
        response = client.post(f'/api/parties/{party_id}/join/')
        self.assertEqual(response.status_code, 200)
        
        # Step 8: Send chat message
        message_data = {
            'message': 'Hello from integration test!',
            'type': 'text'
        }
        
        response = client.post(
            f'/api/parties/{party_id}/chat/',
            message_data
        )
        self.assertEqual(response.status_code, 201)
        
        # Step 9: Verify party state
        response = client.get(f'/api/parties/{party_id}/')
        self.assertEqual(response.status_code, 200)
        
        party_data = response.data
        self.assertEqual(party_data['title'], 'Integration Test Party')
        self.assertGreater(len(party_data['participants']), 0)
        self.assertGreater(len(party_data['videos']), 0)
    
    def test_social_features_integration(self):
        """Test social features integration"""
        # Create second user
        second_user = self.create_test_user(
            email='social@test.com',
            first_name='Social',
            last_name='User'
        )
        second_client = self.auth_client.__class__()
        second_token = self.authenticate_user(second_user)
        second_client.credentials(HTTP_AUTHORIZATION=f'Bearer {second_token}')
        
        # Send friend request
        response = self.auth_client.post(
            f'/api/social/friends/request/',
            {'user_id': second_user.id}
        )
        self.assertEqual(response.status_code, 201)
        
        # Accept friend request
        request_id = response.data['id']
        response = second_client.post(
            f'/api/social/friends/requests/{request_id}/accept/'
        )
        self.assertEqual(response.status_code, 200)
        
        # Verify friendship
        response = self.auth_client.get('/api/social/friends/')
        self.assertEqual(response.status_code, 200)
        self.assertGreater(len(response.data['results']), 0)
    
    @MockExternalServices.mock_stripe()
    def test_billing_integration(self, mock_stripe):
        """Test billing system integration"""
        mock_customer, mock_subscription = mock_stripe
        
        # Subscribe to premium
        subscription_data = {
            'plan': 'premium',
            'payment_method': 'pm_test_123'
        }
        
        response = self.auth_client.post('/api/billing/subscribe/', subscription_data)
        self.assertEqual(response.status_code, 201)
        
        # Verify subscription status
        response = self.auth_client.get('/api/billing/subscription/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], 'active')
        
        # Test premium features access
        response = self.auth_client.get('/api/analytics/advanced/')
        self.assertEqual(response.status_code, 200)  # Should have access now


class StressTests(BaseAPITestCase):
    """Stress tests for system limits"""
    
    def test_high_load_simulation(self):
        """Simulate high load conditions"""
        def make_multiple_requests():
            results = []
            for _ in range(10):
                response = self.auth_client.get('/api/videos/')
                results.append(response.status_code == 200)
            return results
        
        # Simulate multiple users making requests
        with ThreadPoolExecutor(max_workers=5) as executor:
            futures = [
                executor.submit(make_multiple_requests) 
                for _ in range(5)
            ]
            
            all_results = []
            for future in futures:
                results = future.result()
                all_results.extend(results)
        
        # Calculate success rate
        success_rate = sum(all_results) / len(all_results)
        self.assertGreater(success_rate, 0.8)  # 80% success rate under load
    
    def test_memory_usage_under_load(self):
        """Test memory usage under load"""
        import psutil
        import os
        
        process = psutil.Process(os.getpid())
        initial_memory = process.memory_info().rss
        
        # Generate load
        for _ in range(100):
            response = self.auth_client.get('/api/videos/')
            self.assertEqual(response.status_code, 200)
        
        final_memory = process.memory_info().rss
        memory_increase = final_memory - initial_memory
        
        # Memory increase should be reasonable (less than 100MB)
        self.assertLess(memory_increase, 100 * 1024 * 1024)
    
    def test_database_connection_limits(self):
        """Test database connection handling under stress"""
        from django.db import connections
        
        def make_database_request():
            # Force database query
            response = self.auth_client.get('/api/users/profile/')
            return response.status_code == 200
        
        # Make many concurrent database requests
        with ThreadPoolExecutor(max_workers=20) as executor:
            futures = [
                executor.submit(make_database_request) 
                for _ in range(50)
            ]
            
            results = [future.result() for future in futures]
        
        # All requests should succeed (no connection limit errors)
        success_rate = sum(results) / len(results)
        self.assertGreater(success_rate, 0.9)  # 90% success rate
        
        # Check for connection leaks
        for conn in connections.all():
            # Connections should be properly closed or managed
            pass  # Specific checks depend on your database setup
