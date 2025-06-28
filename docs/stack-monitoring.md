# Docker Stack Monitoring System

This system ensures your Docker stacks are always running based on configuration.

## Files

- `stack-config.yml` - Configuration file defining which stacks should be enabled
- `scripts/stack-monitor.py` - Main monitoring script
- `scripts/manage-stacks.sh` - Management script for the monitoring service
- `scripts/health-check.sh` - Simple health check script

## Configuration

Edit `stack-config.yml` to control which stacks should be running:

```yaml
stacks:
  core/traefik/compose.yml:
    enabled: true      # Set to false to disable
    priority: 1        # Lower numbers start first
    description: "Reverse proxy and SSL termination"
```

## Management Commands

```bash
# Show current status of all stacks
./scripts/manage-stacks.sh status

# Run a single monitoring check
./scripts/manage-stacks.sh check

# Start/stop/restart the monitoring service
./scripts/manage-stacks.sh start
./scripts/manage-stacks.sh stop
./scripts/manage-stacks.sh restart

# View service logs
./scripts/manage-stacks.sh logs

# Edit configuration
./scripts/manage-stacks.sh config

# Simple health check
./scripts/health-check.sh
```

## How It Works

1. **Configuration**: `stack-config.yml` defines which stacks should be enabled
2. **Monitoring**: The service checks every 5 minutes (configurable)
3. **Auto-Recovery**: If an enabled stack is down, it automatically starts it
4. **Priority**: Stacks start in priority order (lower numbers first)
5. **Logging**: All actions are logged to `logs/stack-monitor.log`

## Service Management

The monitoring runs as a systemd service:

```bash
# Service status
sudo systemctl status docker-stack-monitor

# Service logs
sudo journalctl -u docker-stack-monitor -f

# Manual service control
sudo systemctl start docker-stack-monitor
sudo systemctl stop docker-stack-monitor
sudo systemctl restart docker-stack-monitor
```

## Configuration Options

In `stack-config.yml`:

```yaml
settings:
  check_interval: 300    # Check every 5 minutes
  restart_delay: 30      # Wait 30s between restarts
  max_retries: 3         # Maximum restart attempts
  log_file: "/home/delorenj/docker/logs/stack-monitor.log"
```

## Adding New Stacks

1. Add the compose file path to `stack-config.yml`
2. Set `enabled: true` and assign a priority
3. The monitor will automatically manage it

## Troubleshooting

- Check logs: `./scripts/manage-stacks.sh logs`
- Manual check: `./scripts/manage-stacks.sh check`
- Service status: `sudo systemctl status docker-stack-monitor`
- Configuration issues: `./scripts/manage-stacks.sh config`

## Status Icons

- 🟢 Stack is running
- 🔴 Stack is not running
- ✅ Stack is enabled in config
- ❌ Stack is disabled in config
