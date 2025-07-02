# OpenCode Docker Container Issue Documentation

## Problem Summary
OpenCode Docker container was failing to start with the error:
```
ERROR: OpenCode binary not found or not executable at /home/mcp/.opencode/bin/opencode
```

## Root Cause Analysis

### Primary Issue: Incorrect Path References ✅ RESOLVED
The container was using outdated `/home/mcp` paths instead of `/root` paths in multiple files:

1. **`start-opencode.sh`** - Multiple references to `/home/mcp` paths
2. **`generate-apikey.sh`** - Reference to `/home/mcp/.env`
3. **`opencode.yml` (Traefik config)** - Comment referencing `/home/mcp`

### Secondary Issue: Server Persistence ❌ UNRESOLVED
After fixing path issues, OpenCode starts successfully but exits immediately after initialization.

## Investigation Details

### OpenCode Installation Location
- **Actual binary location**: `/root/.local/bin/pnpm/opencode`
- **Previous incorrect assumption**: `/root/.local/bin/opencode`
- **Installation method**: `pnpm i -g opencode-ai@latest`

### OpenCode Behavior Analysis
```bash
# OpenCode starts and initializes services
INFO service=default version=0.1.162 args=serve,--hostname,0.0.0.0,--port,4096,--print-logs
INFO service=app cwd=/code creating
INFO service=app git
INFO service=app name=provider registering service
INFO service=app name=config registering service
INFO service=config loaded
INFO service=models.dev refreshing
INFO service=provider init
# Then exits with code 0
```

### Key Observations
1. **OpenCode is a REPL by default** - runs interactive terminal interface
2. **`serve` command exists** - documented as "starts a headless opencode server"
3. **Process exits cleanly** - code 0, not crashing
4. **Brief port binding** - `curl` shows "Connection reset by peer" vs "Connection refused"
5. **No authentication required** - for the binary itself (Traefik auth is separate)

## Files Modified ✅

### `/home/delorenj/docker/stacks/ai/opencode/start-opencode.sh`
```bash
# BEFORE (broken paths)
/home/mcp/generate-apikey.sh
source /home/mcp/.env
/home/mcp/.opencode/bin/opencode

# AFTER (correct paths)
/generate-apikey.sh
source /root/.env
/root/.local/bin/pnpm/opencode
```

### `/home/delorenj/docker/stacks/ai/opencode/generate-apikey.sh`
```bash
# BEFORE
echo "OPENCODE_API_KEY=$API_KEY" >> /home/mcp/.env

# AFTER
echo "OPENCODE_API_KEY=$API_KEY" >> /root/.env
```

### `/home/delorenj/docker/core/traefik/traefik-data/dynamic/opencode.yml`
```yaml
# Updated comment and API key hash
# Generate with container: docker compose exec opencode /generate-apikey.sh
users:
  - "api:$$2y$$05$$5NDzY8X6DDq80Vsw6clYYOZ07VLMTU7rKo0GcPASTEmUzDAuZMhCy"
```

### `/home/delorenj/docker/stacks/ai/opencode/compose.yml`
```yaml
# Added TTY support for interactive applications
tty: true
stdin_open: true
restart: always  # Changed from unless-stopped
```

## Attempted Solutions for Server Persistence

### 1. TTY Support
Added `tty: true` and `stdin_open: true` to compose file - OpenCode still exits

### 2. Restart Loops
Implemented bash while loop to restart process - works but doesn't solve root cause

### 3. Process Monitoring
Used background processes with PID monitoring - same exit behavior

### 4. Environment Variables
Tested various environment configurations - no change in behavior

## Current Status

### ✅ Working Components
- OpenCode binary found and executable
- Container builds successfully
- Traefik routing configured
- API key authentication setup
- Automatic container restart on exit

### ❌ Unresolved Issues
- OpenCode serve command exits after initialization
- No persistent server process
- Cannot access through Traefik (backend unavailable)

## Technical Specifications

### Container Environment
- **Base Image**: `ghcr.io/delorenj/mcp-base:latest`
- **OpenCode Version**: `0.1.162`
- **Installation**: `pnpm i -g opencode-ai@latest`
- **Working Directory**: `/code`
- **Port**: `4096`
- **Hostname**: `0.0.0.0`

### Network Configuration
- **Traefik Route**: `opencode.delo.sh`
- **Backend URL**: `http://opencode:4096`
- **Authentication**: Basic Auth via X-API-Key header
- **SSL**: Let's Encrypt certificate

## Questions for Further Investigation

1. **Is OpenCode's `serve` command designed to run persistently?**
   - Documentation suggests it should start a "headless server"
   - Behavior suggests it initializes and exits

2. **Does OpenCode require specific configuration files?**
   - No config directory found: `/root/.local/share/opencode/` doesn't exist
   - May need initialization step before serving

3. **Are there missing dependencies or environment variables?**
   - All services initialize successfully
   - No error messages in logs

4. **Is this a known issue with OpenCode in containerized environments?**
   - May need different approach for Docker deployment
   - Could require process manager or different startup method

## Recommended Next Steps

1. **Check OpenCode documentation** for server deployment examples
2. **Test OpenCode serve command** on host system (non-containerized)
3. **Contact OpenCode maintainers** about Docker/server deployment
4. **Try alternative approaches**:
   - Process managers (supervisor, pm2)
   - Different base images
   - Alternative startup methods
5. **Investigate OpenCode source code** for serve command implementation

## API Key Information
- **Generated Key**: `dfac1b19d8eb24600bc7db902c9dcfb3b4d364cd91020d125840ae4b5b3675bb`
- **Hashed for Traefik**: `$$2y$$05$$5NDzY8X6DDq80Vsw6clYYOZ07VLMTU7rKo0GcPASTEmUzDAuZMhCy`
- **Usage**: `curl -H "X-API-Key: api:dfac1b19d8eb24600bc7db902c9dcfb3b4d364cd91020d125840ae4b5b3675bb" https://opencode.delo.sh/`
