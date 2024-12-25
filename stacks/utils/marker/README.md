# Marker Service

Bookmark manager service for organizing and sharing web bookmarks.

## Service Details

- **Image**: Marker
- **Purpose**: Self-hosted bookmark management system
- **Web UI**: http://localhost:3000
- **Dependencies**: None

## Configuration

### Environment Variables
Required environment variables (defined in root `.env`):
- `MARKER_SECRET`: Secret key for session management
- `MARKER_DATABASE_URL`: Database connection string
- `MARKER_ADMIN_EMAIL`: Admin user email
- `MARKER_ADMIN_PASSWORD`: Admin user password

### Ports
- `3000`: Web interface

### Volumes
- `./data:/app/data`: Application data
- `./config:/app/config`: Configuration files

## Features

- Bookmark organization with tags
- Full-text search
- Browser extension support
- Share collections
- Import/Export functionality

## Security

- User authentication required
- Admin account for management
- SSL termination handled by Traefik
- Rate limiting enabled

## Maintenance

1. Regular Updates
   ```bash
   docker-compose pull
   docker-compose up -d
   ```

2. Backup Data
   ```bash
   # Stop the container
   docker-compose stop marker
   
   # Backup data directory
   tar -czf marker_backup.tar.gz ./data
   
   # Restart the container
   docker-compose start marker
   ```

3. Database Management
   ```bash
   # Run database migrations
   docker-compose exec marker npm run migrate
   ```

## Monitoring

1. Check Service Status
   ```bash
   docker-compose ps marker
   ```

2. View Resource Usage
   ```bash
   docker stats marker
   ```

## Troubleshooting

### Common Issues

1. Authentication Issues
   - Verify environment variables
   - Check database connection
   - Ensure correct admin credentials

2. Performance Problems
   - Monitor system resources
   - Check database indexes
   - Clear application cache

3. Connection Issues
   - Verify port mappings
   - Check network configuration
   - Ensure service is running

### Logs
```bash
# View logs
docker-compose logs marker

# Follow logs
docker-compose logs -f marker
```

## Browser Extensions

1. Chrome/Brave
   - Available in Chrome Web Store
   - Configure extension with your instance URL

2. Firefox
   - Available in Firefox Add-ons
   - Set up server URL in extension settings

## API Access

The service provides a REST API for programmatic access:
- Base URL: http://localhost:3000/api
- Authentication: Bearer token
- Documentation available at /api/docs
