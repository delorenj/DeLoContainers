import requests
import json
from datetime import datetime, timezone

# Graphiti API endpoint
api_url = "http://localhost:8000/api/v1"

# Create a test episode
episode_data = {
    "name": "test-episode-1",
    "episode_body": "This is a test message from Jarad to test Graphiti integration with Neo4j.",
    "source": "message",
    "reference_time": datetime.now(timezone.utc).isoformat(),
    "source_description": "Test conversation"
}

# Send POST request to create episode
response = requests.post(f"{api_url}/episodes", json=episode_data)
print(f"Status Code: {response.status_code}")
print(f"Response: {response.json() if response.status_code == 200 else response.text}")
