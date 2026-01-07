#!/usr/bin/env python3
"""
Health Probe Script
Performs HTTP/HTTPS health checks on endpoints and reports status.
Used for monitoring web applications, APIs, and load balancer health probes.
"""

import requests
import json
import sys
import argparse
from datetime import datetime
from typing import Dict, List
import urllib3

# Suppress SSL warnings for self-signed certificates (use with caution)
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class HealthProbe:
    """Performs health checks on HTTP/HTTPS endpoints."""
    
    def __init__(self, timeout: int = 10, verify_ssl: bool = True):
        """
        Initialize health probe.
        
        Args:
            timeout: Request timeout in seconds
            verify_ssl: Whether to verify SSL certificates
        """
        self.timeout = timeout
        self.verify_ssl = verify_ssl
        self.results = []
    
    def check_endpoint(self, url: str, expected_status: int = 200) -> Dict:
        """
        Check a single endpoint.
        
        Args:
            url: The URL to check
            expected_status: Expected HTTP status code
            
        Returns:
            Dictionary containing check results
        """
        result = {
            'url': url,
            'timestamp': datetime.utcnow().isoformat(),
            'healthy': False,
            'status_code': None,
            'response_time_ms': None,
            'error': None
        }
        
        try:
            start_time = datetime.now()
            response = requests.get(
                url,
                timeout=self.timeout,
                verify=self.verify_ssl,
                allow_redirects=True
            )
            end_time = datetime.now()
            
            response_time = (end_time - start_time).total_seconds() * 1000
            
            result['status_code'] = response.status_code
            result['response_time_ms'] = round(response_time, 2)
            result['healthy'] = (response.status_code == expected_status)
            
            if not result['healthy']:
                result['error'] = f"Expected status {expected_status}, got {response.status_code}"
                
        except requests.exceptions.Timeout:
            result['error'] = f"Request timeout after {self.timeout} seconds"
        except requests.exceptions.SSLError as e:
            result['error'] = f"SSL Error: {str(e)}"
        except requests.exceptions.ConnectionError as e:
            result['error'] = f"Connection Error: {str(e)}"
        except Exception as e:
            result['error'] = f"Unexpected error: {str(e)}"
        
        self.results.append(result)
        return result
    
    def check_multiple(self, endpoints: List[Dict]) -> List[Dict]:
        """
        Check multiple endpoints.
        
        Args:
            endpoints: List of endpoint dictionaries with 'url' and optional 'expected_status'
            
        Returns:
            List of check results
        """
        results = []
        for endpoint in endpoints:
            url = endpoint.get('url')
            expected_status = endpoint.get('expected_status', 200)
            result = self.check_endpoint(url, expected_status)
            results.append(result)
        
        return results
    
    def print_summary(self):
        """Print a summary of all health checks."""
        total = len(self.results)
        healthy = sum(1 for r in self.results if r['healthy'])
        unhealthy = total - healthy
        
        print("\n" + "="*60)
        print("HEALTH CHECK SUMMARY")
        print("="*60)
        print(f"Total Endpoints: {total}")
        print(f"Healthy: {healthy}")
        print(f"Unhealthy: {unhealthy}")
        print(f"Success Rate: {(healthy/total*100):.1f}%" if total > 0 else "N/A")
        print("="*60 + "\n")
        
        for result in self.results:
            status = "✓ HEALTHY" if result['healthy'] else "✗ UNHEALTHY"
            print(f"{status} - {result['url']}")
            print(f"  Status Code: {result['status_code']}")
            print(f"  Response Time: {result['response_time_ms']}ms" if result['response_time_ms'] else "  Response Time: N/A")
            if result['error']:
                print(f"  Error: {result['error']}")
            print()


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description='HTTP/HTTPS Health Probe')
    parser.add_argument('--url', type=str, help='Single URL to check')
    parser.add_argument('--config', type=str, help='JSON config file with multiple endpoints')
    parser.add_argument('--timeout', type=int, default=10, help='Request timeout in seconds')
    parser.add_argument('--no-verify-ssl', action='store_true', help='Disable SSL verification')
    parser.add_argument('--output', type=str, help='Output file for JSON results')
    
    args = parser.parse_args()
    
    # Initialize health probe
    probe = HealthProbe(
        timeout=args.timeout,
        verify_ssl=not args.no_verify_ssl
    )
    
    # Check endpoints
    if args.url:
        # Single URL check
        probe.check_endpoint(args.url)
    elif args.config:
        # Multiple endpoints from config file
        try:
            with open(args.config, 'r') as f:
                config = json.load(f)
                endpoints = config.get('endpoints', [])
                probe.check_multiple(endpoints)
        except FileNotFoundError:
            print(f"Error: Config file '{args.config}' not found")
            sys.exit(1)
        except json.JSONDecodeError:
            print(f"Error: Invalid JSON in config file '{args.config}'")
            sys.exit(1)
    else:
        print("Error: Must specify either --url or --config")
        parser.print_help()
        sys.exit(1)
    
    # Print summary
    probe.print_summary()
    
    # Save results to file if specified
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(probe.results, f, indent=2)
        print(f"Results saved to: {args.output}")
    
    # Exit with error code if any checks failed
    if any(not r['healthy'] for r in probe.results):
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == '__main__':
    main()
