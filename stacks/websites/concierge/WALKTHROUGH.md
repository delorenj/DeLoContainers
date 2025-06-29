# 🏨 Concierge AI Gateway - Cool Scenarios Walkthrough

Welcome to your new AI-powered gateway! Let's explore three clever scenarios that showcase the power of your Concierge service. Each scenario builds on the last, demonstrating real-world use cases.

---

## 🎯 Scenario 1: "The Smart Health Monitor"
*Monitor your entire infrastructure through AI-powered analysis*

### What We're Doing
Use Concierge to create an intelligent monitoring system that not only checks service health but provides AI-powered insights and recommendations.

### Step 1: Basic Health Intelligence
```bash
# First, let's see what our Concierge knows about itself
curl -s https://concierge.delo.sh/health | jq .
```

### Step 2: AI-Powered Infrastructure Analysis
```bash
# Ask your AI to analyze the health data and provide insights
curl -X POST https://concierge.delo.sh/llm \
  -H "Content-Type: application/json" \
  -H "X-API-Token: concierge-api-key-secure-token-2025" \
  -d '{
    "messages": [
      {
        "role": "system", 
        "content": "You are an expert DevOps engineer analyzing infrastructure health data. Provide concise, actionable insights."
      },
      {
        "role": "user", 
        "content": "Analyze this health status: {\"status\":\"ok\",\"services\":{\"openrouter\":true,\"memory\":true}}. What does this tell you about the system and what should I monitor next?"
      }
    ],
    "model": "anthropic/claude-3.5-sonnet",
    "max_tokens": 200
  }' | jq -r '.choices[0].message.content'
```

### Step 3: Create a Smart Monitoring Script
```bash
# Create an intelligent monitoring script
cat > /tmp/smart_monitor.sh << 'EOF'
#!/bin/bash

echo "🏨 Concierge Smart Monitor"
echo "=========================="

# Get health data
HEALTH=$(curl -s https://concierge.delo.sh/health)
echo "📊 Current Status: $(echo $HEALTH | jq -r '.status')"

# Ask AI for analysis
ANALYSIS=$(curl -s -X POST https://concierge.delo.sh/llm \
  -H "Content-Type: application/json" \
  -H "X-API-Token: concierge-api-key-secure-token-2025" \
  -d "{
    \"messages\": [
      {\"role\": \"system\", \"content\": \"You are a DevOps AI assistant. Analyze health data and provide 2-3 bullet points of actionable insights.\"},
      {\"role\": \"user\", \"content\": \"Health data: $HEALTH. Provide brief analysis.\"}
    ],
    \"model\": \"anthropic/claude-3.5-sonnet\",
    \"max_tokens\": 150
  }" | jq -r '.choices[0].message.content')

echo "🤖 AI Analysis:"
echo "$ANALYSIS"
EOF

chmod +x /tmp/smart_monitor.sh && /tmp/smart_monitor.sh
```

**🎉 Cool Factor**: Your infrastructure now has an AI brain that can interpret health data and provide intelligent recommendations!

---

## 🎯 Scenario 2: "The Code Review Assistant"
*Turn Concierge into your personal code review buddy*

### What We're Doing
Create a workflow where you can paste code snippets and get instant AI-powered code reviews, suggestions, and improvements through your Concierge gateway.

### Step 1: Quick Code Review
```bash
# Let's review some Docker Compose code
curl -X POST https://concierge.delo.sh/llm \
  -H "Content-Type: application/json" \
  -H "X-API-Token: concierge-api-key-secure-token-2025" \
  -d '{
    "messages": [
      {
        "role": "system", 
        "content": "You are a senior DevOps engineer specializing in Docker and containerization. Provide concise, actionable code reviews."
      },
      {
        "role": "user", 
        "content": "Review this Docker Compose service:\n\n```yaml\nservices:\n  concierge:\n    image: denoland/deno:alpine\n    command: run --allow-net --allow-env server.ts\n    environment:\n      - API_KEY=${CONCIERGE_API_KEY}\n    volumes:\n      - ./server.ts:/app/server.ts:ro\n```\n\nWhat improvements would you suggest?"
      }
    ],
    "model": "anthropic/claude-3.5-sonnet",
    "max_tokens": 300
  }' | jq -r '.choices[0].message.content'
```

