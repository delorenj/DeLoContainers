# MCP Activity Notifications

The plugged.in MCP proxy automatically logs notifications for all MCP server activities to help users track and monitor their MCP usage.

## What Gets Logged

The proxy logs notifications for three types of MCP operations:

- **Tool Calls**: When tools are executed via `tools/call`
- **Prompt Retrieval**: When prompts are retrieved via `prompts/get` 
- **Resource Reading**: When resources are accessed via `resources/read`

## Notification Data

Each notification includes:

- **Action Type**: `tool_call`, `prompt_get`, or `resource_read`
- **Server Information**: Server name and UUID
- **Item Name**: Tool name, prompt name, or resource URI
- **Success Status**: Whether the operation succeeded or failed
- **Execution Time**: How long the operation took in milliseconds
- **Error Message**: If the operation failed, the error details

## API Endpoint

The proxy sends notifications to:
```
POST /api/notifications/mcp-activity
```

With authentication via the same API key used for other proxy operations.

## How It Works

1. **Non-blocking**: Notifications are sent asynchronously and won't block MCP operations if the notification system is unavailable
2. **Error handling**: Failed notifications are logged as warnings but don't interrupt the main MCP flow
3. **Execution timing**: Each operation is timed to provide performance insights
4. **Profile-specific**: Notifications are associated with the active profile from the API key

## Configuration

No additional configuration is needed. The notification system uses the same API key and base URL configured for the proxy:

- `PLUGGEDIN_API_KEY` - Your API key
- `PLUGGEDIN_API_BASE_URL` - Base URL for the plugged.in app

## Inspector Authentication

The MCP Inspector now requires authentication for security. We provide multiple modes:

### Auto-Opening Mode (Recommended)
```bash
npm run inspector
```
This automatically:
- Starts the inspector with authentication disabled (`DANGEROUSLY_OMIT_AUTH=true`)
- Opens your browser to `http://localhost:6274` after 3 seconds
- No manual token entry required

### Manual Mode
```bash
npm run inspector:manual
```
Starts the inspector with authentication disabled but doesn't auto-open the browser.

### Authenticated Mode
```bash
npm run inspector:auth
```
This requires using the session token displayed in the console output for production-like testing.

## MCP Authorization Compliance

Our proxy follows the [MCP Authorization specification](https://modelcontextprotocol.io/specification/2025-03-26/basic/authorization):

- **STDIO Transport**: Uses environment-based credentials (API keys) as recommended
- **HTTP Endpoints**: All API calls use Bearer token authentication
- **Security**: All communication with pluggedin-app uses HTTPS and proper authentication
- **OAuth 2.1**: Not implemented as it's optional for STDIO-based MCP servers

## Viewing Notifications

Notifications appear in the plugged.in app's notification system where users can:

- View recent MCP activity
- Track successful operations
- Monitor failed operations and errors
- See execution performance metrics

## Privacy & Security

- Notifications are only sent to the authenticated user's profile
- All communication uses the same security model as other proxy operations
- Error messages are included but sensitive data is not logged
- Notifications expire after 7 days by default 