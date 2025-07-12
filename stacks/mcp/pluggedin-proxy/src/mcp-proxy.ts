import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
  CallToolRequestSchema,
  GetPromptRequestSchema,
  ListPromptsRequestSchema,
  ListResourcesRequestSchema,
  ListToolsRequestSchema,
  ReadResourceRequestSchema,
  Tool,
  ListToolsResultSchema,
  ListPromptsResultSchema,
  ListResourcesResultSchema,
  ReadResourceResultSchema,
  ListResourceTemplatesRequestSchema,
  ListResourceTemplatesResultSchema,
  ResourceTemplate,
  CompatibilityCallToolResultSchema,
  GetPromptResultSchema,
  PromptMessage, // Import PromptMessage
  PingRequestSchema, // Import PingRequestSchema
} from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";
import { getMcpServers } from "./fetch-pluggedinmcp.js";
import { getSessionKey, sanitizeName, isDebugEnabled, getPluggedinMCPApiKey, getPluggedinMCPApiBaseUrl } from "./utils.js";
import { cleanupAllSessions, getSession, initSessions } from "./sessions.js";
import { ConnectedClient } from "./client.js";
import axios from "axios";
// Removed unused imports
// import { GetPluggedinToolsTool } from "./tools/get-pluggedin-tools.js"; // No longer needed?
// import { CallPluggedinToolTool } from "./tools/call-pluggedin-tool.js"; // No longer needed?
import { zodToJsonSchema } from 'zod-to-json-schema';
import { readFileSync } from 'fs';
import { createRequire } from 'module';
import { ToolExecutionResult, ServerParameters } from "./types.js"; // Import ServerParameters
import { logMcpActivity, createExecutionTimer } from "./notification-logger.js";
import { 
  RateLimiter, 
  sanitizeErrorMessage, 
  validateToolName, 
  validateRequestSize,
  withTimeout
} from "./security-utils.js";
import { debugLog, debugError } from "./debug-log.js";
// Removed incorrect McpMessage import

const require = createRequire(import.meta.url);
const packageJson = require('../package.json');

// Map to store prefixed tool name -> { originalName, serverUuid }
const toolToServerMap: Record<string, { originalName: string; serverUuid: string; }> = {};
// Map to store custom instruction name -> serverUuid
const instructionToServerMap: Record<string, string> = {};

// Define the static discovery tool schema using Zod
const DiscoverToolsInputSchema = z.object({
  server_uuid: z.string().uuid().optional().describe("Optional UUID of a specific server to discover. If omitted, attempts to discover all."),
  force_refresh: z.boolean().optional().default(false).describe("Set to true to bypass cache and force a fresh discovery. Defaults to false."),
}).describe("Triggers tool discovery for configured MCP servers in the Pluggedin App.");

// Define the static discovery tool structure
const discoverToolsStaticTool: Tool = {
    name: "pluggedin_discover_tools",
    description: "Triggers discovery of tools (and resources/templates) for configured MCP servers in the Pluggedin App.",
    inputSchema: zodToJsonSchema(DiscoverToolsInputSchema) as any,
};

// Define the static RAG query tool schema using Zod
const RagQueryInputSchema = z.object({
  query: z.string()
    .min(1, "Query cannot be empty")
    .max(1000, "Query too long")
    .describe("The RAG query to perform."),
}).describe("Performs a RAG query against documents in the authenticated user's project.");

// Define the static RAG query tool structure
const ragQueryStaticTool: Tool = {
    name: "pluggedin_rag_query",
    description: "Performs a RAG query against documents in the Pluggedin App.",
    inputSchema: zodToJsonSchema(RagQueryInputSchema) as any,
};

// Define the static tool for sending custom notifications
const sendNotificationStaticTool = {
  name: "pluggedin_send_notification",
  description: "Send custom notifications through the Plugged.in system with optional email delivery. You can provide a custom title or let the system use a localized default.",
  inputSchema: {
    type: "object",
    properties: {
      title: {
        type: "string",
        description: "Optional notification title. If not provided, a localized default will be used. Consider generating a descriptive title based on the message content."
      },
      message: {
        type: "string",
        description: "The notification message content"
      },
      severity: {
        type: "string",
        enum: ["INFO", "SUCCESS", "WARNING", "ALERT"],
        description: "The severity level of the notification (defaults to INFO)",
        default: "INFO"
      },
      sendEmail: {
        type: "boolean",
        description: "Whether to also send the notification via email",
        default: false
      }
    },
    required: ["message"]
  }
} as const;

// Input schema for validation
const SendNotificationInputSchema = z.object({
  title: z.string().optional(),
  message: z.string().min(1, "Message cannot be empty"),
  severity: z.enum(["INFO", "SUCCESS", "WARNING", "ALERT"]).default("INFO"),
  sendEmail: z.boolean().optional().default(false),
});

// Removed old static tool instances (getToolsInstance, callToolInstance) as they are superseded by API fetching

// Define the static prompt for proxy capabilities
const proxyCapabilitiesStaticPrompt = {
  name: "pluggedin_proxy_capabilities",
  description: "Learn about the Plugged.in MCP Proxy capabilities and available tools",
  arguments: []
} as const;