### Step 2: Interactive Code Improvement Session
```bash
# Create a code review function
code_review() {
    local code_file="$1"
    local language="${2:-typescript}"
    
    echo "🔍 Reviewing $code_file..."
    
    # Read the code
    CODE_CONTENT=$(cat "$code_file")
    
    # Send to Concierge for review
    curl -X POST https://concierge.delo.sh/llm \
      -H "Content-Type: application/json" \
      -H "X-API-Token: concierge-api-key-secure-token-2025" \
      -d "{
        \"messages\": [
          {\"role\": \"system\", \"content\": \"You are an expert $language developer. Provide a code review with: 1) What's good 2) What could be improved 3) Security considerations. Be concise but thorough.\"},
          {\"role\": \"user\", \"content\": \"Please review this $language code:\n\n\`\`\`$language\n$CODE_CONTENT\n\`\`\`\"}
        ],
        \"model\": \"anthropic/claude-3.5-sonnet\",
        \"max_tokens\": 500
      }" | jq -r '.choices[0].message.content'
}

# Review your Concierge server code
code_review "/home/delorenj/docker/stacks/websites/concierge/server.ts" "typescript"
```

### Step 3: Security Audit Mode
```bash
# Security-focused review
curl -X POST https://concierge.delo.sh/llm \
  -H "Content-Type: application/json" \
  -H "X-API-Token: concierge-api-key-secure-token-2025" \
  -d '{
    "messages": [
      {
        "role": "system", 
        "content": "You are a cybersecurity expert specializing in API security. Focus on authentication, authorization, input validation, and common vulnerabilities."
      },
      {
        "role": "user", 
        "content": "Audit this API endpoint for security issues:\n\n```typescript\nfunction authenticate(req: Request): boolean {\n  const token = req.headers.get(\"X-API-Token\");\n  return token === API_KEY;\n}\n\nasync function handleLLMRequest(req: Request): Promise<Response> {\n  if (!authenticate(req)) {\n    return new Response(JSON.stringify({ error: \"Unauthorized\" }), { status: 401 });\n  }\n  const body = await req.json();\n  // ... rest of function\n}\n```\n\nWhat security improvements do you recommend?"
      }
    ],
    "model": "anthropic/claude-3.5-sonnet",
    "max_tokens": 400
  }' | jq -r '.choices[0].message.content'
```

**🎉 Cool Factor**: Your Concierge is now your personal code review assistant, providing expert-level feedback on demand!

---

## 🎯 Scenario 3: "The Real-Time AI Collaboration Hub"
*Use WebSockets for live AI-powered development sessions*

### What We're Doing
Create a real-time development environment where you can have ongoing conversations with AI, get live feedback, and build interactive workflows.

### Step 1: Open the Interactive Test Client
```bash
# Open the web client in your browser
echo "🌐 Open this in your browser: file:///home/delorenj/docker/stacks/websites/concierge/test-client.html"

# Or create a simple Python WebSocket client
cat > /tmp/ws_client.py << 'EOF'
import asyncio
import websockets
import json
import sys

async def chat_with_concierge():
    uri = "wss://concierge.delo.sh/ws"
    headers = {"X-API-Token": "concierge-api-key-secure-token-2025"}
    
    try:
        async with websockets.connect(uri, extra_headers=headers) as websocket:
            print("🏨 Connected to Concierge WebSocket!")
            print("Type 'quit' to exit, or start chatting...")
            
            # Listen for messages from server
            async def listen():
                async for message in websocket:
                    data = json.loads(message)
                    print(f"🤖 Concierge: {data}")
            
            # Start listening task
            listen_task = asyncio.create_task(listen())
            
            # Interactive chat loop
            while True:
                user_input = input("You: ")
                if user_input.lower() == 'quit':
                    break
                
                message = {
                    "type": "chat",
                    "message": user_input,
                    "timestamp": "2025-06-29T03:00:00.000Z"
                }
                
                await websocket.send(json.dumps(message))
            
            listen_task.cancel()
            
    except Exception as e:
        print(f"❌ Connection failed: {e}")

if __name__ == "__main__":
    asyncio.run(chat_with_concierge())
EOF

python3 /tmp/ws_client.py
```

### Step 2: Create a Live Development Assistant
```bash
# Create an advanced WebSocket development helper
cat > /tmp/dev_assistant.py << 'EOF'
import asyncio
import websockets
import json
import subprocess
import os

