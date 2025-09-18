# Docker Container Health Monitoring & Self-Healing System

## Overview

A comprehensive self-healing system that automatically detects and recovers unhealthy Docker containers. This system monitors container health, applies recovery strategies, and provides alerting capabilities.

## Features

### 🔍 Health Monitoring
- **Continuous Monitoring**: Checks container status every 30 seconds
- **Health Check Integration**: Monitors Docker native health checks
- **Resource Monitoring**: Tracks CPU, memory, and disk usage
- **Network Health**: Detects network connectivity issues
- **Dependency Tracking**: Ensures dependent services are running

### 🔧 Automated Recovery
- **Smart Restart Logic**: Graduated restart attempts with backoff
- **Resource Limiting**: Automatically applies CPU/memory limits to runaway containers
- **Network Recovery**: Refreshes network connections for connectivity issues
- **Dependency Resolution**: Starts required services before dependent containers
- **Disk Space Management**: Cleans logs and temporary files

### 📊 Alerting & Logging
- **Multi-Channel Alerts**: Webhook, Alertmanager, and log file alerts
- **Severity Levels**: Info, warning, and critical alerts
- **Detailed Logging**: Comprehensive logs for debugging
- **Recovery History**: Tracks all recovery attempts

## Installation

### Quick Install

```bash
# Make installation script executable
chmod +x scripts/install-health-monitor.sh

# Run installation (requires sudo/root)
sudo ./scripts/install-health-monitor.sh
```

### Manual Installation

#### Option 1: Systemd Service (Recommended)

```bash
# Copy service file
sudo cp scripts/docker-health-systemd.service /etc/systemd/system/docker-health-monitor.service

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable docker-health-monitor
sudo systemctl start docker-health-monitor
```

#### Option 2: Docker Container

```bash
# Deploy monitoring stack
cd stacks/monitoring
docker compose -f docker-compose-health.yml up -d
```

#### Option 3: Cron Job

```bash
# Add to crontab
*/5 * * * * /path/to/scripts/docker-health-monitor.sh
```

## Configuration

Edit `/etc/docker-health/config.env`:

```bash
# Check interval (seconds)
CHECK_INTERVAL=30

# Max restart attempts
MAX_RESTART_ATTEMPTS=3

# Cooldown period (seconds)
COOLDOWN_PERIOD=300

# Alert webhook (optional)
ALERT_WEBHOOK=https://your-webhook.com/alerts

# Exclude specific containers
EXCLUDE_CONTAINERS="test-container debug-container"
```

## Recovery Strategies

### 1. Exit Code Recovery

| Exit Code | Issue | Recovery Action |
|-----------|-------|-----------------|
| 0 | Normal exit | Simple restart |
| 1 | General error | Check logs, fix permissions, restart |
| 125 | Docker daemon error | Wait and retry |
| 137 | SIGKILL/OOM | Apply memory limits, restart |
| 139 | Segmentation fault | Full restart |
| 143 | SIGTERM | Normal restart |

### 2. Resource-Based Recovery

#### High CPU Usage
```bash
# Automatically applied when CPU > 100%
docker update --cpus="1" <container>
```

#### High Memory Usage
```bash
# Automatically applied when memory > 90%
docker update --memory="2g" --memory-swap="4g" <container>
```

### 3. Health Check Recovery

Containers with failing health checks are:
1. Analyzed for specific failure patterns
2. Restarted with appropriate recovery strategy
3. Monitored for improvement

### 4. Dependency Recovery

Services with dependencies are handled specially:
- **QBittorrent**: Ensures Gluetun VPN is running
- **MetaMCP**: Checks Redis and PostgreSQL
- **Grafana**: Verifies Prometheus availability

## Health Check Examples

### Adding Health Checks to Containers

#### Web Service
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost/health"]
  interval: 30s
  timeout: 10s
  retries: 3
```

#### Database Service
```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres"]
  interval: 30s
  timeout: 10s
  retries: 3
```

#### Custom Application
```yaml
healthcheck:
  test: ["CMD", "/app/health-check.sh"]
  interval: 30s
  timeout: 10s
  retries: 3
