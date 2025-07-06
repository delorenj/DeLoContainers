import axios from 'axios';
import { getPluggedinMCPApiKey, getPluggedinMCPApiBaseUrl } from './utils.js';
import { debugError } from './debug-log.js';

export interface McpActivityData {
  action: 'tool_call' | 'prompt_get' | 'resource_read';
  serverName: string;
  serverUuid: string;
  itemName: string;
  success: boolean;
  errorMessage?: string;
  executionTime?: number;
}

/**
 * Log MCP server activity to the pluggedin-app notification system
 */
export async function logMcpActivity(data: McpActivityData): Promise<void> {
  // Use debugError for all logging to avoid interfering with stdout JSON-RPC protocol
  debugError(`[Notification Logger] Attempting to log activity:`, JSON.stringify(data, null, 2));
  
  try {
    const apiKey = getPluggedinMCPApiKey();
    const baseUrl = getPluggedinMCPApiBaseUrl();
    
    debugError(`[Notification Logger] Configuration - API Key: ${apiKey ? 'SET' : 'NOT SET'}, Base URL: ${baseUrl || 'NOT SET'}`);
    
    if (!apiKey || !baseUrl) {
      debugError('[Notification Logger] API key or base URL not configured, skipping notification');
      return;
    }

    const notificationUrl = `${baseUrl}/api/notifications/mcp-activity`;
    debugError(`[Notification Logger] Sending POST to: ${notificationUrl}`);
    
    const response = await axios.post(notificationUrl, data, {
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      timeout: 5000, // Short timeout for notifications
    });

    debugError(`[Notification Logger] ✅ Successfully logged ${data.action} for ${data.itemName}`);
    debugError(`[Notification Logger] Response status: ${response.status}, data:`, response.data);
  } catch (error) {
    // Don't throw errors for notification logging failures
    debugError('[Notification Logger] ❌ Failed to log MCP activity:', 
      axios.isAxiosError(error) 
        ? `Status: ${error.response?.status}, Data: ${JSON.stringify(error.response?.data)}` 
        : error instanceof Error 
          ? error.message 
          : String(error)
    );
  }
}

/**
 * Helper function to measure execution time
 */
export function createExecutionTimer() {
  const startTime = Date.now();
  
  return {
    stop: () => Date.now() - startTime,
  };
} 