#!/bin/bash

# Concierge Service Integration Test
# Tests all endpoints and functionality

set -e

BASE_URL="https://concierge.delo.sh"
API_KEY="concierge-api-key-secure-token-2025"

echo "🏨 Testing Concierge Service"
echo "================================"

# Test 1: Health Check
echo "1. Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s "$BASE_URL/health")
echo "✅ Health check: $HEALTH_RESPONSE"

# Test 2: Public Hello
echo -e "\n2. Testing public hello endpoint..."
PUBLIC_HELLO=$(curl -s "$BASE_URL/hello")
echo "✅ Public hello: $PUBLIC_HELLO"

# Test 3: Authenticated Hello
echo -e "\n3. Testing authenticated hello endpoint..."
AUTH_HELLO=$(curl -s -H "X-API-Token: $API_KEY" "$BASE_URL/hello")
echo "✅ Authenticated hello: $AUTH_HELLO"

# Test 4: LLM Request
echo -e "\n4. Testing LLM endpoint..."
LLM_RESPONSE=$(curl -s -X POST "$BASE_URL/llm" \
  -H "Content-Type: application/json" \
  -H "X-API-Token: $API_KEY" \
  -d '{
    "messages": [{"role": "user", "content": "Say hello in exactly 3 words."}],
    "model": "anthropic/claude-3.5-sonnet",
    "max_tokens": 10
  }')
echo "✅ LLM response: $LLM_RESPONSE"

# Test 5: Unauthorized Access
echo -e "\n5. Testing unauthorized access..."
UNAUTH_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null -X POST "$BASE_URL/llm" \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "test"}]}')
if [ "$UNAUTH_RESPONSE" = "401" ]; then
  echo "✅ Unauthorized access properly blocked (401)"
else
  echo "❌ Unauthorized access not blocked (got $UNAUTH_RESPONSE)"
fi

# Test 6: Invalid Endpoint
echo -e "\n6. Testing invalid endpoint..."
INVALID_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null "$BASE_URL/invalid")
if [ "$INVALID_RESPONSE" = "404" ]; then
  echo "✅ Invalid endpoint returns 404"
else
  echo "❌ Invalid endpoint should return 404 (got $INVALID_RESPONSE)"
fi

echo -e "\n🎉 All tests completed!"
echo "================================"
echo "Service is running at: $BASE_URL"
echo "Test client available at: test-client.html"
echo "API Key: $API_KEY"
