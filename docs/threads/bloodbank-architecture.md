# Bloodbank Architecture Plan

## Overview
Bloodbank is a dead simple screenshot hosting service designed for LLM workflows, integrating seamlessly with the existing DeLoContainers infrastructure.

## Architecture Components

### 1. Core Services Stack
**Location**: `stacks/utils/bloodbank/`

#### Services:
- **bloodbank-web**: Nginx static file server with custom config
- **bloodbank-watcher**: File watcher service (mise-based)
- **bloodbank-cleanup**: Daily cleanup cron service
- **bloodbank-mcp** (future): MCP server for LLM integration

### 2. File Structure
```
~/ss/                           # Screenshot drop zone
/data/bloodbank/
├── hosted/                     # Active screenshots (web-accessible)
├── archive/                    # Daily archives
├── metadata/                   # JSON metadata files
└── config/                     # Configuration files
```

### 3. Data Flow
1. **Screenshot Capture** → `~/ss/` (user's screenshot tool)
2. **File Watcher** → Detects new files in `~/ss/`
3. **Processing** → Rename, move to hosted/, generate metadata
4. **Clipboard** → Copy URL to clipboard
5. **Cleanup** → Daily archive, 30-day retention

## Technical Implementation

### Docker Compose Structure
```yaml
services:
  bloodbank-web:
    image: nginx:alpine
    container_name: bloodbank-web
    volumes:
      - bloodbank_data:/usr/share/nginx/html
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.bloodbank.rule=Host(`bloodbank.delo.sh`)"
      - "traefik.http.routers.bloodbank.tls=true"
      - "traefik.http.routers.bloodbank.tls.certresolver=letsencrypt"

  bloodbank-watcher:
    build: ./watcher
    container_name: bloodbank-watcher
    volumes:
      - ${HOME}/ss:/watch:ro
      - bloodbank_data:/data
      - /tmp:/tmp
    environment:
      - BLOODBANK_URL=https://bloodbank.delo.sh
    restart: unless-stopped

  bloodbank-cleanup:
    image: alpine:latest
    container_name: bloodbank-cleanup
    volumes:
      - bloodbank_data:/data
    command: |
      sh -c '
      echo "0 2 * * * /cleanup.sh" | crontab -
      crond -f'
    restart: unless-stopped
```

### Nginx Configuration
- Static file serving with security headers
- No directory listing without X-API header
- Direct file access with exact filename
- CORS headers for LLM access

### File Watcher Service
- **Technology**: Go binary with fsnotify
- **Triggers**: File creation in `~/ss/`
- **Processing**: 
  - Rename to `YYYYmmdd-HHmm.png`
  - Move to hosted directory
  - Generate metadata JSON
  - Copy URL to clipboard (via X11/Wayland)

### Cleanup Service
- **Schedule**: Daily at 2 AM
- **Archive**: Move files to dated archive folders
- **Retention**: Delete archives older than 30 days
- **Preserve**: Skip files marked with preserve flag

## Security Considerations

### Access Control
- No directory browsing without API header
- Direct file access only with exact filename
- Rate limiting via Traefik
- No sensitive metadata exposure

### File Validation
- Image format validation
- File size limits
- Sanitized filenames
- Malware scanning (future)

## Integration Points

### Traefik Integration
- Uses existing proxy network
- SSL termination handled by Traefik
- Automatic certificate management

### MCP Server (Future)
- Task-specific staging areas
- AI annotation capabilities
- Metadata management API
- Batch operations

### Clipboard Integration
- X11 clipboard for Linux
- Wayland clipboard support
- Cross-platform compatibility

## Monitoring & Observability

### Metrics
- File processing rate
- Storage usage
- Cleanup statistics
- Error rates

### Logging
- File operations
- Access logs
- Error tracking
- Performance metrics

## Development Phases

### Phase 1: Core Functionality
- [x] Architecture design
- [ ] Docker compose setup
- [ ] Nginx configuration
- [ ] File watcher service
- [ ] Basic cleanup service

### Phase 2: Enhanced Features
- [ ] Metadata management
- [ ] Preserve flag functionality
- [ ] Batch ID support
- [ ] Repository tagging

### Phase 3: MCP Integration
- [ ] MCP server development
- [ ] AI annotation tools
- [ ] Task-specific staging
- [ ] LLM notification system

### Phase 4: Frontend
- [ ] SvelteKit application
- [ ] Image gallery
- [ ] Metadata editing
- [ ] Search functionality

## Configuration Management

### Environment Variables
```bash
BLOODBANK_URL=https://bloodbank.delo.sh
BLOODBANK_RETENTION_DAYS=30
BLOODBANK_MAX_FILE_SIZE=10MB
BLOODBANK_WATCH_DIR=/home/delorenj/ss
BLOODBANK_API_KEY=<generated>
```

### Volume Mounts
- Screenshot source: `${HOME}/ss:/watch:ro`
- Data storage: `bloodbank_data:/data`
- Clipboard access: `/tmp:/tmp`

## Next Steps
1. Create directory structure
2. Implement file watcher service
3. Configure Nginx with security headers
4. Set up Traefik routing
5. Test end-to-end workflow
