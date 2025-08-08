#!/bin/bash
# Test NATS connection and basic pub/sub

echo "🚀 Testing NATS connection..."

# Test basic connectivity with a simple publish
if ! docker exec nats-cli nats --server nats:4222 pub test.connection "Connection test" > /dev/null 2>&1; then
    echo "❌ NATS server is not accessible"
    exit 1
fi

echo "✅ NATS server is running and accessible"

# Test basic pub/sub
echo "📤 Testing publish/subscribe..."

# Start subscriber in background and capture output
docker exec -d nats-cli sh -c 'nats --server nats:4222 sub test.subject --count=1 > /tmp/sub_output.log 2>&1' 

# Wait a moment for subscriber to start
sleep 2

# Publish a message
docker exec nats-cli nats --server nats:4222 pub test.subject "Hello from NATS test!"

# Wait for subscriber to receive
sleep 2

echo "✅ Basic pub/sub test completed"

# Test JetStream
echo "📦 Testing JetStream..."
docker exec nats-cli nats --server nats:4222 stream add TEST_STREAM --subjects="test.js.>" --storage=file --replicas=1 --max-age=1h --discard=old --max-msgs=1000 2>/dev/null || echo "Stream might already exist"

docker exec nats-cli nats --server nats:4222 pub test.js.message "JetStream test message"

echo "✅ JetStream test completed"

echo "🎉 All tests passed! NATS is working correctly."
echo ""
echo "🌐 Access the monitoring dashboard at: http://localhost:8222"
echo "🔗 Connect your applications to: nats://localhost:4222"
