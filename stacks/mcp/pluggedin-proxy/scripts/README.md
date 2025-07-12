# Inspector Scripts

This directory contains helper scripts for running the MCP Inspector with various configurations.

## Scripts

### `inspector-simple.js` (Default)
- **Used by**: `npm run inspector`
- **Purpose**: Auto-opens browser after starting inspector
- **Features**:
  - Starts inspector with `DANGEROUSLY_OMIT_AUTH=true`
  - Automatically opens browser to `http://localhost:6274` after 3 seconds
  - No manual token entry required
  - Loads environment variables from `.env.local`

### `inspector-auto.js` (Advanced)
- **Purpose**: Attempts to capture session token and open pre-filled URL
- **Features**:
  - Parses inspector output for session token
  - Opens browser with token pre-filled in URL
  - More complex but handles token-based authentication

### `inspector-auto.sh` (Shell version)
- **Purpose**: Shell script version of auto-opening functionality
- **Features**:
  - Similar to `inspector-auto.js` but in bash
  - May have platform compatibility issues

## Usage

```bash
# Auto-opening mode (recommended)
npm run inspector

# Manual mode (no auto-open)
npm run inspector:manual

# Authenticated mode (requires token)
npm run inspector:auth
```

## Environment Variables

All scripts load environment variables from `.env.local`:
- `PLUGGEDIN_API_KEY`: Your API key for the pluggedin-app
- `PLUGGEDIN_API_BASE_URL`: Base URL for the pluggedin-app (e.g., `http://localhost:12005`)

## Platform Support

- **macOS**: Uses `open` command
- **Linux**: Uses `xdg-open` command  
- **Windows**: Uses `start` command

## Troubleshooting

If auto-opening doesn't work:
1. Check that your platform's browser opener is available
2. Manually open `http://localhost:6274` in your browser
3. Use `pnpm inspector:manual` for manual control 