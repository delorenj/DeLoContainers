import { cmd } from "./cmd"
import { App } from "../../app/app"
import { Provider } from "../../provider/provider"
import { Share } from "../../share/share"
import { UI } from "../ui"
import { Log } from "../../util/log"

export const ServeCommand = cmd({
  command: "serve",
  describe: "starts a headless opencode server",
  builder: (yargs) =>
    yargs
      .option("port", {
        alias: "p",
        type: "number",
        default: 4096,
        describe: "port to listen on",
      })
      .option("hostname", {
        alias: "h",
        type: "string",
        default: "127.0.0.1",
        describe: "hostname to listen on",
      }),
  handler: async (args) => {
    const log = Log.create({ service: "serve" })
    
    // Initialize the app context
    const result = await App.provide(
      { cwd: process.cwd(), version: args.$0 || "dev" },
      async () => {
        // Check for providers
        const providers = await Provider.list()
        if (Object.keys(providers).length === 0) {
          UI.println("Error: No providers configured. Please run 'opencode auth' first.")
          return "needs_provider"
        }

        // Initialize share functionality
        await Share.init()

        // Start the server with specified port and hostname
        const server = Bun.serve({
          port: args.port,
          hostname: args.hostname,
          idleTimeout: 0,
          fetch: (await import("../../server/server")).Server.app().fetch,
        })

        console.log(`opencode server listening on http://${args.hostname}:${args.port}`)
        console.log(`\nAvailable endpoints:`)
        console.log(`  GET  ${server.url}openapi - OpenAPI documentation`)
        console.log(`  GET  ${server.url}event - Server-sent events stream`)
        console.log(`  POST ${server.url}app_info - Get app information`)
        console.log(`  POST ${server.url}app_initialize - Initialize the app`)
        console.log(`  POST ${server.url}session_create - Create a new session`)
        console.log(`  POST ${server.url}session_list - List all sessions`)
        console.log(`  POST ${server.url}session_chat - Chat with a model`)
        console.log(`  POST ${server.url}session_messages - Get messages for a session`)
        console.log(`  POST ${server.url}provider_list - List available providers`)
        console.log(`  POST ${server.url}file_search - Search for files`)
        console.log(`\nPress Ctrl+C to stop the server`)

        // Handle graceful shutdown
        process.on("SIGINT", () => {
          log.info("Shutting down server...")
          server.stop()
          process.exit(0)
        })

        process.on("SIGTERM", () => {
          log.info("Shutting down server...")
          server.stop()
          process.exit(0)
        })

        // Keep the process running
        await new Promise(() => {})
        
        return "done"
      }
    )

    if (result === "needs_provider") {
      process.exit(1)
    }
  },
})