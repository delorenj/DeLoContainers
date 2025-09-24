cat << 'EOF'
#!/usr/bin/env zsh

# Firecrawl Complete Worker Fix
# Updates docker-compose.yaml to run workers properly

set -e

echo "🚀 Firecrawl Complete Worker Fix"
echo "================================="

# Backup current docker-compose.yaml
cp docker-compose.yaml docker-compose.yaml.backup.$(date +%s)

# Update the command to use harness which starts all workers
sed -i 's|command: node dist/src/index.js|command: node dist/src/harness.js --start-docker|' docker-compose.yaml

echo "✅ Updated docker-compose.yaml to use harness"

# Restart services
docker compose down
docker compose up -d --build api

echo "⏳ Waiting 20 seconds for workers to start..."
sleep 20

# Test with a new job
echo "🧪 Creating test crawl job..."
response=$(curl -s -X POST http://localhost:3002/v2/crawl \
    -H "Content-Type: application/json" \
    -d '{"url":"https://example.com","limit":1}')

echo "Response: $response"

if [[ "$response" == *"\"id\":"* ]]; then
    job_id=$(echo "$response" | grep -oE '"id":"[^"]*"' | cut -d'"' -f4)
    echo "Job created: $job_id"
    
    echo "Waiting 10 seconds for processing..."
    sleep 10
    
    echo "Checking status:"
    curl -s "http://localhost:3002/v2/crawl/$job_id" | python3 -m json.tool
fi

echo "✅ Done! Check logs with: docker compose logs -f api | grep -i worker"
EOF
Output

#!/usr/bin/env zsh

# Firecrawl Complete Worker Fix
# Updates docker-compose.yaml to run workers properly

set -e

echo "🚀 Firecrawl Complete Worker Fix"
echo "================================="

# Backup current docker-compose.yaml
cp docker-compose.yaml docker-compose.yaml.backup.$(date +%s)

# Update the command to use harness which starts all workers
sed -i 's|command: node dist/src/index.js|command: node dist/src/harness.js --start-docker|' docker-compose.yaml

echo "✅ Updated docker-compose.yaml to use harness"

# Restart services
docker compose down
docker compose up -d --build api

echo "⏳ Waiting 20 seconds for workers to start..."
sleep 20

# Test with a new job
echo "🧪 Creating test crawl job..."
response=$(curl -s -X POST http://localhost:3002/v2/crawl \
    -H "Content-Type: application/json" \
    -d '{"url":"https://example.com","limit":1}')

echo "Response: $response"

if [[ "$response" == *"\"id\":"* ]]; then
    job_id=$(echo "$response" | grep -oE '"id":"[^"]*"' | cut -d'"' -f4)
    echo "Job created: $job_id"
    
    echo "Waiting 10 seconds for processing..."
    sleep 10
    
    echo "Checking status:"
    curl -s "http://localhost:3002/v2/crawl/$job_id" | python3 -m json.tool
fi

echo "✅ Done! Check logs with: docker compose logs -f api | grep -i worker
