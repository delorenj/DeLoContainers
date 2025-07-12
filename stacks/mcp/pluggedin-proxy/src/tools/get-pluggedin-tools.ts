import { z } from "zod";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
  Tool,
  // ListToolsResultSchema, // No longer needed for live discovery
  // CompatibilityCallToolResultSchema, // Keep for reference, but execute returns string now
} from "@modelcontextprotocol/sdk/types.js";
// import { getMcpServers, ServerParameters } from "../fetch-pluggedinmcp.js"; // No longer needed
import { getPluggedinMCPApiKey, getPluggedinMCPApiBaseUrl } from "../utils.js"; // Import API utils
// import { getSessionKey, sanitizeName } from "../utils.js"; // No longer needed
// import { getSession } from "../sessions.js"; // No longer needed
// import { reportToolsToPluggedinMCP } from "../report-tools.js"; // No longer needed
// import { getInactiveTools, ToolParameters } from "../fetch-tools.js"; // No longer needed
// import {
//   getProfileCapabilities,
//   ProfileCapability,
// } from "../fetch-capabilities.js"; // No longer needed
import axios from "axios"; // Import axios
// import { logger } from "../logging.js"; // No longer needed, get from container
// import { Cache } from "../cache.js"; // Removed Cache
// import { container } from "../di-container.js"; // Removed DI container
// import { Logger } from "../logging.js"; // Removed Logger type
// import { ToolPlugin, pluginRegistry } from "../plugin-system.js"; // Removed Plugin System
import { ToolExecutionResult } from "../types.js"; // Import execution result type

// Removed Cache related definitions

const toolName = "get_tools";
const toolDescription = `
Retrieves the list of currently active and available proxied MCP tools managed by PluggedinMCP.
Use this tool first to discover which tools (like 'github__create_issue', 'google_calendar__list_events', etc.) are available before attempting to call them with 'tool_call'.
Requires a valid PluggedinMCP API key configured in the environment.
`;

const GetPluggedinToolsSchema = z.object({});

// Removed logger
// Removed Cache instance

/**
 * Helper function to fetch server names from the pluggedin-app API.
 * Used for prefixing tool names. Returns an empty object on failure.
 * @param apiBaseUrl - The base URL of the pluggedin-app API.
 * @param apiKey - The API key for authentication.
 * @returns A promise resolving to a record mapping server UUIDs to server names.
 */
async function _fetchServerNames(apiBaseUrl: string, apiKey: string): Promise<Record<string, string>> {
  const serverNames: Record<string, string> = {};
  try {
    // logger.debug("Fetching server names for tool prefixing..."); // Removed logging
    const serversResponse = await axios.get(
      `${apiBaseUrl}/api/mcp-servers`, // Assuming this endpoint exists
      { headers: { Authorization: `Bearer ${apiKey}` } }
    );
    if (serversResponse.data && typeof serversResponse.data === 'object') {
      Object.entries(serversResponse.data).forEach(([uuid, serverData]: [string, any]) => {
        if (serverData && serverData.name) {
          serverNames[uuid] = serverData.name;
        }
      });
      // logger.debug(`Fetched ${Object.keys(serverNames).length} server names.`); // Removed logging
    } else {
      // logger.warn("Invalid response structure from /api/mcp-servers when fetching names."); // Removed logging
    }
  } catch (serverFetchError) {
    // logger.error("Error fetching server names for prefixing:", serverFetchError); // Removed logging
    // Proceed without prefixing if server names cannot be fetched, returning empty map
  }
  return serverNames;
}

/**
 * Implementation for the 'get_tools' static tool.
 * Fetches the list of available proxied tools from the pluggedin-app API.
 */
// Removed ToolPlugin interface implementation
export class GetPluggedinToolsTool {
  readonly name = toolName;
  readonly description = toolDescription;
  readonly inputSchema = GetPluggedinToolsSchema;

  // Removed static invalidateCache method

  /**
   * Executes the 'get_tools' logic.
   * Always fetches tools directly from the API.
   * Prefixes tool names with their server names (fetched separately).
   * @param args - Validated input arguments (empty object for this tool).
   * @param meta - Optional request metadata (not used by this tool).
   * @returns A promise resolving to a ToolExecutionResult containing the JSON stringified list of tool names.
   */
  async execute(
    args: z.infer<typeof GetPluggedinToolsSchema>,
    meta?: any
  ): Promise<ToolExecutionResult> {

    const apiKey = getPluggedinMCPApiKey();
    const apiBaseUrl = getPluggedinMCPApiBaseUrl();

    if (!apiKey || !apiBaseUrl) {
      // logger.error("PLUGGEDIN_API_KEY or PLUGGEDIN_API_BASE_URL is missing for get_tools."); // Removed logging
      // Return error structure matching ToolExecutionResult
      return {
        isError: true,
        content: [{ type: "text", text: "Configuration Error: Missing API Key or Base URL." }],
      };
    }

    // Removed cache check logic

    // logger.debug("Fetching tools from API..."); // Removed logging

    try {
      // Fetch tools directly from API
      const response = await axios.get(
        `${apiBaseUrl}/api/tools`, // Endpoint that returns all tools for the profile
        {
          headers: {
            Authorization: `Bearer ${apiKey}`,
          },
        }
      );

      // Check if the response structure is as expected
      if (!response.data || !Array.isArray(response.data.results)) {
        // logger.error("Invalid response structure received from /api/tools:", response.data); // Removed logging
        // Return error structure matching ToolExecutionResult
        return {
          isError: true,
          content: [{ type: "text", text: "Error: Invalid response from API." }],
        };
      }

      // The API returns tool objects, we need to extract the names
      // Assuming the API returns objects with a 'name' and 'mcp_server_uuid'
      // We now receive full tool details including description and toolSchema
      
      // Fetch server names using the helper function for grouping/keying
      const serverNames = await _fetchServerNames(apiBaseUrl, apiKey);
      const sanitize = (name: string) => name.replace(/[^a-zA-Z0-9_]/g, "_").toLowerCase();

      // Define the expected structure from the API based on the previous change
      const toolsFromApi: Array<{
        name: string;
        mcp_server_uuid: string;
        description?: string | null; // Allow null description
        toolSchema?: any; // JSON schema object
        status: string; // Assuming status is returned
      }> = response.data.results;

      // Build a flattened tool object without server prefixes
      const flattenedTools: Record<string, any> = {};

      toolsFromApi.forEach(tool => {
        // Store the server UUID in a hidden field for the tool_call function to use
        const serverUuid = tool.mcp_server_uuid;
        
        // Use just the tool name as the key without any server prefix
        flattenedTools[tool.name] = {
          type: "function",
          function: {
            name: tool.name,
            description: tool.description ?? `Tool ${tool.name}`,
            parameters: tool.toolSchema || { type: "object", properties: {} },
            // Add a hidden field with the server UUID that won't be visible in the UI
            // but can be used by the tool_call function
            _serverUuid: serverUuid
          }
        };
      });

      // Return the stringified flattened tool object
      // Don't wrap in a top-level "tools" key to avoid the empty {} issue
      const resultString = JSON.stringify(flattenedTools, null, 2);

      // Removed caching logic

      // Return success structure matching ToolExecutionResult
      return {
        content: [{ type: "text", text: resultString }],
      };

    } catch (error) {
      // logger.error("Error fetching tools via /api/tools:", error); // Removed logging
      // Return error structure matching ToolExecutionResult
      const errorMessage = error instanceof Error ? error.message : String(error);
      return {
        isError: true,
        content: [{ type: "text", text: `API Error: ${errorMessage}` }],
      };
    }
  }
}

// Removed plugin registration