class DevAssistant:
    def __init__(self):
        self.uri = "wss://concierge.delo.sh/ws"
        self.headers = {"X-API-Token": "concierge-api-key-secure-token-2025"}
        self.websocket = None
    
    async def connect(self):
        self.websocket = await websockets.connect(self.uri, extra_headers=self.headers)
        print("🏨 Dev Assistant connected to Concierge!")
    
    async def ask_ai(self, question, context=""):
        """Ask AI a question through the LLM endpoint"""
        import requests
        
        response = requests.post("https://concierge.delo.sh/llm", 
            headers={
                "Content-Type": "application/json",
                "X-API-Token": "concierge-api-key-secure-token-2025"
            },
            json={
                "messages": [
                    {"role": "system", "content": f"You are a helpful development assistant. Context: {context}"},
                    {"role": "user", "content": question}
                ],
                "model": "anthropic/claude-3.5-sonnet",
                "max_tokens": 300
            }
        )
        
        if response.status_code == 200:
            return response.json()["choices"][0]["message"]["content"]
        return "Error getting AI response"
    
    async def run_command(self, command):
        """Run a shell command and return output"""
        try:
            result = subprocess.run(command, shell=True, capture_output=True, text=True)
            return f"Exit code: {result.returncode}\nOutput: {result.stdout}\nError: {result.stderr}"
        except Exception as e:
            return f"Command failed: {e}"
    
    async def interactive_session(self):
        print("🚀 Interactive Development Session Started!")
        print("Commands: 'ai <question>', 'run <command>', 'status', 'quit'")
        
        while True:
            try:
                user_input = input("\n💻 Dev> ").strip()
                
                if user_input.lower() == 'quit':
                    break
                elif user_input.startswith('ai '):
                    question = user_input[3:]
                    print("🤖 Thinking...")
                    answer = await self.ask_ai(question, "Development session context")
                    print(f"🤖 AI: {answer}")
                elif user_input.startswith('run '):
                    command = user_input[4:]
                    print(f"⚡ Running: {command}")
                    output = await self.run_command(command)
                    print(f"📋 Result:\n{output}")
                elif user_input == 'status':
                    print("📊 Checking Concierge status...")
                    status_output = await self.run_command("curl -s https://concierge.delo.sh/health")
                    ai_analysis = await self.ask_ai(f"Analyze this health status: {status_output}")
                    print(f"🤖 AI Analysis: {ai_analysis}")
                else:
                    print("❓ Unknown command. Try 'ai <question>', 'run <command>', 'status', or 'quit'")
                    
            except KeyboardInterrupt:
                break
            except Exception as e:
                print(f"❌ Error: {e}")
        
        if self.websocket:
            await self.websocket.close()
        print("👋 Development session ended!")

async def main():
    assistant = DevAssistant()
    await assistant.connect()
    await assistant.interactive_session()

if __name__ == "__main__":
    asyncio.run(main())
EOF

echo "🚀 Starting Interactive Development Assistant..."
python3 /tmp/dev_assistant.py
```

### Step 3: Create a Multi-Agent Workflow Simulator
```bash
# Simulate multiple AI agents working together
cat > /tmp/multi_agent_demo.sh << 'EOF'
#!/bin/bash

echo "🤖 Multi-Agent AI Workflow Demo"
echo "==============================="

# Agent 1: System Architect
echo "🏗️  Agent 1 (Architect): Analyzing system design..."
ARCHITECT_RESPONSE=$(curl -s -X POST https://concierge.delo.sh/llm \
  -H "Content-Type: application/json" \
  -H "X-API-Token: concierge-api-key-secure-token-2025" \
  -d '{
    "messages": [
      {"role": "system", "content": "You are a system architect. Analyze the Concierge service architecture and suggest one improvement."},
      {"role": "user", "content": "The Concierge service currently has health monitoring, LLM proxy, and WebSocket support. What architectural improvement would you prioritize next?"}
    ],
    "model": "anthropic/claude-3.5-sonnet",
    "max_tokens": 150
  }' | jq -r '.choices[0].message.content')

echo "🏗️  Architect says: $ARCHITECT_RESPONSE"
echo ""

# Agent 2: Security Expert
echo "🔒 Agent 2 (Security): Reviewing security posture..."
SECURITY_RESPONSE=$(curl -s -X POST https://concierge.delo.sh/llm \
  -H "Content-Type: application/json" \
  -H "X-API-Token: concierge-api-key-secure-token-2025" \
  -d '{
    "messages": [
      {"role": "system", "content": "You are a security expert. Focus on API security and authentication."},
      {"role": "user", "content": "The Concierge service uses API key authentication via X-API-Token header. What security enhancement should be implemented first?"}
    ],
    "model": "anthropic/claude-3.5-sonnet",
    "max_tokens": 150
  }' | jq -r '.choices[0].message.content')

echo "🔒 Security Expert says: $SECURITY_RESPONSE"
echo ""