```

## Monitoring Dashboard

### Prometheus Metrics

The system exports metrics to Prometheus:
- `container_health_status`: Current health status
- `container_restart_count`: Number of restarts
- `container_recovery_success`: Successful recoveries
- `container_recovery_failure`: Failed recoveries

### Grafana Dashboard

Import the dashboard from `stacks/monitoring/dashboards/docker-health.json`:
- Container status overview
- Restart frequency graphs
- Health check status table
- Recovery action logs

## Manual Recovery

### Recover Specific Container

```bash
# Generic recovery
./scripts/docker-recovery-strategies.sh container_name

# Specific issue recovery
./scripts/docker-recovery-strategies.sh container_name high_cpu
./scripts/docker-recovery-strategies.sh container_name high_memory
./scripts/docker-recovery-strategies.sh container_name network
./scripts/docker-recovery-strategies.sh container_name dependencies
```

### Batch Recovery

```bash
# Recover multiple containers
./scripts/docker-recovery-strategies.sh container1 container2 container3
```

## Troubleshooting

### Check Monitor Status

```bash
# Systemd service
sudo systemctl status docker-health-monitor

# Docker container
docker logs docker-health-monitor

# View logs
tail -f /var/log/docker-health/health-monitor.log
```

### Common Issues

#### Monitor Not Starting
- Check Docker socket permissions
- Verify script paths in service file
- Check system logs: `journalctl -u docker-health-monitor`

#### Containers Not Recovering
- Check cooldown period settings
- Verify max restart attempts
- Review recovery logs: `/var/log/docker-health/recovery.log`

#### High Resource Usage
- Adjust CHECK_INTERVAL to reduce frequency
- Exclude stable containers from monitoring
- Apply resource limits to the monitor itself

## Integration with Existing Infrastructure

### Traefik
The system respects Traefik labels and network configuration during recovery.

### Docker Compose
Automatically detects and uses compose files for container recreation.

### Monitoring Stack
Integrates with existing Prometheus, Grafana, and Alertmanager deployments.

## Best Practices

1. **Set Appropriate Health Checks**: Define health checks for all critical services
2. **Configure Resource Limits**: Prevent resource exhaustion with limits
3. **Use Restart Policies**: Combine with Docker restart policies
4. **Monitor the Monitor**: Ensure the health monitor itself is monitored
5. **Regular Log Rotation**: Configure log rotation to prevent disk filling
6. **Test Recovery**: Periodically test recovery procedures
7. **Document Dependencies**: Clearly define service dependencies

## Advanced Configuration

### Custom Recovery Scripts

Add custom recovery logic in `/etc/docker-health/custom-recovery.sh`:

```bash
#!/bin/bash
custom_recovery() {
    local container="$1"
    case "$container" in
        "my-special-app")
            # Custom recovery logic
            ;;
    esac
}
```

### Alert Webhooks

Configure webhooks for different alert channels:

```bash
# Slack webhook
ALERT_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Discord webhook
ALERT_WEBHOOK="https://discord.com/api/webhooks/YOUR/WEBHOOK"

# Custom webhook with authentication
ALERT_WEBHOOK="https://your-api.com/alerts"
ALERT_WEBHOOK_TOKEN="your-token"
```

## Security Considerations

- Monitor runs with minimal required permissions
- Docker socket mounted read-only when possible
- Logs sanitized to prevent credential exposure
- Network isolation for monitoring components

## Performance Impact

- **CPU**: < 1% average usage
- **Memory**: ~50MB for monitor process
- **Disk I/O**: Minimal, primarily logging
- **Network**: Negligible, only for alerts

## Maintenance

### Weekly Tasks
- Review recovery logs for patterns
- Check alert webhook connectivity
- Verify health check effectiveness

### Monthly Tasks
- Analyze recovery success rates
- Optimize recovery strategies
- Update container dependencies
- Review and adjust thresholds

## Support

For issues or improvements:
1. Check logs in `/var/log/docker-health/`
2. Review recovery attempts in state file
3. Test manual recovery with strategy scripts
4. Consult this documentation

## Version History

- **v1.0.0**: Initial implementation with basic recovery
- **v1.1.0**: Added health check monitoring
- **v1.2.0**: Integrated with monitoring stack
- **v1.3.0**: Added dependency resolution
- **v1.4.0**: Enhanced recovery strategies

Last Updated: 2025-09-16