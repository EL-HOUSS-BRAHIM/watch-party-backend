#!/usr/bin/env python3
"""
Comprehensive test runner for Watch Party Backend
"""

import os
import sys
import subprocess
import time
import json
from pathlib import Path
import argparse
import coverage
import pytest

# Set up Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'watchparty.settings.base')

import django
from django.core.management import execute_from_command_line
from django.test.utils import get_runner
from django.conf import settings

# Initialize Django
django.setup()


class TestRunner:
    """Enhanced test runner with comprehensive reporting"""
    
    def __init__(self):
        self.project_dir = Path(__file__).parent
        self.coverage = coverage.Coverage()
        self.test_results = {
            'total_tests': 0,
            'passed': 0,
            'failed': 0,
            'skipped': 0,
            'errors': [],
            'coverage_percentage': 0,
            'execution_time': 0
        }
    
    def run_security_tests(self, verbose=False):
        """Run security-focused tests"""
        print("🔐 Running Security Tests...")
        
        test_modules = [
            'tests.test_security.InputSanitizationTests',
            'tests.test_security.InputValidationTests',
            'tests.test_security.FileSecurityTests',
            'tests.test_security.AuthenticationSecurityTests',
            'tests.test_security.APISecurityTests',
            'tests.test_security.SecurityMiddlewareTests',
            'tests.test_security.ComplianceTests',
        ]
        
        return self._run_test_modules(test_modules, verbose)
    
    def run_performance_tests(self, verbose=False):
        """Run performance tests"""
        print("⚡ Running Performance Tests...")
        
        test_modules = [
            'tests.test_performance.APIPerformanceTests',
            'tests.test_performance.DatabasePerformanceTests',
            'tests.test_performance.CachePerformanceTests',
            'tests.test_performance.WebSocketPerformanceTests',
        ]
        
        return self._run_test_modules(test_modules, verbose)
    
    def run_integration_tests(self, verbose=False):
        """Run integration tests"""
        print("🔗 Running Integration Tests...")
        
        test_modules = [
            'tests.test_performance.IntegrationTests',
            'tests.test_performance.StressTests',
            'tests.test_performance.LoadTestCase',
        ]
        
        return self._run_test_modules(test_modules, verbose)
    
    def run_api_tests(self, verbose=False):
        """Run API endpoint tests"""
        print("🌐 Running API Tests...")
        
        # Discover all API test files
        api_test_files = [
            'tests.test_api',
            'tests.test_authentication',
            'tests.test_integration',
        ]
        
        return self._run_test_modules(api_test_files, verbose)
    
    def run_websocket_tests(self, verbose=False):
        """Run WebSocket tests"""
        print("🔌 Running WebSocket Tests...")
        
        test_modules = [
            'tests.test_performance.WebSocketPerformanceTests',
            # Add more WebSocket test modules as they're created
        ]
        
        return self._run_test_modules(test_modules, verbose)
    
    def run_all_tests(self, verbose=False, with_coverage=True):
        """Run all tests with coverage"""
        print("🧪 Running All Tests...")
        
        start_time = time.time()
        
        if with_coverage:
            self.coverage.start()
        
        try:
            # Run different test suites
            results = []
            results.append(self.run_security_tests(verbose))
            results.append(self.run_performance_tests(verbose))
            results.append(self.run_integration_tests(verbose))
            results.append(self.run_api_tests(verbose))
            results.append(self.run_websocket_tests(verbose))
            
            # Aggregate results
            for result in results:
                if result:
                    self.test_results['total_tests'] += result.get('total_tests', 0)
                    self.test_results['passed'] += result.get('passed', 0)
                    self.test_results['failed'] += result.get('failed', 0)
                    self.test_results['skipped'] += result.get('skipped', 0)
                    self.test_results['errors'].extend(result.get('errors', []))
            
            if with_coverage:
                self.coverage.stop()
                self.coverage.save()
                
                # Generate coverage report
                coverage_percentage = self._generate_coverage_report()
                self.test_results['coverage_percentage'] = coverage_percentage
            
            self.test_results['execution_time'] = time.time() - start_time
            
            # Generate comprehensive report
            self._generate_test_report()
            
            return self.test_results
            
        except Exception as e:
            print(f"❌ Test execution failed: {e}")
            return None
    
    def _run_test_modules(self, test_modules, verbose=False):
        """Run specific test modules"""
        results = {
            'total_tests': 0,
            'passed': 0,
            'failed': 0,
            'skipped': 0,
            'errors': []
        }
        
        for module in test_modules:
            try:
                # Run Django tests
                cmd = [
                    'python', 'manage.py', 'test', module,
                    '--verbosity=2' if verbose else '--verbosity=1',
                    '--keepdb',
                    '--parallel'
                ]
                
                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    cwd=self.project_dir
                )
                
                # Parse test results (simplified parsing)
                if result.returncode == 0:
                    results['passed'] += 1
                else:
                    results['failed'] += 1
                    results['errors'].append({
                        'module': module,
                        'error': result.stderr
                    })
                
                results['total_tests'] += 1
                
            except Exception as e:
                results['errors'].append({
                    'module': module,
                    'error': str(e)
                })
                results['failed'] += 1
                results['total_tests'] += 1
        
        return results
    
    def _generate_coverage_report(self):
        """Generate coverage report"""
        try:
            # Generate HTML coverage report
            self.coverage.html_report(directory='htmlcov')
            
            # Generate console report
            coverage_percentage = self.coverage.report()
            
            # Generate JSON report for CI/CD
            self.coverage.json_report(outfile='coverage.json')
            
            return coverage_percentage
            
        except Exception as e:
            print(f"❌ Coverage report generation failed: {e}")
            return 0
    
    def _generate_test_report(self):
        """Generate comprehensive test report"""
        report = {
            'timestamp': time.time(),
            'results': self.test_results,
            'environment': {
                'python_version': sys.version,
                'django_version': getattr(settings, 'DJANGO_VERSION', 'Unknown'),
                'database': getattr(settings, 'DATABASES', {}).get('default', {}).get('ENGINE', 'Unknown')
            }
        }
        
        # Save JSON report
        with open('test_report.json', 'w') as f:
            json.dump(report, f, indent=2)
        
        # Print summary
        self._print_test_summary()
    
    def _print_test_summary(self):
        """Print test execution summary"""
        print("\n" + "="*60)
        print("🧪 TEST EXECUTION SUMMARY")
        print("="*60)
        
        results = self.test_results
        
        print(f"Total Tests: {results['total_tests']}")
        print(f"✅ Passed: {results['passed']}")
        print(f"❌ Failed: {results['failed']}")
        print(f"⏭️  Skipped: {results['skipped']}")
        print(f"📊 Coverage: {results['coverage_percentage']:.1f}%")
        print(f"⏱️  Execution Time: {results['execution_time']:.2f}s")
        
        if results['errors']:
            print("\n❌ ERRORS:")
            for error in results['errors']:
                print(f"  - {error['module']}: {error['error'][:100]}...")
        
        # Success/failure indication
        success_rate = (results['passed'] / results['total_tests'] * 100) if results['total_tests'] > 0 else 0
        
        if success_rate >= 90 and results['coverage_percentage'] >= 80:
            print("\n🎉 ALL TESTS PASSED WITH GOOD COVERAGE!")
        elif success_rate >= 80:
            print("\n✅ Most tests passed, but consider improving coverage")
        else:
            print("\n❌ TESTS FAILED - Please review and fix issues")
        
        print("="*60)


