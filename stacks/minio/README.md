# DeLoDrive - MinIO Object Storage

MinIO object storage accessible at `drive.delo.sh` behind Traefik reverse proxy.

## Configuration

- **Domain**: drive.delo.sh
- **Admin User**: delorenj
- **Admin Password**: Ittr5eesol
- **Data Directory**: /home/delorenj/DeLoDrive
- **Network**: proxy (Traefik)
- **Console Port**: 9001 (Web UI)
- **API Port**: 9000 (S3 API)

## Quick Start

### 1. Ensure DNS is configured
Make sure `drive.delo.sh` points to your server's IP in Cloudflare.

### 2. Start the service
```bash
cd /home/delorenj/docker/trunk-main/stacks/minio
docker compose up -d
```

### 3. Access the Web Console
Open https://drive.delo.sh in your browser and login with:
- Username: `delorenj`
- Password: `Ittr5eesol`

## Management Commands

### View logs
```bash
docker compose logs -f
```

### Stop the service
```bash
docker compose down
```

### Restart the service
```bash
docker compose restart
```

### Update MinIO
```bash
docker compose pull
docker compose up -d
```

## MinIO Client (mc) Setup

### Install the MinIO client
```bash
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/
```

### Configure alias
```bash
mc alias set delodrive https://drive.delo.sh delorenj Ittr5eesol
```

### Test connection
```bash
mc admin info delodrive
```

### Create a bucket
```bash
mc mb delodrive/mybucket
```

### Upload a file
```bash
mc cp myfile.txt delodrive/mybucket/
```

### List buckets
```bash
mc ls delodrive
```

### List files in a bucket
```bash
mc ls delodrive/mybucket
```

## S3 API Usage

You can use any S3-compatible client with these settings:
- **Endpoint**: https://drive.delo.sh
- **Access Key**: delorenj
- **Secret Key**: Ittr5eesol
- **Region**: us-east-1 (default)

### Example with AWS CLI
```bash
aws configure set aws_access_key_id delorenj
aws configure set aws_secret_access_key Ittr5eesol
aws --endpoint-url https://drive.delo.sh s3 ls
```

## Traefik Integration

The service is configured with two routers:
1. **Console Router** (priority 100): Serves the web UI at https://drive.delo.sh
2. **API Router** (priority 50): Handles S3 API requests

SSL certificates are automatically managed by Traefik using Let's Encrypt with Cloudflare DNS challenge.

## Data Storage

All data is stored in `/home/delorenj/DeLoDrive` on the host system.

## Troubleshooting

### Check if container is running
```bash
docker ps | grep delodrive
```

### View container logs
```bash
docker logs delodrive
```

### Check Traefik routing
```bash
docker logs traefik | grep minio
```

### Verify network connectivity
```bash
docker network inspect proxy
```

### Test DNS resolution
```bash
nslookup drive.delo.sh
```
