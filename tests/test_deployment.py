#!/usr/bin/env python3
"""
Automated Deployment & Smoke Test Suite for docker-cicd-pipeline
Uses Python Standard Library exclusively (zero third-party dependencies).

Validates:
1. Container availability and readiness probe (/healthz)
2. HTTP 200 OK on primary landing page (/)
3. Expected HTML DOM content and security tokens
4. JSON payload integrity on healthcheck endpoint
5. Nginx security headers compliance
6. Static assets serving (CSS/JS MIME types)
7. 404 error page routing and response code
"""

import sys
import time
import json
import argparse
import unittest
import urllib.request
import urllib.error


class TestDeployment(unittest.TestCase):
    base_url = "http://127.0.0.1:8080"
    timeout = 10.0

    @classmethod
    def setUpClass(cls):
        """Wait for the container web server to become reachable before assertions."""
        print(f"\n[INIT] Target base URL: {cls.base_url}")
        print(f"[INIT] Polling endpoint for container readiness...")

        health_url = f"{cls.base_url.rstrip('/')}/healthz"
        max_attempts = 15
        delay = 2

        for attempt in range(1, max_attempts + 1):
            try:
                req = urllib.request.Request(
                    health_url,
                    headers={"User-Agent": "DeploymentSmokeTest/1.0"}
                )
                with urllib.request.urlopen(req, timeout=3.0) as response:
                    if response.status == 200:
                        print(f"[INIT] Container is ready (attempt {attempt}/{max_attempts})")
                        return
            except Exception as err:
                time.sleep(delay)

        raise RuntimeError(f"Container failed to respond at {health_url} after {max_attempts * delay}s")

    def test_01_homepage_status_code(self):
        """Verify homepage returns HTTP 200 OK with text/html content type."""
        url = f"{self.base_url}/"
        req = urllib.request.Request(url, headers={"User-Agent": "CI-SmokeTest"})
        with urllib.request.urlopen(req, timeout=self.timeout) as response:
            self.assertEqual(response.status, 200, f"Expected 200 OK, got {response.status}")
            content_type = response.headers.get("Content-Type", "")
            self.assertIn("text/html", content_type, f"Expected text/html, got {content_type}")

    def test_02_homepage_content_assertions(self):
        """Verify homepage contains expected brand, title, and architecture sections."""
        url = f"{self.base_url}/"
        req = urllib.request.Request(url, headers={"User-Agent": "CI-SmokeTest"})
        with urllib.request.urlopen(req, timeout=self.timeout) as response:
            html = response.read().decode("utf-8")
            required_phrases = [
                "docker-cicd-pipeline",
                "Automated Docker CI/CD Pipeline",
                "Deployment Status",
                "Technology Stack",
                "GitHub Actions",
                "Continuous Integration (CI)",
                "Continuous Delivery (CD)"
            ]
            for phrase in required_phrases:
                self.assertIn(phrase, html, f"Missing required text in homepage: '{phrase}'")

    def test_03_health_endpoint_contract(self):
        """Verify /healthz returns status 200 and valid JSON schema with status=healthy."""
        url = f"{self.base_url}/healthz"
        req = urllib.request.Request(url, headers={"User-Agent": "CI-SmokeTest"})
        with urllib.request.urlopen(req, timeout=self.timeout) as response:
            self.assertEqual(response.status, 200)
            content_type = response.headers.get("Content-Type", "")
            self.assertIn("application/json", content_type)
            
            payload = json.loads(response.read().decode("utf-8"))
            self.assertIn("status", payload)
            self.assertEqual(payload["status"], "healthy")
            self.assertEqual(payload.get("service"), "docker-cicd-pipeline")
            self.assertIn("timestamp", payload)

    def test_04_security_headers(self):
        """Verify Nginx HTTP response headers adhere to security best practices."""
        url = f"{self.base_url}/"
        req = urllib.request.Request(url, headers={"User-Agent": "CI-SmokeTest"})
        with urllib.request.urlopen(req, timeout=self.timeout) as response:
            headers = response.headers
            self.assertEqual(headers.get("X-Content-Type-Options"), "nosniff")
            self.assertEqual(headers.get("X-Frame-Options"), "SAMEORIGIN")
            self.assertIn("default-src 'self'", headers.get("Content-Security-Policy", ""))
            self.assertEqual(headers.get("Referrer-Policy"), "strict-origin-when-cross-origin")
            
            # Ensure Server tokens are suppressed (does not reveal exact nginx version)
            server_header = headers.get("Server", "")
            self.assertNotIn("1.27", server_header, "Nginx version token leaked in Server header")

    def test_05_static_assets_serving(self):
        """Verify static CSS and JS are served properly with correct MIME types."""
        assets = [
            ("/assets/style.css", "text/css"),
            ("/assets/app.js", "application/javascript"),
        ]
        for path, expected_mime in assets:
            url = f"{self.base_url}{path}"
            req = urllib.request.Request(url, headers={"User-Agent": "CI-SmokeTest"})
            with urllib.request.urlopen(req, timeout=self.timeout) as response:
                self.assertEqual(response.status, 200, f"Asset {path} returned {response.status}")
                self.assertIn(expected_mime, response.headers.get("Content-Type", ""))

    def test_06_custom_404_error_page(self):
        """Verify requesting a non-existent URL returns 404 with custom error page."""
        url = f"{self.base_url}/route-that-does-not-exist-404"
        req = urllib.request.Request(url, headers={"User-Agent": "CI-SmokeTest"})
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as response:
                self.fail(f"Expected HTTP 404, but received status {response.status}")
        except urllib.error.HTTPError as err:
            self.assertEqual(err.code, 404, f"Expected 404, got {err.code}")
            body = err.read().decode("utf-8")
            self.assertIn("Resource Not Found", body)


def main():
    parser = argparse.ArgumentParser(description="Docker CI/CD Smoke & Deployment Test Runner")
    parser.add_argument("--url", default="http://127.0.0.1:8080", help="Base URL of target container")
    parser.add_argument("--timeout", type=float, default=10.0, help="HTTP request timeout in seconds")
    args, unknown = parser.parse_known_args()

    TestDeployment.base_url = args.url.rstrip("/")
    TestDeployment.timeout = args.timeout

    suite = unittest.TestLoader().loadTestsFromTestCase(TestDeployment)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    sys.exit(0 if result.wasSuccessful() else 1)


if __name__ == "__main__":
    main()
