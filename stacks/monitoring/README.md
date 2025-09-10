# Real Docker Monitoring Stack

Industry-standard monitoring using **Prometheus + Grafana + cAdvisor**.

## Quick Start

```bash
cd /home/delorenj/docker/trunk-main/monitoring
docker-compose up -d
```

## Access Points

- **Grafana**: http://localhost:9831 (admin/admin)
- **Prometheus**: http://localhost:9472
- **cAdvisor**: http://localhost:9264
- **AlertManager**: http://localhost:9784

## Key Features

- **Real metrics** from cAdvisor (not fake data)
- **Memory/CPU alerts** for MetaMCP container
- **Process count monitoring** with alerts >15 processes
- **Historical data** retention (200 hours)
- **Pre-configured dashboards** for Docker containers

## Import Grafana Dashboards

1. Go to Grafana (http://localhost:9831)
2. Import these community dashboards:
   - **Docker and Host Monitoring**: ID `179`
   - **Docker Container Monitoring**: ID `19908`
   - **Node Exporter Full**: ID `1860`

## MetaMCP Specific Alerts

- Process count >15 → Critical alert
- Memory usage >80% → Warning alert
- CPU usage >80% → Warning alert
- Container down → Critical alert

## Stop Monitoring

```bash
docker-compose down -v
```