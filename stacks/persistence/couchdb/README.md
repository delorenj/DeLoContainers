# CouchDB Service

NoSQL database service for document storage and replication.

## Service Details

- **Image**: Apache CouchDB
- **Purpose**: Document database with HTTP/JSON API
- **Web UI**: http://localhost:5984/_utils
- **Dependencies**: None

## Configuration

### Environment Variables
Required environment variables (defined in root `.env`):
- `COUCHDB_USER`: Admin username
- `COUCHDB_PASSWORD`: Admin password

### Ports
- `5984`: HTTP API and Web UI

### Volumes
- `./data:/opt/couchdb/data`: Database files
- `./config:/opt/couchdb/etc/local.d`: Configuration files

## Security

- Admin credentials required for access
- CORS configuration available in local.ini
- SSL termination handled by Traefik

## Maintenance

1. Regular Updates
   ```bash
   docker-compose pull
   docker-compose up -d
   ```

2. Backup Database
   ```bash
   # Using CouchDB's built-in replication
   curl -X POST http://admin:password@localhost:5984/_replicate \
     -H "Content-Type: application/json" \
     -d '{"source":"http://localhost:5984/dbname","target":"backup_db"}'
   ```

3. Compaction
   ```bash
   # Compact specific database
   curl -X POST http://admin:password@localhost:5984/dbname/_compact
   ```

## Monitoring

1. Check Status
   ```bash
   curl http://localhost:5984/_up
   ```

2. View Active Tasks
   ```bash
   curl http://admin:password@localhost:5984/_active_tasks
   ```

## Troubleshooting

### Common Issues

1. Authentication Failures
   - Verify environment variables
   - Check admin party mode is disabled
   - Ensure correct credentials in requests

2. Performance Issues
   - Check disk space
   - Run database compaction
   - Monitor system resources

3. Connection Issues
   - Verify port mappings
   - Check network configuration
   - Ensure service is running:
     ```bash
     docker-compose ps couchdb
     ```

### Logs
```bash
# View logs
docker-compose logs couchdb

# Follow logs
docker-compose logs -f couchdb
