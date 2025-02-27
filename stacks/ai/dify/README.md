# Dify.AI Deployment Guide

Dify is an open-source LLM application development platform deployed behind the Traefik reverse proxy on the DeLoNET infrastructure.

## Subdomain Configuration

The Dify services are accessible through the following subdomains:

- Web UI: `https://dify.delo.sh` 
- API: `https://api.dify.delo.sh`

## Services

This deployment includes the following services:

1. **dify-web**: Frontend web interface
2. **dify-api**: Backend API service
3. **dify-worker**: Async job worker
4. **dify-scheduler**: Task scheduler
5. **dify-db**: PostgreSQL database
6. **dify-redis**: Redis cache
7. **dify-weaviate**: Vector database

## Deployment

To deploy Dify, run the following commands:

```bash
cd /home/delorenj/docker/stacks/ai/dify
docker-compose up -d
```

## Initial Setup

After deployment, follow these steps:

1. Visit `https://dify.delo.sh` in your browser
2. Complete the initial setup process:
   - Create an admin account
   - Configure your LLM provider API keys

## Managing API Keys

Dify requires API keys for various LLM providers. You can add or update these through:

1. The Dify web interface under Settings → Model Providers
2. Or by updating the relevant environment variables in the `.env` file

## Common Issues & Troubleshooting

### Connection Issues

If you experience connection problems between services:

1. Check that the Traefik network is properly configured
2. Verify that the docker-compose.yml labels are correct
3. Test direct container-to-container communication with: `docker exec -it dify-web ping dify-api`

### Database Migrations

If database updates are needed:

```bash
docker-compose stop api worker scheduler
docker-compose up -d db
docker-compose up -d api
```

## Backup

To backup your Dify deployment:

```bash
# Backup volumes
tar -czf dify-data-backup-$(date +%Y%m%d).tar.gz ./data

# Backup configuration
cp .env .env.backup
cp docker-compose.yml docker-compose.yml.backup
```

## Upgrading

To upgrade to a newer version of Dify:

```bash
# Pull the latest images
docker-compose pull

# Restart the services
docker-compose down
docker-compose up -d
```

## Maintenance Commands

```bash
# View logs
docker-compose logs -f

# View logs for a specific service
docker-compose logs -f api

# Restart a specific service
docker-compose restart api

# Check service status
docker-compose ps
```
