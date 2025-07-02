#!/bin/bash

# AI Stack Status Check Script

echo "=== AI Stack Status Check ==="
echo ""

# Check bolt.diy
echo "🤖 Bolt.DIY (AI Web Development Assistant)"
echo "   URL: https://bolt.delo.sh"
if curl -s -o /dev/null -w "%{http_code}" https://bolt.delo.sh | grep -q "200"; then
    echo "   Status: ✅ Online"
else
    echo "   Status: ❌ Offline"
fi
echo ""

# Check other AI services
echo "🔍 Qdrant (Vector Database)"
echo "   URL: https://qdrant.delo.sh"
if curl -s -o /dev/null -w "%{http_code}" https://qdrant.delo.sh | grep -q "200"; then
    echo "   Status: ✅ Online"
else
    echo "   Status: ❌ Offline"
fi
echo ""

echo "🌊 Flowise (LLM Application Builder)"
echo "   URL: https://flowise.delo.sh"
if curl -s -o /dev/null -w "%{http_code}" https://flowise.delo.sh | grep -q "200"; then
    echo "   Status: ✅ Online"
else
    echo "   Status: ❌ Offline"
fi
echo ""

echo "🤖 Agent Zero"
echo "   URL: https://agent-zero.delo.sh"
if curl -s -o /dev/null -w "%{http_code}" https://agent-zero.delo.sh | grep -q "200"; then
    echo "   Status: ✅ Online"
else
    echo "   Status: ❌ Offline"
fi
echo ""

# Check Docker containers
echo "📦 Docker Container Status:"
cd /home/delorenj/docker/stacks/ai/bolt-diy
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "=== Status Check Complete ==="
