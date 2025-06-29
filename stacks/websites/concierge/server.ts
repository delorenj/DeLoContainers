const API_KEY = Deno.env.get("API_KEY");
const OPENROUTER_API_KEY = Deno.env.get("OPENROUTER_API_KEY");

interface LLMRequest {
  model?: string;
  messages: Array<{
    role: "system" | "user" | "assistant";
    content: string;
  }>;
  stream?: boolean;
  max_tokens?: number;
  temperature?: number;
}

interface HealthResponse {
  status: "ok" | "error";
  timestamp: string;
  version: "1.0.0";
  services: {
    openrouter: boolean;
    memory: boolean;
  };
}

// Authentication middleware
function authenticate(req: Request): boolean {
  const token = req.headers.get("X-API-Token");
  return token === API_KEY;
}

// CORS headers
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-API-Token",
};

// Health check endpoint
async function handleHealth(): Promise<Response> {
  const health: HealthResponse = {
    status: "ok",
    timestamp: new Date().toISOString(),
    version: "1.0.0",
    services: {
      openrouter: !!OPENROUTER_API_KEY,
      memory: true, // Assume memory service is available
    },
  };

  return new Response(JSON.stringify(health, null, 2), {
    headers: { 
      "Content-Type": "application/json",
      ...corsHeaders
    },
  });
}

// Hello endpoint (legacy)
function handleHello(req: Request): Response {
  const isAuthenticated = authenticate(req);
  
  const message = isAuthenticated ? "hello, jarad" : "world";
  
  return new Response(JSON.stringify({ message }), {
    headers: { 
      "Content-Type": "application/json",
      ...corsHeaders
    },
  });
}

// LLM proxy endpoint
async function handleLLMRequest(req: Request): Promise<Response> {
  if (!authenticate(req)) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { 
        "Content-Type": "application/json",
        ...corsHeaders
      },
    });
  }

  if (!OPENROUTER_API_KEY) {
    return new Response(JSON.stringify({ error: "OpenRouter API key not configured" }), {
      status: 500,
      headers: { 
        "Content-Type": "application/json",
        ...corsHeaders
      },
    });
  }

  try {
    const body: LLMRequest = await req.json();
    
    // Default model if not specified
    if (!body.model) {
      body.model = "anthropic/claude-3.5-sonnet";
    }

    const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENROUTER_API_KEY}`,
        "Content-Type": "application/json",
        "HTTP-Referer": "https://concierge.delo.sh",
        "X-Title": "Concierge AI Gateway",
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      throw new Error(`OpenRouter API error: ${response.status}`);
    }

    // Handle streaming responses
    if (body.stream) {
      return new Response(response.body, {
        headers: {
          "Content-Type": "text/event-stream",
          "Cache-Control": "no-cache",
          "Connection": "keep-alive",
          ...corsHeaders,
        },
      });
    }

    const data = await response.json();
    return new Response(JSON.stringify(data), {
      headers: { 
        "Content-Type": "application/json",
        ...corsHeaders
      },
    });

  } catch (error) {
    console.error("LLM request error:", error);
    return new Response(JSON.stringify({ 
      error: "Internal server error",
      details: error.message 
    }), {
      status: 500,
      headers: { 
        "Content-Type": "application/json",
        ...corsHeaders
      },
    });
  }
}

// WebSocket handler for real-time communication
function handleWebSocket(req: Request): Response {
  if (!authenticate(req)) {
    return new Response("Unauthorized", { status: 401 });
  }

  const { socket, response } = Deno.upgradeWebSocket(req);

  socket.onopen = () => {
    console.log("WebSocket connection opened");
    socket.send(JSON.stringify({ 
      type: "connection", 
      message: "Connected to Concierge",
      timestamp: new Date().toISOString()
    }));
  };

  socket.onmessage = async (event) => {
    try {
      const data = JSON.parse(event.data);
      console.log("WebSocket message received:", data);

      // Echo back for now - can be extended for real agent communication
      socket.send(JSON.stringify({
        type: "response",
        data: data,
        timestamp: new Date().toISOString()
      }));
    } catch (error) {
      socket.send(JSON.stringify({
        type: "error",
        message: "Invalid JSON",
        timestamp: new Date().toISOString()
      }));
    }
  };

  socket.onclose = () => {
    console.log("WebSocket connection closed");
  };

  return response;
}

// Main request handler
Deno.serve({ port: 8000 }, async (req) => {
  const url = new URL(req.url);
  const method = req.method;

  // Handle CORS preflight
  if (method === "OPTIONS") {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  console.log(`${method} ${url.pathname}`);

  // Route handling
  switch (url.pathname) {
    case "/health":
      return await handleHealth();
    
    case "/hello":
      return handleHello(req);
    
    case "/llm":
      if (method === "POST") {
        return await handleLLMRequest(req);
      }
      break;
    
    case "/ws":
      if (req.headers.get("upgrade") === "websocket") {
        return handleWebSocket(req);
      }
      break;
    
    default:
      return new Response(JSON.stringify({ 
        error: "Not Found",
        available_endpoints: ["/health", "/hello", "/llm", "/ws"]
      }), { 
        status: 404,
        headers: { 
          "Content-Type": "application/json",
          ...corsHeaders
        }
      });
  }

  return new Response("Method Not Allowed", { 
    status: 405,
    headers: corsHeaders
  });
});

console.log("🚀 Concierge server running on port 8000");
console.log("📋 Available endpoints:");
console.log("  GET  /health - Service health check");
console.log("  GET  /hello  - Hello world (authenticated with X-API-Token)");
console.log("  POST /llm    - LLM proxy to OpenRouter (authenticated)");
console.log("  WS   /ws     - WebSocket connection (authenticated)");
