#!/usr/bin/env bun
/**
 * Example of using the opencode serve API
 * 
 * First, start the server:
 *   bun run ./packages/opencode/src/index.ts serve --port 5000
 * 
 * Then run this example:
 *   bun run ./packages/opencode/examples/serve-api-example.ts
 */

const API_URL = "http://127.0.0.1:5000"

async function example() {
  try {
    // 1. List available providers
    console.log("=== Listing providers ===")
    const providersRes = await fetch(`${API_URL}/provider_list`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: "{}"
    })
    const providers = await providersRes.json()
    console.log("Available providers:", providers.providers.map((p: any) => p.id))
    
    // 2. Create a new session
    console.log("\n=== Creating session ===")
    const sessionRes = await fetch(`${API_URL}/session_create`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: "{}"
    })
    const session = await sessionRes.json()
    console.log("Session created:", session.id)
    
    // 3. Chat with the model
    console.log("\n=== Chatting with model ===")
    const chatRes = await fetch(`${API_URL}/session_chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        sessionID: session.id,
        providerID: providers.providers[0].id,
        modelID: providers.default[providers.providers[0].id],
        parts: [
          {
            type: "text",
            content: "What is 2+2? Reply with just the number."
          }
        ]
      })
    })
    const chatResult = await chatRes.json()
    if (chatResult.error) {
      console.log("Chat error:", chatResult.error)
    } else if (chatResult.parts && chatResult.parts[0]) {
      console.log("AI Response:", chatResult.parts[0].content)
    } else {
      console.log("Unexpected response:", chatResult)
    }
    
    // 4. Get session messages
    console.log("\n=== Session messages ===")
    const messagesRes = await fetch(`${API_URL}/session_messages`, {
      method: "POST", 
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ sessionID: session.id })
    })
    const messages = await messagesRes.json()
    console.log("Total messages:", messages.length)
    
  } catch (error) {
    console.error("Error:", error)
    console.log("\nMake sure the server is running:")
    console.log("  bun run ./packages/opencode/src/index.ts serve --port 5000")
  }
}

example()