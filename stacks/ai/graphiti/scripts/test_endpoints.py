#!/usr/bin/env python3

import requests
import json
import time
from datetime import datetime, timezone

# Graphiti API endpoint
api_url = "http://localhost:8000"

def test_endpoint(url, method="GET", data=None, description=""):
    """Test an endpoint and print the results."""
    print(f"\n----- Testing {description} -----")
    print(f"{method} {url}")
    
    try:
        if method == "GET":
            response = requests.get(url, timeout=10)
        elif method == "POST":
            response = requests.post(url, json=data, timeout=10)
        else:
            print(f"Method {method} not supported")
            return
        
        print(f"Status Code: {response.status_code}")
        
        try:
            print(f"Response: {json.dumps(response.json(), indent=2)}")
        except:
            print(f"Response (text): {response.text[:300]}")
            
    except requests.exceptions.Timeout:
        print("Request timed out after 10 seconds")
    except requests.exceptions.ConnectionError:
        print("Connection error occurred")
    except Exception as e:
        print(f"Error: {str(e)}")

# Test root endpoint
test_endpoint(f"{api_url}/", description="Root endpoint")

# Test docs endpoint (FastAPI often has /docs)
test_endpoint(f"{api_url}/docs", description="API documentation")

# Test openapi.json (FastAPI schema)
test_endpoint(f"{api_url}/openapi.json", description="OpenAPI schema")

# Check correct health endpoint (/healthcheck - not /health)
test_endpoint(f"{api_url}/healthcheck", description="Healthcheck endpoint")

# API Endpoints based on Graphiti documentation
test_endpoint(f"{api_url}/api/v1/episodes", description="Episodes API")

# Try to create an episode
episode_data = {
    "name": "test-episode-1",
    "episode_body": "This is a test message from Jarad to test Graphiti integration with Neo4j.",
    "source": "message",
    "reference_time": datetime.now(timezone.utc).isoformat(),
    "source_description": "Test conversation"
}

# Send POST request to create episode (to the documented endpoint)
test_endpoint(f"{api_url}/api/v1/episodes", method="POST", data=episode_data, description="Create episode (v1 API)")

# Try alternative endpoint paths
test_endpoint(f"{api_url}/episodes", method="POST", data=episode_data, description="Create episode (root path)")

# Try searching
test_endpoint(f"{api_url}/api/v1/search?q=test", description="Search endpoint (v1 API)")
test_endpoint(f"{api_url}/search?q=test", description="Search endpoint (root path)")

print("\nDone testing endpoints.")