def benchmark_api_endpoints():
    """Benchmark critical API endpoints"""
    print("📊 Running API Benchmarks...")
    
    from tests.test_base import PerformanceBenchmark
    from rest_framework.test import APIClient
    
    client = APIClient()
    
    # List of endpoints to benchmark
    endpoints = [
        '/api/videos/',
        '/api/parties/',
        '/api/users/profile/',
        '/api/search/',
        '/api/auth/login/',
    ]
    
    benchmark_results = {}
    
    for endpoint in endpoints:
        try:
            if endpoint == '/api/auth/login/':
                # Special case for login endpoint
                result = PerformanceBenchmark.benchmark_endpoint(
                    client, endpoint, method='POST',
                    data={'username': 'test', 'password': 'test'},
                    iterations=10
                )
            else:
                result = PerformanceBenchmark.benchmark_endpoint(
                    client, endpoint, iterations=50
                )
            
            benchmark_results[endpoint] = result
            print(f"  {endpoint}: {result['mean']:.3f}s avg, {result['max']:.3f}s max")
            
        except Exception as e:
            print(f"  ❌ {endpoint}: Benchmark failed - {e}")
    
    # Save benchmark results
    with open('benchmark_results.json', 'w') as f:
        json.dump(benchmark_results, f, indent=2)
    
    return benchmark_results


