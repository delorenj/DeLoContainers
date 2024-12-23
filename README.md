# DeLoContainers

A centralized repository for managing Docker containers and infrastructure for the DeLoNET home network.

## 🏗️ Repository Structure

```
/
├── docker-compose.yml     # Main compose file (network definitions)
├── mise.toml             # Task definitions
├── .env                  # Environment variables
├── stacks/              # Service stacks
│   ├── proxy/           # Traefik and networking
│   ├── media/           # Media services
│   └── ai/              # AI services
├── scripts/             # Management scripts
│   ├── backup.sh        # Backup automation
│   ├── init-stack.sh    # Stack initialization
│   ├── traefik.sh      # Traefik management
│   ├── vpn.sh          # VPN management
│   └── prune.sh        # System maintenance
└── backups/             # Service backups
```

## 🚀 Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/delorenj/DeLoContainers.git
   cd DeLoContainers
   ```

2. Set up environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. Start a stack:
   ```bash
   mise run stack:up proxy
   ```

## 🛠️ Available Tasks

### Stack Management
```bash
# Start a stack
mise run stack:up <stack_name>

# Stop a stack
mise run stack:down <stack_name>

# Restart a stack
mise run stack:restart <stack_name>

# View stack logs
mise run stack:logs <stack_name>

# Examples:
mise run stack:up proxy      # Start proxy stack
mise run stack:logs media    # View media stack logs
mise run stack:restart ai    # Restart AI stack
```

### Backup Management
```bash
# Backup all services
mise run backup:all

# Backup specific service
mise run backup:prowlarr
mise run backup:qbittorrent
mise run backup:traefik
```

### Traefik Management
```bash
# Show Traefik configuration and routes
mise run traefik:show

# Check Traefik status
mise run traefik:status

# Available commands:
mise run traefik:validate    # Validate configuration
mise run traefik:add        # Add new domain
mise run traefik:remove     # Remove domain
mise run traefik:apply      # Apply changes
mise run traefik:logs       # View logs
mise run traefik:certs      # Check SSL certificates
```

### System Maintenance
```bash
# Clean up Docker system
mise run system:prune
```

[Rest of README remains the same...]