# Agent 3: Performance Engineer
echo "⚡ Agent 3 (Performance): Analyzing performance..."
PERFORMANCE_RESPONSE=$(curl -s -X POST https://concierge.delo.sh/llm \
  -H "Content-Type: application/json" \
  -H "X-API-Token: concierge-api-key-secure-token-2025" \
  -d '{
    "messages": [
      {"role": "system", "content": "You are a performance engineer. Focus on scalability and optimization."},
      {"role": "user", "content": "The Concierge service runs on Deno with Docker. What performance optimization would have the biggest impact?"}
    ],
    "model": "anthropic/claude-3.5-sonnet",
    "max_tokens": 150
  }' | jq -r '.choices[0].message.content')

echo "⚡ Performance Engineer says: $PERFORMANCE_RESPONSE"
echo ""

# Synthesizer Agent
echo "🧠 Agent 4 (Synthesizer): Creating action plan..."
SYNTHESIS_RESPONSE=$(curl -s -X POST https://concierge.delo.sh/llm \
  -H "Content-Type: application/json" \
  -H "X-API-Token: concierge-api-key-secure-token-2025" \
  -d "{
    \"messages\": [
      {\"role\": \"system\", \"content\": \"You are a project manager synthesizing input from multiple experts. Create a prioritized action plan.\"},
      {\"role\": \"user\", \"content\": \"Based on these expert opinions:\n\nArchitect: $ARCHITECT_RESPONSE\n\nSecurity: $SECURITY_RESPONSE\n\nPerformance: $PERFORMANCE_RESPONSE\n\nCreate a prioritized 3-item action plan.\"}
    ],
    \"model\": \"anthropic/claude-3.5-sonnet\",
    \"max_tokens\": 200
  }" | jq -r '.choices[0].message.content')

echo "🧠 Synthesizer's Action Plan:"
echo "$SYNTHESIS_RESPONSE"
echo ""
echo "🎉 Multi-agent analysis complete!"
EOF

chmod +x /tmp/multi_agent_demo.sh && /tmp/multi_agent_demo.sh
```

**🎉 Cool Factor**: You now have a real-time AI collaboration environment where multiple AI agents can work together to analyze and improve your systems!

---

## 🏆 Bonus: The Ultimate Concierge Command

Create a single command that showcases all three scenarios:

```bash
# The Ultimate Concierge Demo
cat > /tmp/ultimate_demo.sh << 'EOF'
#!/bin/bash

echo "🏨 ULTIMATE CONCIERGE DEMO"
echo "=========================="
echo ""

echo "🎯 Scenario 1: Smart Health Monitor"
echo "-----------------------------------"
HEALTH=$(curl -s https://concierge.delo.sh/health)
echo "Status: $(echo $HEALTH | jq -r '.status')"

echo ""
echo "🎯 Scenario 2: Code Review Assistant"
echo "------------------------------------"
REVIEW=$(curl -s -X POST https://concierge.delo.sh/llm \
  -H "Content-Type: application/json" \
  -H "X-API-Token: concierge-api-key-secure-token-2025" \
  -d '{
    "messages": [
      {"role": "system", "content": "You are a code reviewer. Be concise."},
      {"role": "user", "content": "Rate this API design from 1-10 and give one improvement: A service with /health, /hello, /llm endpoints using API key auth."}
    ],
    "model": "anthropic/claude-3.5-sonnet",
    "max_tokens": 100
  }' | jq -r '.choices[0].message.content')
echo "AI Review: $REVIEW"

echo ""
echo "🎯 Scenario 3: Real-time Collaboration"
echo "--------------------------------------"
echo "WebSocket endpoint ready at: wss://concierge.delo.sh/ws"
echo "Test client available at: test-client.html"

echo ""
echo "🚀 Your Concierge is ready for:"
echo "   • Intelligent monitoring"
echo "   • AI-powered code reviews"
echo "   • Real-time collaboration"
echo "   • Multi-agent workflows"
echo ""
echo "🎉 Welcome to the future of AI-powered development!"
EOF

chmod +x /tmp/ultimate_demo.sh && /tmp/ultimate_demo.sh
```

---

## 🎊 What You've Accomplished

With these three scenarios, you now have:

1. **🧠 Intelligent Infrastructure**: Your services can self-analyze and provide insights
2. **👨‍💻 AI Development Partner**: Instant code reviews and security audits
3. **🤝 Real-time AI Collaboration**: Live development sessions with AI assistance

Your Concierge isn't just an API gateway—it's the foundation for an entire AI-powered development ecosystem! 🚀

**Next Challenge**: Try combining all three scenarios in a single workflow where you monitor your system, get AI recommendations, implement changes, and have the AI review your work in real-time!