def validate_security_configuration():
    """Validate security configuration"""
    print("🔐 Validating Security Configuration...")
    
    security_checks = {
        'DEBUG': settings.DEBUG == False,
        'SECRET_KEY': len(settings.SECRET_KEY) >= 50,
        'ALLOWED_HOSTS': len(settings.ALLOWED_HOSTS) > 0 and 'localhost' not in str(settings.ALLOWED_HOSTS),
        'SECURE_SSL_REDIRECT': getattr(settings, 'SECURE_SSL_REDIRECT', False),
        'SECURE_HSTS_SECONDS': getattr(settings, 'SECURE_HSTS_SECONDS', 0) > 0,
        'SESSION_COOKIE_SECURE': getattr(settings, 'SESSION_COOKIE_SECURE', False),
        'CSRF_COOKIE_SECURE': getattr(settings, 'CSRF_COOKIE_SECURE', False),
    }
    
    passed_checks = sum(security_checks.values())
    total_checks = len(security_checks)
    
    print(f"Security Configuration: {passed_checks}/{total_checks} checks passed")
    
    for check, status in security_checks.items():
        status_icon = "✅" if status else "❌"
        print(f"  {status_icon} {check}")
    
    if passed_checks < total_checks:
        print("⚠️  Consider reviewing security settings for production")
    
    return security_checks


def main():
    """Main test runner entry point"""
    parser = argparse.ArgumentParser(description='Watch Party Backend Test Runner')
    parser.add_argument('--security', action='store_true', help='Run security tests only')
    parser.add_argument('--performance', action='store_true', help='Run performance tests only')
    parser.add_argument('--integration', action='store_true', help='Run integration tests only')
    parser.add_argument('--api', action='store_true', help='Run API tests only')
    parser.add_argument('--websocket', action='store_true', help='Run WebSocket tests only')
    parser.add_argument('--benchmark', action='store_true', help='Run API benchmarks')
    parser.add_argument('--security-check', action='store_true', help='Validate security configuration')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    parser.add_argument('--no-coverage', action='store_true', help='Skip coverage analysis')
    
    args = parser.parse_args()
    
    runner = TestRunner()
    
    # Set up Django environment
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'watchparty.settings.base')
    
    if args.security_check:
        validate_security_configuration()
        return
    
    if args.benchmark:
        benchmark_api_endpoints()
        return
    
    # Run specific test suites
    if args.security:
        runner.run_security_tests(args.verbose)
    elif args.performance:
        runner.run_performance_tests(args.verbose)
    elif args.integration:
        runner.run_integration_tests(args.verbose)
    elif args.api:
        runner.run_api_tests(args.verbose)
    elif args.websocket:
        runner.run_websocket_tests(args.verbose)
    else:
        # Run all tests
        runner.run_all_tests(args.verbose, not args.no_coverage)


if __name__ == '__main__':
    main()