export const createServer = async () => {
  // Create rate limiters for different operations
  const toolCallRateLimiter = new RateLimiter(60000, 60); // 60 calls per minute
  const apiCallRateLimiter = new RateLimiter(60000, 100); // 100 API calls per minute
  
  const server = new Server(
    {
      name: "PluggedinMCP",
      version: packageJson.version,
    },
    {
      capabilities: {
        prompts: {}, // Enable prompt support capability
        resources: {},
        tools: {},
      },
    }
  );

  // List Tools Handler - Fetches tools from Pluggedin App API and adds static tool
  server.setRequestHandler(ListToolsRequestSchema, async (request) => {
     const apiKey = getPluggedinMCPApiKey();
     const baseUrl = getPluggedinMCPApiBaseUrl();
     
     // If no API key, return only static tools (for Smithery compatibility)
     // This path should be fast and not rate limited for tool discovery
     if (!apiKey || !baseUrl) {
       // Don't log to console for STDIO transport as it interferes with protocol
       return { 
         tools: [discoverToolsStaticTool, ragQueryStaticTool, sendNotificationStaticTool], 
         nextCursor: undefined 
       };
     }
     
     // Rate limit check only for authenticated API calls
     if (!apiCallRateLimiter.checkLimit()) {
       throw new Error("Rate limit exceeded. Please try again later.");
     }
     
     let fetchedTools: (Tool & { _serverUuid: string, _serverName?: string })[] = [];
     
     try {

       const apiUrl = `${baseUrl}/api/tools`; // Assuming this is the correct endpoint

       // Fetch the list of tools (which include original names and server info)
       // The API returns an object like { tools: [], message?: "..." }
       const response = await axios.get<{ tools: (Tool & { _serverUuid: string, _serverName?: string })[], message?: string }>(apiUrl, {
         headers: {
           Authorization: `Bearer ${apiKey}`,
         },
         timeout: 10000,
       });

       // Access the 'tools' array from the response payload
       const fetchedTools = response.data?.tools || [];

       // Clear previous mapping and populate with new data
       Object.keys(toolToServerMap).forEach(key => delete toolToServerMap[key]); // Clear map
       
       // Create mappings for each tool to its server
       fetchedTools.forEach(tool => {
         // Store mapping with original name as the key
         if (tool.name && tool._serverUuid) {
            toolToServerMap[tool.name] = { 
              originalName: tool.name, // No transformation needed anymore
              serverUuid: tool._serverUuid 
            };
         } else {
            debugError(`[ListTools Handler] Missing tool name or UUID for tool: ${tool.name}`);
         }
       });

       // Prepare the response payload according to MCP spec { tools: Tool[] }
       // Remove the internal _serverUuid and _serverName before sending to client
       const toolsForClient: Tool[] = fetchedTools.map(({ _serverUuid, _serverName, ...rest }) => rest);

       // Note: Pagination not handled here, assumes API returns all tools

       // Always include the static tools
       const allToolsForClient = [discoverToolsStaticTool, ragQueryStaticTool, sendNotificationStaticTool, ...toolsForClient];

       return { tools: allToolsForClient, nextCursor: undefined };

     } catch (error: any) {
       // Log API fetch error but still return the static tool
       let sanitizedError = "Failed to list tools";
       if (axios.isAxiosError(error) && error.response?.status) {
         // Only include status code, not full error details
         sanitizedError = `Failed to list tools (HTTP ${error.response.status})`;
       }
       debugError("[ListTools Handler Error]", error); // Log full error internally
       throw new Error(sanitizedError);
     }
  });

  // Call Tool Handler - Routes tool calls to the appropriate downstream server
  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name: requestedToolName, arguments: args } = request.params;
    const meta = request.params._meta;

    // Basic input validation
    if (!requestedToolName || typeof requestedToolName !== 'string') {
      throw new Error("Invalid tool name provided");
    }

    // Basic request size check (lightweight)
    if (!validateRequestSize(request.params, 50 * 1024 * 1024)) { // 50MB limit
      throw new Error("Request payload too large");
    }

    // Rate limit check for tool calls
    if (!toolCallRateLimiter.checkLimit()) {
      throw new Error("Rate limit exceeded. Please try again later.");
    }

    try {
        // Handle static discovery tool first
        if (requestedToolName === discoverToolsStaticTool.name) {
            debugError(`[CallTool Handler] Executing static tool: ${requestedToolName}`);
            const validatedArgs = DiscoverToolsInputSchema.parse(args ?? {}); // Validate args
            const { server_uuid, force_refresh } = validatedArgs;

            const apiKey = getPluggedinMCPApiKey();
            const baseUrl = getPluggedinMCPApiBaseUrl();
            if (!apiKey || !baseUrl) {
                throw new Error("Pluggedin API Key or Base URL is not configured for discovery trigger.");
            }

            const timer = createExecutionTimer();
            let shouldRunDiscovery = force_refresh; // If force_refresh is true, always run discovery
            let existingDataSummary = "";

            // Check for existing data if not forcing refresh
            if (!force_refresh) {
                try {
                    // Check for existing tools, resources, prompts, and templates with timeout protection
                    const apiRequests = Promise.all([
                        axios.get(`${baseUrl}/api/tools`, { headers: { Authorization: `Bearer ${apiKey}` }, timeout: 10000 }),
                        axios.get(`${baseUrl}/api/resources`, { headers: { Authorization: `Bearer ${apiKey}` }, timeout: 10000 }),
                        axios.get(`${baseUrl}/api/prompts`, { headers: { Authorization: `Bearer ${apiKey}` }, timeout: 10000 }),
                        axios.get(`${baseUrl}/api/resource-templates`, { headers: { Authorization: `Bearer ${apiKey}` }, timeout: 10000 })
                    ]);
                    
                    const [toolsResponse, resourcesResponse, promptsResponse, templatesResponse] = await withTimeout(apiRequests, 15000);

                    const toolsCount = toolsResponse.data?.tools?.length || (Array.isArray(toolsResponse.data) ? toolsResponse.data.length : 0);
                    const resourcesCount = Array.isArray(resourcesResponse.data) ? resourcesResponse.data.length : 0;
                    const promptsCount = Array.isArray(promptsResponse.data) ? promptsResponse.data.length : 0;
                    const templatesCount = Array.isArray(templatesResponse.data) ? templatesResponse.data.length : 0;

                    const totalItems = toolsCount + resourcesCount + promptsCount + templatesCount;

                    if (totalItems > 0) {
                        // We have existing data, return it without running discovery
                        const staticToolsCount = 3; // Always have 3 static tools
                        const totalToolsCount = toolsCount + staticToolsCount;
                        existingDataSummary = `Found cached data: ${toolsCount} dynamic tools + ${staticToolsCount} static tools = ${totalToolsCount} total tools, ${resourcesCount} resources, ${promptsCount} prompts, ${templatesCount} templates`;
                        
                        const cacheMessage = server_uuid 
                            ? `Returning cached discovery data for server ${server_uuid}. ${existingDataSummary}. Use force_refresh=true to update.\n\n`
                            : `Returning cached discovery data for all servers. ${existingDataSummary}. Use force_refresh=true to update.\n\n`;

                        // Format the actual data for the response
                        let dataContent = cacheMessage;
                        
                        // Add static built-in tools section (always available)
                        dataContent += `## 🔧 Static Built-in Tools (Always Available):\n`;
                        dataContent += `1. **pluggedin_discover_tools** - Triggers discovery of tools (and resources/templates) for configured MCP servers in the Pluggedin App\n`;
                        dataContent += `2. **pluggedin_rag_query** - Performs a RAG query against documents in the Pluggedin App\n`;
                        dataContent += `3. **pluggedin_send_notification** - Send custom notifications through the Plugged.in system with optional email delivery\n`;
                        dataContent += `\n`;
                        
                        // Add dynamic tools section (from MCP servers)
                        if (toolsCount > 0) {
                            const tools = toolsResponse.data?.tools || toolsResponse.data || [];
                            dataContent += `## ⚡ Dynamic MCP Tools (${toolsCount}) - From Connected Servers:\n`;
                            tools.forEach((tool: any, index: number) => {
                                dataContent += `${index + 1}. **${tool.name}**`;
                                if (tool.description) {
                                    dataContent += ` - ${tool.description}`;
                                }
                                dataContent += `\n`;
                            });
                            dataContent += `\n`;
                        } else {
                            dataContent += `## ⚡ Dynamic MCP Tools (0) - From Connected Servers:\n`;
                            dataContent += `No dynamic tools available. Add MCP servers to get more tools.\n\n`;
                        }
                        
                        // Add prompts section  
                        if (promptsCount > 0) {
                            dataContent += `## 💬 Available Prompts (${promptsCount}):\n`;
                            promptsResponse.data.forEach((prompt: any, index: number) => {
                                dataContent += `${index + 1}. **${prompt.name}**`;
                                if (prompt.description) {
                                    dataContent += ` - ${prompt.description}`;
                                }
                                dataContent += `\n`;
                            });
                            dataContent += `\n`;
                        }
                        
                        // Add resources section
                        if (resourcesCount > 0) {
                            dataContent += `## 📄 Available Resources (${resourcesCount}):\n`;
                            resourcesResponse.data.forEach((resource: any, index: number) => {
                                dataContent += `${index + 1}. **${resource.name || resource.uri}**`;
                                if (resource.description) {
                                    dataContent += ` - ${resource.description}`;
                                }
                                if (resource.uri && resource.name !== resource.uri) {
                                    dataContent += ` (${resource.uri})`;
                                }
                                dataContent += `\n`;
                            });
                            dataContent += `\n`;
                        }
                        
                        // Add templates section
                        if (templatesCount > 0) {
                            dataContent += `## 📋 Available Resource Templates (${templatesCount}):\n`;
                            templatesResponse.data.forEach((template: any, index: number) => {
                                dataContent += `${index + 1}. **${template.name || template.uriTemplate}**`;
                                if (template.description) {
                                    dataContent += ` - ${template.description}`;
                                }
                                if (template.uriTemplate && template.name !== template.uriTemplate) {
                                    dataContent += ` (${template.uriTemplate})`;
                                }
                                dataContent += `\n`;
                            });
                        }

                        // Log successful cache hit
                        logMcpActivity({
                            action: 'tool_call',
                            serverName: 'Discovery System (Cache)',
                            serverUuid: 'pluggedin_discovery_cache',
                            itemName: requestedToolName,
                            success: true,
                            executionTime: timer.stop(),
                        }).catch(() => {}); // Ignore notification errors

                        return {
                            content: [{ type: "text", text: dataContent }],
                            isError: false,
                        } as ToolExecutionResult;
                    } else {
                        // No existing data found, run discovery
                        shouldRunDiscovery = true;
                        existingDataSummary = "No cached dynamic data found";
                    }
                } catch (cacheError: any) {
                    // Error checking cache, show static tools and proceed with discovery
                    debugError(`[Discovery Cache Check] Error checking for existing data: ${cacheError.message}`);
                    
                    // Show static tools even when cache check fails
                    const staticToolsCount = 3;
                    const cacheErrorMessage = `Cache check failed, showing static tools. Will run discovery for dynamic tools.\n\n`;
                    
                    let staticContent = cacheErrorMessage;
                    staticContent += `## 🔧 Static Built-in Tools (Always Available):\n`;
                    staticContent += `1. **pluggedin_discover_tools** - Triggers discovery of tools (and resources/templates) for configured MCP servers in the Pluggedin App\n`;
                    staticContent += `2. **pluggedin_rag_query** - Performs a RAG query against documents in the Pluggedin App\n`;
                    staticContent += `3. **pluggedin_send_notification** - Send custom notifications through the Plugged.in system with optional email delivery\n`;
                    staticContent += `\n## ⚡ Dynamic MCP Tools - From Connected Servers:\n`;
                    staticContent += `Cache check failed. Running discovery to find dynamic tools...\n\n`;
                    staticContent += `Note: You can call pluggedin_discover_tools again to see the updated results.`;

                    // Log cache error but static tools shown
                    logMcpActivity({
                        action: 'tool_call',
                        serverName: 'Discovery System (Cache Error)',
                        serverUuid: 'pluggedin_discovery_cache_error',
                        itemName: requestedToolName,
                        success: true,
                        executionTime: timer.stop(),
                    }).catch(() => {}); // Ignore notification errors

                    // Also trigger discovery in background (fire and forget)
                    try {
                        const discoveryApiUrl = server_uuid
                            ? `${baseUrl}/api/discover/${server_uuid}`
                            : `${baseUrl}/api/discover/all`;
                        
                        axios.post(discoveryApiUrl, {}, {
                            headers: { Authorization: `Bearer ${apiKey}` },
                            timeout: 60000, // Background discovery timeout
                        }).catch(() => {}); // Fire and forget
                    } catch {
                        // Ignore discovery trigger errors
                    }

                    return {
                        content: [{ type: "text", text: staticContent }],
                        isError: false,
                    } as ToolExecutionResult;
                }
            }

            // Run discovery if needed
            if (shouldRunDiscovery) {
                // Define the API endpoint in pluggedin-app to trigger discovery
                const discoveryApiUrl = server_uuid
                    ? `${baseUrl}/api/discover/${server_uuid}` // Endpoint for specific server
                    : `${baseUrl}/api/discover/all`; // Endpoint for all servers

                if (force_refresh) {
                    // For force refresh, get cached data first AND trigger discovery in background
                    try {
                        // Fire-and-forget: trigger discovery in background
                        axios.post(discoveryApiUrl, {}, {
                            headers: { Authorization: `Bearer ${apiKey}` },
                            timeout: 60000, // 60s timeout for background discovery
                        }).catch((bgError) => {
                            debugError(`[Background Discovery] Failed: ${bgError.message}`);
                        });

                        // Get current cached data to show immediately
                        let forceRefreshContent = "";
                        
                        try {
                            // Fetch current cached data (use shorter timeout since this is just cache check)
                            const [toolsResponse, resourcesResponse, promptsResponse, templatesResponse] = await Promise.all([
                                axios.get(`${baseUrl}/api/tools`, { headers: { Authorization: `Bearer ${apiKey}` }, timeout: 5000 }),
                                axios.get(`${baseUrl}/api/resources`, { headers: { Authorization: `Bearer ${apiKey}` }, timeout: 5000 }),
                                axios.get(`${baseUrl}/api/prompts`, { headers: { Authorization: `Bearer ${apiKey}` }, timeout: 5000 }),
                                axios.get(`${baseUrl}/api/resource-templates`, { headers: { Authorization: `Bearer ${apiKey}` }, timeout: 5000 })
                            ]);

                            const toolsCount = toolsResponse.data?.tools?.length || (Array.isArray(toolsResponse.data) ? toolsResponse.data.length : 0);
                            const resourcesCount = Array.isArray(resourcesResponse.data) ? resourcesResponse.data.length : 0;
                            const promptsCount = Array.isArray(promptsResponse.data) ? promptsResponse.data.length : 0;
                            const templatesCount = Array.isArray(templatesResponse.data) ? templatesResponse.data.length : 0;

                            const staticToolsCount = 3;
                            const totalToolsCount = toolsCount + staticToolsCount;
                            
                            const refreshMessage = server_uuid 
                                ? `🔄 Force refresh initiated for server ${server_uuid}. Discovery is running in background.\n\nShowing current cached data (${toolsCount} dynamic tools + ${staticToolsCount} static tools = ${totalToolsCount} total tools, ${resourcesCount} resources, ${promptsCount} prompts, ${templatesCount} templates):\n\n`
                                : `🔄 Force refresh initiated for all servers. Discovery is running in background.\n\nShowing current cached data (${toolsCount} dynamic tools + ${staticToolsCount} static tools = ${totalToolsCount} total tools, ${resourcesCount} resources, ${promptsCount} prompts, ${templatesCount} templates):\n\n`;

                            forceRefreshContent = refreshMessage;
                            
                            // Add static built-in tools section (always available)
                            forceRefreshContent += `## 🔧 Static Built-in Tools (Always Available):\n`;
                            forceRefreshContent += `1. **pluggedin_discover_tools** - Triggers discovery of tools (and resources/templates) for configured MCP servers in the Pluggedin App\n`;
                            forceRefreshContent += `2. **pluggedin_rag_query** - Performs a RAG query against documents in the Pluggedin App\n`;
                            forceRefreshContent += `3. **pluggedin_send_notification** - Send custom notifications through the Plugged.in system with optional email delivery\n`;
                            forceRefreshContent += `\n`;
                            
                            // Add dynamic tools section (from MCP servers)
                            if (toolsCount > 0) {
                                const tools = toolsResponse.data?.tools || toolsResponse.data || [];
                                forceRefreshContent += `## ⚡ Dynamic MCP Tools (${toolsCount}) - From Connected Servers:\n`;
                                tools.forEach((tool: any, index: number) => {
                                    forceRefreshContent += `${index + 1}. **${tool.name}**`;
                                    if (tool.description) {
                                        forceRefreshContent += ` - ${tool.description}`;
                                    }
                                    forceRefreshContent += `\n`;
                                });
                                forceRefreshContent += `\n`;
                            } else {
                                forceRefreshContent += `## ⚡ Dynamic MCP Tools (0) - From Connected Servers:\n`;
                                forceRefreshContent += `No dynamic tools available. Add MCP servers to get more tools.\n\n`;
                            }
                            
                            // Add prompts section  
                            if (promptsCount > 0) {
                                forceRefreshContent += `## 💬 Available Prompts (${promptsCount}):\n`;
                                promptsResponse.data.forEach((prompt: any, index: number) => {
                                    forceRefreshContent += `${index + 1}. **${prompt.name}**`;
                                    if (prompt.description) {
                                        forceRefreshContent += ` - ${prompt.description}`;
                                    }
                                    forceRefreshContent += `\n`;
                                });
                                forceRefreshContent += `\n`;
                            }
                            
                            // Add resources section
                            if (resourcesCount > 0) {
                                forceRefreshContent += `## 📄 Available Resources (${resourcesCount}):\n`;
                                resourcesResponse.data.forEach((resource: any, index: number) => {
                                    forceRefreshContent += `${index + 1}. **${resource.name || resource.uri}**`;
                                    if (resource.description) {
                                        forceRefreshContent += ` - ${resource.description}`;
                                    }
                                    if (resource.uri && resource.name !== resource.uri) {
                                        forceRefreshContent += ` (${resource.uri})`;
                                    }
                                    forceRefreshContent += `\n`;
                                });
                                forceRefreshContent += `\n`;
                            }
                            
                            // Add templates section
                            if (templatesCount > 0) {
                                forceRefreshContent += `## 📋 Available Resource Templates (${templatesCount}):\n`;
                                templatesResponse.data.forEach((template: any, index: number) => {
                                    forceRefreshContent += `${index + 1}. **${template.name || template.uriTemplate}**`;
                                    if (template.description) {
                                        forceRefreshContent += ` - ${template.description}`;
                                    }
                                    if (template.uriTemplate && template.name !== template.uriTemplate) {
                                        forceRefreshContent += ` (${template.uriTemplate})`;
                                    }
                                    forceRefreshContent += `\n`;
                                });
                                forceRefreshContent += `\n`;
                            }
                            
                            forceRefreshContent += `📝 **Note**: Fresh discovery is running in background. Call pluggedin_discover_tools() again in 10-30 seconds to see if any new tools were discovered.`;

                        } catch (cacheError: any) {
                            // If we can't get cached data, just show static tools
                            forceRefreshContent = server_uuid 
                                ? `🔄 Force refresh initiated for server ${server_uuid}. Discovery is running in background.\n\nCould not retrieve cached data, showing static tools:\n\n`
                                : `🔄 Force refresh initiated for all servers. Discovery is running in background.\n\nCould not retrieve cached data, showing static tools:\n\n`;
                                
                            forceRefreshContent += `## 🔧 Static Built-in Tools (Always Available):\n`;
                            forceRefreshContent += `1. **pluggedin_discover_tools** - Triggers discovery of tools (and resources/templates) for configured MCP servers in the Pluggedin App\n`;
                            forceRefreshContent += `2. **pluggedin_rag_query** - Performs a RAG query against documents in the Pluggedin App\n`;
                            forceRefreshContent += `3. **pluggedin_send_notification** - Send custom notifications through the Plugged.in system with optional email delivery\n`;
                            forceRefreshContent += `\n📝 **Note**: Fresh discovery is running in background. Call pluggedin_discover_tools() again in 10-30 seconds to see updated results.`;
                        }

                        // Log successful trigger
                        logMcpActivity({
                            action: 'tool_call',
                            serverName: 'Discovery System (Background)',
                            serverUuid: 'pluggedin_discovery_bg',
                            itemName: requestedToolName,
                            success: true,
                            executionTime: timer.stop(),
                        }).catch(() => {}); // Ignore notification errors
                        
                        return {
                            content: [{ type: "text", text: forceRefreshContent }],
                            isError: false,
                        } as ToolExecutionResult;

                    } catch (triggerError: any) {
                        // Even trigger failed, return error
                        const errorMsg = `Failed to trigger background discovery: ${triggerError.message}`;
                        
                        // Log failed trigger
                        logMcpActivity({
                            action: 'tool_call',
                            serverName: 'Discovery System',
                            serverUuid: 'pluggedin_discovery',
                            itemName: requestedToolName,
                            success: false,
                            errorMessage: errorMsg,
                            executionTime: timer.stop(),
                        }).catch(() => {}); // Ignore notification errors
                        
                        throw new Error(errorMsg);
                    }
                } else {
                    // For regular discovery (no force refresh), wait for completion
                    try {
                        const discoveryResponse = await axios.post(discoveryApiUrl, {}, {
                            headers: { Authorization: `Bearer ${apiKey}` },
                            timeout: 30000, // 30s timeout for regular discovery
                        });

                        // Return success message from the discovery API response
                        const baseMessage = discoveryResponse.data?.message || "Discovery process initiated.";
                        const contextMessage = `${existingDataSummary}. ${baseMessage}\n\nNote: You can call pluggedin_discover_tools again to see the cached results including both static and dynamic tools.`;
                        
                        // Log successful discovery
                        logMcpActivity({
                            action: 'tool_call',
                            serverName: 'Discovery System',
                            serverUuid: 'pluggedin_discovery',
                            itemName: requestedToolName,
                            success: true,
                            executionTime: timer.stop(),
                        }).catch(() => {}); // Ignore notification errors
                        
                        return {
                            content: [{ type: "text", text: contextMessage }],
                            isError: false,
                        } as ToolExecutionResult;

                    } catch (apiError: any) {
                        // Log failed discovery
                        logMcpActivity({
                            action: 'tool_call',
                            serverName: 'Discovery System',
                            serverUuid: 'pluggedin_discovery',
                            itemName: requestedToolName,
                            success: false,
                            errorMessage: apiError instanceof Error ? apiError.message : String(apiError),
                            executionTime: timer.stop(),
                        }).catch(() => {}); // Ignore notification errors
                        
                         const errorMsg = axios.isAxiosError(apiError)
                            ? `API Error (${apiError.response?.status}): ${apiError.response?.data?.error || apiError.message}`
                            : apiError.message;
                         throw new Error(`Failed to trigger discovery via API: ${errorMsg}`);
                    }
                }
            }
        }

        // Handle static RAG query tool
        if (requestedToolName === ragQueryStaticTool.name) {
            debugError(`[CallTool Handler] Executing static tool: ${requestedToolName}`);
            const validatedArgs = RagQueryInputSchema.parse(args ?? {}); // Validate args

            const apiKey = getPluggedinMCPApiKey();
            const baseUrl = getPluggedinMCPApiBaseUrl();
            if (!apiKey || !baseUrl) {
                throw new Error("Pluggedin API Key or Base URL is not configured for RAG query.");
            }

            // Define the API endpoint in pluggedin-app for RAG queries
            const ragApiUrl = `${baseUrl}/api/rag/query`;
            const timer = createExecutionTimer();

            try {
                // Make POST request with RAG query (ragIdentifier removed for security)
                const ragResponse = await axios.post(ragApiUrl, {
                    query: validatedArgs.query,
                }, {
                    headers: { 
                        Authorization: `Bearer ${apiKey}`,
                        'Content-Type': 'application/json'
                    },
                    timeout: 15000, // Reduced timeout to prevent DoS
                    responseType: 'text' // Expect text response, not JSON
                });

                // The API returns plain text response
                const responseText = ragResponse.data || "No response generated";
                
                // Log successful RAG query
                logMcpActivity({
                    action: 'tool_call',
                    serverName: 'RAG System',
                    serverUuid: 'pluggedin_rag',
                    itemName: requestedToolName,
                    success: true,
                    executionTime: timer.stop(),
                }).catch(() => {}); // Ignore notification errors
                
                return {
                    content: [{ type: "text", text: responseText }],
                    isError: false,
                } as ToolExecutionResult; // Cast to expected type

            } catch (apiError: any) {
                 // Log failed RAG query
                 logMcpActivity({
                     action: 'tool_call',
                     serverName: 'RAG System',
                     serverUuid: 'pluggedin_rag',
                     itemName: requestedToolName,
                     success: false,
                     errorMessage: apiError instanceof Error ? apiError.message : String(apiError),
                     executionTime: timer.stop(),
                 }).catch(() => {}); // Ignore notification errors
                 
                 // Sanitized error message to prevent information disclosure
                 const errorMsg = axios.isAxiosError(apiError) && apiError.response?.status
                    ? `RAG service error (${apiError.response.status})`
                    : "RAG service temporarily unavailable";
                 throw new Error(errorMsg);
            }
        }

        // Handle static send notification tool
        if (requestedToolName === sendNotificationStaticTool.name) {
            debugError(`[CallTool Handler] Executing static tool: ${requestedToolName}`);
            const validatedArgs = SendNotificationInputSchema.parse(args ?? {}); // Validate args

            const apiKey = getPluggedinMCPApiKey();
            const baseUrl = getPluggedinMCPApiBaseUrl();
            if (!apiKey || !baseUrl) {
                throw new Error("Pluggedin API Key or Base URL is not configured for custom notifications.");
            }

            // Define the API endpoint in pluggedin-app for custom notifications
            const notificationApiUrl = `${baseUrl}/api/notifications/custom`;
            const timer = createExecutionTimer();

            try {
                // Make POST request with notification data
                const notificationResponse = await axios.post(notificationApiUrl, {
                    title: validatedArgs.title,
                    message: validatedArgs.message,
                    severity: validatedArgs.severity,
                    sendEmail: validatedArgs.sendEmail,
                }, {
                    headers: { 
                        Authorization: `Bearer ${apiKey}`,
                        'Content-Type': 'application/json'
                    },
                    timeout: 30000, // Increased timeout for notifications
                });

                // The API returns success confirmation
                const responseData = notificationResponse.data;
                const responseText = responseData?.message || "Notification sent successfully";
                
                // Log successful notification
                logMcpActivity({
                    action: 'tool_call',
                    serverName: 'Notification System',
                    serverUuid: 'pluggedin_notifications',
                    itemName: requestedToolName,
                    success: true,
                    executionTime: timer.stop(),
                }).catch(() => {}); // Ignore notification errors
                
                return {
                    content: [{ type: "text", text: responseText }],
                    isError: false,
                } as ToolExecutionResult; // Cast to expected type

            } catch (apiError: any) {
                 // Log failed notification
                 logMcpActivity({
                     action: 'tool_call',
                     serverName: 'Notification System',
                     serverUuid: 'pluggedin_notifications',
                     itemName: requestedToolName,
                     success: false,
                     errorMessage: apiError instanceof Error ? apiError.message : String(apiError),
                     executionTime: timer.stop(),
                 }).catch(() => {}); // Ignore notification errors
                 
                 // Sanitized error message
                 const errorMsg = axios.isAxiosError(apiError) && apiError.response?.status
                    ? `Notification service error (${apiError.response.status})`
                    : "Notification service temporarily unavailable";
                 throw new Error(errorMsg);
            }
        }

        // Look up the downstream tool in our map
        const toolInfo = toolToServerMap[requestedToolName];
        if (!toolInfo) {
            throw new Error(`Tool not found: ${requestedToolName}`);
        }

        const { originalName, serverUuid } = toolInfo;

        // Basic server UUID validation
        if (!serverUuid || typeof serverUuid !== 'string') {
            throw new Error("Invalid server UUID");
        }

        // Get the downstream server session
        const serverParams = await getMcpServers(true);
        
        const params = serverParams[serverUuid];
        if (!params) {
            throw new Error(`Configuration not found for server UUID: ${serverUuid} associated with tool ${requestedToolName}`);
        }
        const sessionKey = getSessionKey(serverUuid, params);
        const session = await getSession(sessionKey, serverUuid, params);

        if (!session) {
            throw new Error(`Session not found for server UUID: ${serverUuid}`);
        }

        // Proxy the call to the downstream server using the original tool name
        debugError(`[CallTool Proxy] Calling tool '${originalName}' on server ${serverUuid}`);
        const timer = createExecutionTimer();
        
        try {
            const result = await session.client.request(
                { method: "tools/call", params: { name: originalName, arguments: args, _meta: meta } },
                 CompatibilityCallToolResultSchema
            );

            // Log successful tool call
            logMcpActivity({
                action: 'tool_call',
                serverName: params.name || serverUuid,
                serverUuid,
                itemName: originalName,
                success: true,
                executionTime: timer.stop(),
            }).catch(() => {}); // Ignore notification errors

            // Return the result directly, casting to any to satisfy the handler's complex return type
            return result as any;
        } catch (toolError) {
            // Log failed tool call
            logMcpActivity({
                action: 'tool_call',
                serverName: params.name || serverUuid,
                serverUuid,
                itemName: originalName,
                success: false,
                errorMessage: toolError instanceof Error ? toolError.message : String(toolError),
                executionTime: timer.stop(),
            }).catch(() => {}); // Ignore notification errors
            
            // Re-throw the original error
            throw toolError;
        }

    } catch (error) {
      const sanitizedError = sanitizeErrorMessage(error);
      // Use requestedToolName here, which is in scope
      debugError(`[CallTool Handler Error] Tool: ${requestedToolName || 'unknown'}, Error: ${sanitizedError}`);

      // Re-throw the error for the SDK to format and send back to the client
      if (error instanceof Error) {
         // Create a new error with sanitized message to prevent info disclosure
         throw new Error(sanitizedError);
      } else {
         throw new Error(sanitizedError || "An unknown error occurred during tool execution");
      }
    }
  });

  // Get Prompt Handler - Handles static prompts, custom instructions, and standard prompts
  server.setRequestHandler(GetPromptRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;
    const meta = request.params._meta;
    const instructionPrefix = 'pluggedin_instruction_';

    // Handle static proxy capabilities prompt first
    if (name === proxyCapabilitiesStaticPrompt.name) {
      const timer = createExecutionTimer();
      
      try {
        // Log successful static prompt retrieval
        logMcpActivity({
          action: 'prompt_get',
          serverName: 'Proxy System',
          serverUuid: 'pluggedin_proxy',
          itemName: name,
          success: true,
          executionTime: timer.stop(),
        }).catch(() => {}); // Ignore notification errors
        
        return {
          messages: [
            {
              role: "user",
              content: {
                type: "text",
                text: `# Plugged.in MCP Proxy Capabilities

The Plugged.in MCP Proxy is a powerful gateway that provides access to multiple MCP servers and built-in tools. Here's what you can do:

## 🔧 Built-in Static Tools

### 1. **pluggedin_discover_tools**
- **Purpose**: Trigger discovery of tools and resources from configured MCP servers
- **Parameters**: 
  - \`server_uuid\` (optional): Discover from specific server, or all servers if omitted
  - \`force_refresh\` (optional): Set to true to trigger background discovery and return immediately (defaults to false)
- **Usage**: Returns cached data instantly if available. Use \`force_refresh=true\` to update data in background, then call again without force_refresh to see results.

### 2. **pluggedin_rag_query**
- **Purpose**: Perform RAG (Retrieval-Augmented Generation) queries against your documents
- **Parameters**:
  - \`query\` (required): The search query (1-1000 characters)
- **Usage**: Search through uploaded documents and knowledge base

### 3. **pluggedin_send_notification**
- **Purpose**: Send custom notifications through the Plugged.in system
- **Parameters**:
  - \`message\` (required): The notification message content
  - \`severity\` (optional): INFO, SUCCESS, WARNING, or ALERT (defaults to INFO)
  - \`sendEmail\` (optional): Whether to also send via email (defaults to false)
- **Usage**: Create custom notifications with optional email delivery

## 🔗 Proxy Features

### MCP Server Management
- **Auto-discovery**: Automatically discovers tools, prompts, and resources from configured servers
- **Session Management**: Maintains persistent connections to downstream MCP servers
- **Error Handling**: Graceful error handling and recovery for server connections

### Authentication & Security
- **API Key Authentication**: Secure access using your Plugged.in API key
- **Profile-based Access**: All operations are scoped to your active profile
- **Audit Logging**: All MCP activities are logged for monitoring and debugging

### Notification System
- **Activity Tracking**: Automatic logging of all MCP operations (tools, prompts, resources)
- **Performance Metrics**: Execution timing for all operations
- **Custom Notifications**: Send custom notifications with email delivery options

## 🚀 Getting Started

1. **Configure Environment**: Set \`PLUGGEDIN_API_KEY\` and \`PLUGGEDIN_API_BASE_URL\`
2. **Discover Tools**: Run \`pluggedin_discover_tools\` to see available tools from your servers
3. **Use Tools**: Call any discovered tool through the proxy
4. **Query Documents**: Use \`pluggedin_rag_query\` to search your knowledge base
5. **Send Notifications**: Use \`pluggedin_send_notification\` for custom alerts

## 📊 Monitoring

- Check the Plugged.in app notifications to see MCP activity logs
- Monitor execution times and success rates
- View custom notifications in the notification center

The proxy acts as a unified gateway to all your MCP capabilities while providing enhanced features like RAG, notifications, and comprehensive logging.`
              }
            }
          ]
        };
      } catch (error) {
        // Log failed static prompt retrieval
        logMcpActivity({
          action: 'prompt_get',
          serverName: 'Proxy System',
          serverUuid: 'pluggedin_proxy',
          itemName: name,
          success: false,
          errorMessage: error instanceof Error ? error.message : String(error),
          executionTime: timer.stop(),
        }).catch(() => {}); // Ignore notification errors
        
        throw error;
      }
    }

    try {
      const apiKey = getPluggedinMCPApiKey();
      const baseUrl = getPluggedinMCPApiBaseUrl();
      if (!apiKey || !baseUrl) {
        throw new Error("Pluggedin API Key or Base URL is not configured.");
      }

      if (name.startsWith(instructionPrefix)) {
        // --- Handle Custom Instruction Request ---
        debugError(`[GetPrompt Handler] Detected custom instruction prefix for: ${name}`);
        const serverUuid = instructionToServerMap[name];
        debugError(`[GetPrompt Handler] Looked up serverUuid from instructionToServerMap: ${serverUuid}`); // Log UUID lookup
        if (!serverUuid) {
           debugError(`[GetPrompt Handler] Current instructionToServerMap:`, JSON.stringify(instructionToServerMap)); // Log the map content
          throw new Error(`Server UUID not found in map for custom instruction: ${name}. Try listing prompts again.`);
        }

        // Call the new app API endpoint to get instruction details
        // This endpoint needs to be created: /api/custom-instructions/[uuid]
        const instructionApiUrl = `${baseUrl}/api/custom-instructions/${serverUuid}`;
        debugError(`[GetPrompt Handler] Fetching instruction details from: ${instructionApiUrl}`);

        const timer = createExecutionTimer();
        
        try {
          // Expecting the API to return { messages: PromptMessage[] }
          const response = await axios.get<{ messages: PromptMessage[] }>(instructionApiUrl, {
            headers: { Authorization: `Bearer ${apiKey}` },
            timeout: 10000,
          });

          const instructionData = response.data;
          if (!instructionData || !Array.isArray(instructionData.messages)) {
             throw new Error(`Invalid response format from ${instructionApiUrl}`);
          }

          // Log successful custom instruction retrieval
          logMcpActivity({
            action: 'prompt_get',
            serverName: 'Custom Instructions',
            serverUuid,
            itemName: name,
            success: true,
            executionTime: timer.stop(),
          }).catch(() => {}); // Ignore notification errors

          // Construct the GetPromptResult directly in the proxy
          return {
            messages: instructionData.messages,
          } as z.infer<typeof GetPromptResultSchema>; // Ensure correct type

        } catch (apiError: any) {
           const errorMsg = axios.isAxiosError(apiError)
              ? `API Error (${apiError.response?.status}) fetching instruction ${name}: ${apiError.response?.data?.error || apiError.message}`
              : apiError.message;
              
           // Log failed custom instruction retrieval
           logMcpActivity({
             action: 'prompt_get',
             serverName: 'Custom Instructions',
             serverUuid,
             itemName: name,
             success: false,
             errorMessage: errorMsg,
             executionTime: timer.stop(),
           }).catch(() => {}); // Ignore notification errors
           
           throw new Error(`Failed to fetch custom instruction details: ${errorMsg}`);
        }

      } else {
        // --- Handle Standard Prompt Request (Existing Logic) ---
        debugError(`[GetPrompt Handler] No custom instruction prefix detected for: ${name}. Proceeding with standard prompt resolution.`);
        // 1. Call the resolve API endpoint to find which server has this prompt
        const resolveApiUrl = `${baseUrl}/api/resolve/prompt?name=${encodeURIComponent(name)}`;
         debugError(`[GetPrompt Handler] Calling resolve API: ${resolveApiUrl}`); // Log API call
        const resolveResponse = await axios.get<{uuid: string}>(resolveApiUrl, {
          headers: { Authorization: `Bearer ${apiKey}` },
          timeout: 10000,
        });

        const resolvedData = resolveResponse.data;
        if (!resolvedData || !resolvedData.uuid) {
          throw new Error(`Could not resolve server details for prompt name: ${name}`);
        }

        // 2. Get FRESH server configuration using the same method as tools
        const serverParamsMap = await getMcpServers(true);
        const serverParams = serverParamsMap[resolvedData.uuid];
        
        if (!serverParams) {
          throw new Error(`Configuration not found for server UUID: ${resolvedData.uuid} associated with prompt ${name}`);
        }

        // 3. Get the downstream server session using fresh config
        const sessionKey = getSessionKey(serverParams.uuid, serverParams);
        const session = await getSession(sessionKey, serverParams.uuid, serverParams);

        if (!session) {
          debugError(`[GetPrompt Handler] Session not found for ${serverParams.uuid}, attempting re-init...`);
          await initSessions();
          const refreshedSession = await getSession(sessionKey, serverParams.uuid, serverParams);
          if (!refreshedSession) {
            throw new Error(`Session could not be established for server UUID: ${serverParams.uuid} handling prompt: ${name}`);
          }
          // Use the refreshed session
          debugError(`[GetPrompt Handler] Proxying get request for prompt '${name}' to server ${serverParams.name || serverParams.uuid}`);
          const timer = createExecutionTimer();
          
          try {
            const result = await refreshedSession.client.request(
              { method: "prompts/get", params: { name, arguments: args, _meta: meta } },
              GetPromptResultSchema
            );
            
            // Log successful prompt retrieval
            logMcpActivity({
              action: 'prompt_get',
              serverName: serverParams.name || serverParams.uuid,
              serverUuid: serverParams.uuid,
              itemName: name,
              success: true,
              executionTime: timer.stop(),
            }).catch(() => {}); // Ignore notification errors
            
            return result;
          } catch (promptError) {
            // Log failed prompt retrieval
            logMcpActivity({
              action: 'prompt_get',
              serverName: serverParams.name || serverParams.uuid,
              serverUuid: serverParams.uuid,
              itemName: name,
              success: false,
              errorMessage: promptError instanceof Error ? promptError.message : String(promptError),
              executionTime: timer.stop(),
            }).catch(() => {}); // Ignore notification errors
            
            throw promptError;
          }
        } else {
          // Use the existing session
          debugError(`[GetPrompt Handler] Proxying get request for prompt '${name}' to server ${serverParams.name || serverParams.uuid}`);
          const timer = createExecutionTimer();
          
          try {
            const result = await session.client.request(
              { method: "prompts/get", params: { name, arguments: args, _meta: meta } },
              GetPromptResultSchema
            );
            
            // Log successful prompt retrieval
            logMcpActivity({
              action: 'prompt_get',
              serverName: serverParams.name || serverParams.uuid,
              serverUuid: serverParams.uuid,
              itemName: name,
              success: true,
              executionTime: timer.stop(),
            }).catch(() => {}); // Ignore notification errors
            
            return result;
          } catch (promptError) {
            // Log failed prompt retrieval
            logMcpActivity({
              action: 'prompt_get',
              serverName: serverParams.name || serverParams.uuid,
              serverUuid: serverParams.uuid,
              itemName: name,
              success: false,
              errorMessage: promptError instanceof Error ? promptError.message : String(promptError),
              executionTime: timer.stop(),
            }).catch(() => {}); // Ignore notification errors
            
            throw promptError;
          }
        }
      }
    } catch (error: any) {
      const errorMessage = axios.isAxiosError(error)
        ? `API Error (${error.response?.status}) resolving/getting prompt ${name}: ${error.response?.data?.error || error.message}`
        : error instanceof Error
        ? error.message
        : `Unknown error getting prompt: ${name}`;
      debugError("[GetPrompt Handler Error]", errorMessage);
      throw new Error(`Failed to get prompt ${name}: ${errorMessage}`);
    }
  });

  // List Prompts Handler - Fetches aggregated list from Pluggedin App API
  server.setRequestHandler(ListPromptsRequestSchema, async (request) => {
    try {
      const apiKey = getPluggedinMCPApiKey();
      const baseUrl = getPluggedinMCPApiBaseUrl();
      if (!apiKey || !baseUrl) {
        throw new Error("Pluggedin API Key or Base URL is not configured.");
      }

      const promptsApiUrl = `${baseUrl}/api/prompts`;
      const customInstructionsApiUrl = `${baseUrl}/api/custom-instructions`; // New endpoint for custom instructions

      // Fetch both standard prompts and custom instructions concurrently
      const [promptsResponse, customInstructionsResponse] = await Promise.all([
        axios.get<z.infer<typeof ListPromptsResultSchema>["prompts"]>(promptsApiUrl, {
          headers: { Authorization: `Bearer ${apiKey}` },
          timeout: 10000,
        }),
        axios.get<z.infer<typeof ListPromptsResultSchema>["prompts"]>(customInstructionsApiUrl, { // Assuming custom instructions API returns the same format
          headers: { Authorization: `Bearer ${apiKey}` },
          timeout: 10000,
        })
      ]);

      const standardPrompts = promptsResponse.data || [];
      const customInstructionsAsPrompts = customInstructionsResponse.data || [];

      // Clear previous instruction mapping and populate with new data
      Object.keys(instructionToServerMap).forEach(key => delete instructionToServerMap[key]); // Clear map
      customInstructionsAsPrompts.forEach(instr => {
        if (instr.name && instr._serverUuid) {
          // Assert _serverUuid as string since the check ensures it's not undefined
          instructionToServerMap[instr.name] = instr._serverUuid as string;
        } else {
            debugError(`[ListPrompts Handler] Missing name or _serverUuid for custom instruction:`, instr);
        }
      });

      // Merge the results (Remove internal _serverUuid from custom instructions before sending to client)
      const allPrompts = [
          proxyCapabilitiesStaticPrompt, // Add static proxy capabilities prompt
          ...standardPrompts,
          ...customInstructionsAsPrompts.map(({ _serverUuid, ...rest }) => rest)
      ];

      // Wrap the combined array in the expected structure for the MCP response
      // Note: Pagination not handled here
      return { prompts: allPrompts, nextCursor: undefined };

    } catch (error: any) {
      const errorMessage = axios.isAxiosError(error)
        ? `API Error (${error.response?.status}): ${error.message}`
        : error instanceof Error
        ? error.message
        : "Unknown error fetching prompts or custom instructions from API";
      debugError("[ListPrompts Handler Error]", errorMessage);
      // Let SDK handle error formatting
      throw new Error(`Failed to list prompts: ${errorMessage}`);
    }
  });


  // List Resources Handler - Fetches aggregated list from Pluggedin App API
  server.setRequestHandler(ListResourcesRequestSchema, async (request) => {
    try {
      const apiKey = getPluggedinMCPApiKey();
      const baseUrl = getPluggedinMCPApiBaseUrl();
      if (!apiKey || !baseUrl) {
        throw new Error("Pluggedin API Key or Base URL is not configured.");
      }

      const apiUrl = `${baseUrl}/api/resources`; // Assuming this is the correct endpoint

      // debugError(`[Proxy - ListResources] Fetching from ${apiUrl}`); // Debug log

      const response = await axios.get<z.infer<typeof ListResourcesResultSchema>["resources"]>(apiUrl, {
        headers: {
          Authorization: `Bearer ${apiKey}`,
        },
        timeout: 10000, // Add a timeout for the API call (e.g., 10 seconds)
      });

      // The API currently returns just the array, wrap it in the expected structure
      const resources = response.data || [];

      // debugError(`[Proxy - ListResources] Received ${resources.length} resources from API.`); // Debug log

      // Note: Pagination across servers via the API is not implemented here.
      // The API would need to support cursor-based pagination for this to work fully.
      return { resources: resources, nextCursor: undefined };

    } catch (error: any) {
      const errorMessage = axios.isAxiosError(error)
        ? `API Error (${error.response?.status}): ${error.message}`
        : error instanceof Error
        ? error.message
        : "Unknown error fetching resources from API";
      debugError("[ListResources Handler Error]", errorMessage);
      // Let SDK handle error formatting
      throw new Error(`Failed to list resources: ${errorMessage}`);
    }
  });

  // Read Resource Handler - Simplified to only proxy
  // WARNING: This handler will likely fail now because resourceToClient is no longer populated.
  // It needs to be refactored to proxy the read request to the correct downstream server,
  // potentially by calling a new API endpoint on pluggedin-app or by re-establishing a session.
  // Refactored Read Resource Handler - Uses API to resolve URI to server details
  server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
    const { uri } = request.params;
    const meta = request.params._meta; // Pass meta along

    try {
        const apiKey = getPluggedinMCPApiKey();
        const baseUrl = getPluggedinMCPApiBaseUrl();
        if (!apiKey || !baseUrl) {
            throw new Error("Pluggedin API Key or Base URL is not configured for resource resolution.");
        }

        // 1. Call the new API endpoint to resolve the URI
        const resolveApiUrl = `${baseUrl}/api/resolve/resource?uri=${encodeURIComponent(uri)}`;
        // debugError(`[ReadResource Handler] Resolving URI via: ${resolveApiUrl}`); // Optional debug log

        const resolveResponse = await axios.get<ServerParameters>(resolveApiUrl, { // Expect ServerParameters type
            headers: { Authorization: `Bearer ${apiKey}` },
            timeout: 10000, // Timeout for resolution call
        });

        const serverParams = resolveResponse.data;
        if (!serverParams || !serverParams.uuid) {
            throw new Error(`Could not resolve server details for URI: ${uri}`);
        }

        // 2. Get the downstream server session using resolved details
        const sessionKey = getSessionKey(serverParams.uuid, serverParams);
        // Ensure session is established before proceeding
        const session = await getSession(sessionKey, serverParams.uuid, serverParams);

        if (!session) {
            // Attempt to re-initialize sessions if not found (might happen on proxy restart)
            // This is a potential area for improvement (e.g., caching serverParams)
            debugError(`[ReadResource Handler] Session not found for ${serverParams.uuid}, attempting re-init...`);
            await initSessions(); // Re-initialize all sessions
            const refreshedSession = await getSession(sessionKey, serverParams.uuid, serverParams);
            if (!refreshedSession) {
               throw new Error(`Session could not be established for server UUID: ${serverParams.uuid} handling URI: ${uri}`);
            }
             // Use the refreshed session
             debugError(`[ReadResource Handler] Proxying read request for URI '${uri}' to server ${serverParams.name || serverParams.uuid}`);
             const timer = createExecutionTimer();
             
             try {
               const result = await refreshedSession.client.request(
                   { method: "resources/read", params: { uri, _meta: meta } }, // Pass original URI and meta
                   ReadResourceResultSchema
               );
               
               // Log successful resource read
               logMcpActivity({
                 action: 'resource_read',
                 serverName: serverParams.name || serverParams.uuid,
                 serverUuid: serverParams.uuid,
                 itemName: uri,
                 success: true,
                 executionTime: timer.stop(),
               }).catch(() => {}); // Ignore notification errors
               
               return result;
             } catch (resourceError) {
               // Log failed resource read
               logMcpActivity({
                 action: 'resource_read',
                 serverName: serverParams.name || serverParams.uuid,
                 serverUuid: serverParams.uuid,
                 itemName: uri,
                 success: false,
                 errorMessage: resourceError instanceof Error ? resourceError.message : String(resourceError),
                 executionTime: timer.stop(),
               }).catch(() => {}); // Ignore notification errors
               
               throw resourceError;
             }
        } else {
             // Use the existing session
             debugError(`[ReadResource Handler] Proxying read request for URI '${uri}' to server ${serverParams.name || serverParams.uuid}`);
             const timer = createExecutionTimer();
             
             try {
               const result = await session.client.request(
                   { method: "resources/read", params: { uri, _meta: meta } }, // Pass original URI and meta
                   ReadResourceResultSchema
               );
               
               // Log successful resource read
               logMcpActivity({
                 action: 'resource_read',
                 serverName: serverParams.name || serverParams.uuid,
                 serverUuid: serverParams.uuid,
                 itemName: uri,
                 success: true,
                 executionTime: timer.stop(),
               }).catch(() => {}); // Ignore notification errors
               
               return result;
             } catch (resourceError) {
               // Log failed resource read
               logMcpActivity({
                 action: 'resource_read',
                 serverName: serverParams.name || serverParams.uuid,
                 serverUuid: serverParams.uuid,
                 itemName: uri,
                 success: false,
                 errorMessage: resourceError instanceof Error ? resourceError.message : String(resourceError),
                 executionTime: timer.stop(),
               }).catch(() => {}); // Ignore notification errors
               
               throw resourceError;
             }
        }

    } catch (error: any) {
        const errorMessage = axios.isAxiosError(error)
            ? `API Error (${error.response?.status}) resolving URI ${uri}: ${error.response?.data?.error || error.message}`
            : error instanceof Error
            ? error.message
            : `Unknown error reading resource URI: ${uri}`;
        debugError("[ReadResource Handler Error]", errorMessage);
        // Let SDK handle error formatting
        throw new Error(`Failed to read resource ${uri}: ${errorMessage}`);
    }
  });

  // List Resource Templates Handler - Fetches aggregated list from Pluggedin App API
  server.setRequestHandler(ListResourceTemplatesRequestSchema, async (request) => {
    try {
      const apiKey = getPluggedinMCPApiKey();
      const baseUrl = getPluggedinMCPApiBaseUrl();
      if (!apiKey || !baseUrl) {
        throw new Error("Pluggedin API Key or Base URL is not configured.");
      }

      const apiUrl = `${baseUrl}/api/resource-templates`; // New endpoint

      // debugError(`[Proxy - ListResourceTemplates] Fetching from ${apiUrl}`); // Debug log

      // Fetch the list of templates
      // Assuming the API returns ResourceTemplate[] directly
      const response = await axios.get<ResourceTemplate[]>(apiUrl, {
        headers: {
          Authorization: `Bearer ${apiKey}`,
        },
        timeout: 10000, // Add a timeout
      });

      const templates = response.data || [];

      // debugError(`[Proxy - ListResourceTemplates] Received ${templates.length} templates from API.`); // Debug log

      // Wrap the array in the expected structure for the MCP response
      return { resourceTemplates: templates, nextCursor: undefined }; // Pagination not handled

    } catch (error: any) {
      const errorMessage = axios.isAxiosError(error)
        ? `API Error (${error.response?.status}): ${error.message}`
        : error instanceof Error
        ? error.message
        : "Unknown error fetching resource templates from API";
      debugError("[ListResourceTemplates Handler Error]", errorMessage);
      // Let SDK handle error formatting
      throw new Error(`Failed to list resource templates: ${errorMessage}`);
    }
  });

  // Ping Handler - Responds to simple ping requests
  server.setRequestHandler(PingRequestSchema, async (request) => {
    debugError("[Ping Handler] Received ping request.");
    
    // Basic health information
    const healthInfo = {
      status: "ok",
      timestamp: new Date().toISOString(),
      version: packageJson.version,
      sessions: Object.keys(toolToServerMap).length,
      memory: process.memoryUsage(),
      uptime: process.uptime()
    };
    
    debugLog("[Ping Handler] Health check:", healthInfo);
    
    // Return empty object for MCP spec compliance, but log health info
    return {};
  });

  const cleanup = async () => {
    try {
      // Clean up sessions
      await cleanupAllSessions();
      
      // Clear tool mappings
      Object.keys(toolToServerMap).forEach(key => delete toolToServerMap[key]);
      Object.keys(instructionToServerMap).forEach(key => delete instructionToServerMap[key]);
      
      // Reset rate limiters
      toolCallRateLimiter.reset();
      apiCallRateLimiter.reset();
      
      debugLog("[Proxy Cleanup] All resources cleaned up successfully");
    } catch (error) {
      debugError("[Proxy Cleanup] Error during cleanup:", error);
    }
  };

  return { server, cleanup };
};
