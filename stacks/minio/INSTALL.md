# DeLoDrive Installation Guide

## Prerequisites

✅ Docker and Docker Compose installed
✅ Traefik running on the `proxy` network
✅ Cloudflare DNS configured for `drive.delo.sh`

## Installation Steps

### 1. Configure DNS in Cloudflare

Add an A record in Cloudflare:
- **Type**: A
- **Name**: drive
- **Content**: Your server's public IP
- **Proxy status**: DNS only (grey cloud) - Let Traefik handle SSL
- **TTL**: Auto

### 2. Deploy MinIO

```bash
cd /home/delorenj/docker/trunk-main/stacks/minio
./setup.sh
```

Or manually:

```bash
cd /home/delorenj/docker/trunk-main/stacks/minio
docker compose up -d
```

### 3. Verify Deployment

Check if the container is running:
```bash
docker ps | grep delodrive
```

View logs:
```bash
docker compose logs -f
```

Check Traefik routing:
```bash
docker logs traefik 2>&1 | grep -i minio
```

### 4. Access the Web Console

Open your browser to: **https://drive.delo.sh**

Login with:
- **Username**: `delorenj`
- **Password**: `Ittr5eesol`

## Post-Installation

### Install MinIO Client (Optional)

```bash
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/
mc --version
```

### Configure MinIO Client

```bash
mc alias set delodrive https://drive.delo.sh delorenj Ittr5eesol
mc admin info delodrive
```

### Create Your First Bucket

```bash
mc mb delodrive/my-first-bucket
mc ls delodrive
```

## Architecture

```
Internet
    ↓
Cloudflare DNS (drive.delo.sh)
    ↓
Your Server
    ↓
Traefik (Port 443)
    ├─ SSL Termination (Let's Encrypt)
    └─ Routing
        ↓
MinIO Container (delodrive)
    ├─ Console UI (Port 9001) → https://drive.delo.sh
    └─ S3 API (Port 9000) → https://drive.delo.sh/minio/*
```

## File Locations

- **Docker Compose**: `/home/delorenj/docker/trunk-main/stacks/minio/compose.yml`
- **Environment**: `/home/delorenj/docker/trunk-main/stacks/minio/.env`
- **Data Storage**: `/home/delorenj/DeLoDrive`
- **Network**: `proxy` (shared with Traefik)

## Troubleshooting

### Can't access drive.delo.sh

1. Check DNS propagation:
   ```bash
   nslookup drive.delo.sh
   dig drive.delo.sh
   ```

2. Check if Traefik is running:
   ```bash
   docker ps | grep traefik
   ```

3. Check MinIO container:
   ```bash
   docker ps | grep delodrive
   docker logs delodrive
   ```

4. Check Traefik logs:
   ```bash
   docker logs traefik 2>&1 | grep -i minio
   ```

### SSL Certificate Issues

Traefik will automatically request a Let's Encrypt certificate using Cloudflare DNS challenge.
This may take a few minutes on first startup.

Check certificate status:
```bash
docker logs traefik 2>&1 | grep -i acme
```

### Permission Issues

Ensure the data directory has correct permissions:
```bash
ls -la /home/delorenj/DeLoDrive
chmod 755 /home/delorenj/DeLoDrive
```

## Maintenance

### Update MinIO

```bash
cd /home/delorenj/docker/trunk-main/stacks/minio
docker compose pull
docker compose up -d
```

### Backup Data

The data directory `/home/delorenj/DeLoDrive` contains all your MinIO data.
Back it up regularly:

```bash
rsync -av /home/delorenj/DeLoDrive/ /path/to/backup/
```

### View Resource Usage

```bash
docker stats delodrive
```

## Security Notes

- Change the default password in `.env` file
- Consider enabling MinIO's built-in encryption
- Regularly update the MinIO image
- Monitor access logs

## Next Steps

- Create buckets for different use cases
- Set up bucket policies and access controls
- Configure lifecycle rules for automatic data management
- Integrate with applications using S3 API
- Set up bucket versioning for important data
