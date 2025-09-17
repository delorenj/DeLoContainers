# Docker Service Map

## Active Container Ecosystem

### Current Status (2025-09-16)
- **Total Containers**: 50 (45 running, 3 exited, 2 created)
- **Active Networks**: 14 Docker networks
- **Resource Usage**: Monitoring shows high CPU usage on cadvisor (171%)

## Service Categories

### 🔐 Core Infrastructure
| Service | Status | Port(s) | Network | Description |
|---------|--------|---------|---------|-------------|
| **Traefik** | ✅ Up 2 days | 80, 443, 8099 | proxy | Reverse proxy & load balancer |
| **MetaMCP** | ✅ Up 2 hours (healthy) | 12008-12009 | metamcp_default, proxy | MCP server with Traefik integration |
| **MetaMCP Process Monitor** | ✅ Up 2 hours | - | metamcp_default | Process monitoring for MetaMCP |

### 📊 Monitoring Stack
| Service | Status | Port(s) | Memory | CPU | Description |
|---------|--------|---------|--------|-----|-------------|
| **Prometheus** | ✅ Up 6 hours | 9472 | 772MiB | 2% | Metrics collection |
| **Grafana** | ✅ Up 6 hours | 9831 | 83MiB | 0.09% | Visualization dashboard |
| **cAdvisor** | ⚠️ Up 6 hours (high CPU) | 9264 | 298MiB | 171% | Container metrics |
| **Node Exporter** | ✅ Up 6 hours | 9519 | 11MiB | 0% | System metrics |
| **Alertmanager** | ✅ Up 6 hours | 9784 | 31MiB | 0.03% | Alert routing |

### 🤖 AI & Automation
| Service | Status | Port(s) | Description |
|---------|--------|---------|-------------|
| **Letta** | ✅ Up 46 hours | 8283 | Memory management AI |
| **Dify Stack** | ✅ Up 2 days | Multiple | AI workflow platform |
| - API | ✅ | 5001 | API service |
| - Worker | ✅ | 5001 | Background worker |
| - Worker Beat | ✅ | 5001 | Task scheduler |
| - Web | ✅ | 3000 | Web interface |
| - Sandbox | ✅ Healthy | - | Code execution sandbox |
| - SSRF Proxy | ✅ | 3128 | Security proxy |
| - Weaviate | ✅ | 8080 | Vector database |
| - Plugin Daemon | ❌ Exited | - | Plugin management |

### 📦 Data Persistence
| Service | Status | Port(s) | Description |
|---------|--------|---------|-------------|
| **PostgreSQL** | ✅ Up 2 days | 15434 | Primary database |
| **Redis** | ✅ Up 2 days | 6379, 6380 | Cache & message broker |
| **Qdrant** | ✅ Up 46 hours | 6333-6334 | Vector database |
| **NATS** | ✅ Up 2 days | 4222, 6222, 8222 | Message streaming |

### 🎥 Media Services
| Service | Status | Port(s) | Description |
|---------|--------|---------|-------------|
| **Castagram** | ✅ Up 2 days | - | Media management |
| **LiveKit Server** | ✅ Up 2 days | 7881, 61000-61050 | WebRTC server |
| **LiveKit Egress** | ✅ Up 2 days | - | Recording service |
| **LiveKit CoTurn** | ✅ Up 2 days | 3478, 5349 | TURN/STUN server |
| **Chrome Debug** | ✅ Up 2 days | 9222 | Browserless Chrome |

### 🛡️ Network & Security
| Service | Status | Port(s) | Description |
|---------|--------|---------|-------------|
| **AdGuard** | ✅ Up 2 days | 53, 3000 | DNS filtering |
| **AdGuard Redirect** | ⚠️ Unhealthy | 8888 | Redirect service |
| **Gluetun** | ✅ Up 2 days | 8091, 49152-49156 | VPN client |
| **VPN Monitor** | ✅ Up 2 days | - | VPN status monitoring |

### 🔧 Utilities
| Service | Status | Port(s) | Description |
|---------|--------|---------|-------------|
| **Assets Nginx** | ✅ Up 2 days | 80 | Static file server |
| **SSBNK Web** | ✅ Up 2 days | 80 | Web interface |
| **SSBNK Watcher** | ✅ Up 2 days | - | File watcher |
| **SSBNK Cleanup** | ✅ Up 2 days | - | Cleanup service |

### ⚙️ Development & Testing
| Service | Status | Description |
|---------|--------|-------------|
| **Act Build Tests** | ❌ Exited 2 days ago | GitHub Actions local runner |
| **MetaMCP Test** | 🆕 Created | Test environment |
| **MetaMCP Production** | ❌ Exited 7 hours ago | Production environment |

## Docker Networks

### Active Networks
1. **proxy** - Main reverse proxy network (Traefik)
2. **metamcp_default** - MetaMCP services
3. **docker_default** - Dify application stack
4. **nats_nats-internal** - NATS messaging
5. **castagram_castagram-network** - Media services
6. **dify-middlewares-dev_default** - Development middleware
7. **media_default** - Media stack
8. **docker_ssrf_proxy_network** - Security proxy network

## Project Structure

```text
.
├── core/
│   ├── portainer/
│   │   └── compose.yml
│   ├── traefik/
│   │   ├── scripts/
│   │   ├── traefik-data/
│   │   │   ├── dynamic/
│   │   │   └── scripts/
│   │   └── compose.yml
│   └── traefik-frontend/
│       ├── app/
│       │   ├── static/
│       │   └── templates/
│       ├── data/
│       ├── screenshots/
│       └── compose.yml
├── docs/
│   ├── rules/
│   └── session/
├── ffmpeg-mcp-server/
├── scripts/
└── stacks/
    ├── ai/
    │   ├── dify/
    │   │   └── docker/ (Active - Full stack running)
    │   ├── firecrawl/
    │   │   ├── apps/
    │   │   ├── examples/
    │   │   └── compose.yml
    │   ├── flowise/
    │   │   └── compose.yml
    │   ├── graphiti/
    │   │   ├── scripts/
    │   │   └── compose.yml
    │   ├── langflow/
    │   │   └── compose.yml
    │   ├── letta/
    │   │   └── compose.yml (Active)
    │   ├── litellm/
    │   │   └── compose.yml
    │   ├── mem0/
    │   │   ├── history/
    │   │   └── compose.yml
    │   └── n8n/
    │       └── compose.yml
    ├── devops/
    │   └── gocd/
    │       ├── godata/
    │       └── compose.yml
    ├── mcp/
    │   ├── pluggedin-app/
    │   │   ├── compose.yml
    │   │   ├── docker-compose.simple.yml
    │   │   └── docker-compose.dev.yml
    │   └── pluggedin-proxy/
    │       └── compose.yml
    ├── media/
    │   ├── exportarr/
    │   │   └── compose.yml
    │   ├── gluetun/ (Active)
    │   ├── jellyfin/
    │   │   ├── cache/
    │   │   ├── data/
    │   │   └── log/
    │   ├── prowlarr/
    │   │   ├── asp/
    │   │   ├── Backups/
    │   │   ├── Definitions/
    │   │   ├── logs/
    │   │   └── Sentry/
    │   ├── qbittorrent/ (Exited)
    │   │   ├── BT_backup/
    │   │   ├── GeoDB/
    │   │   ├── nova3/
    │   │   ├── qBittorrent/
    │   │   └── rss/
    │   ├── radarr/
    │   │   ├── asp/
    │   │   └── Sentry/
    │   └── compose.yml* (Active)
    ├── monitoring/
    │   └── compose.yml (Active - Full monitoring stack)
    ├── persistence/
    │   ├── couchdb/
    │   │   └── compose.yml
    │   ├── qdrant/
    │   │   └── compose.yml (Active)
    │   ├── redis/
    │   └── compose.yml
    ├── utils/
    │   ├── adguard/
    │   │   └── compose.yml (Active)
    │   ├── audiojangler/
    │   │   ├── data/
    │   │   └── compose.yml
    │   ├── marker/
    │   │   └── compose.yml
    │   ├── rustdesk/
    │   │   ├── data/
    │   │   └── compose.yml
    │   ├── scripts/
    │   │   ├── html/
    │   │   └── compose.yml
    │   └── syncthing/
    │       └── compose.yml
    ├── websites/
    └── Windows/
        └── compose.yml
```

## Key Observations

### 🟢 Healthy Services
- Most core services are running stably for 2+ days
- MetaMCP recently restarted (2 hours ago) and is healthy
- Monitoring stack fully operational
- Database services stable

### ⚠️ Issues to Address
1. **cAdvisor** - Extremely high CPU usage (171%)
2. **AdGuard Redirect** - Container unhealthy
3. **Dify Plugin Daemon** - Service exited
4. **QBittorrent** - Container exited (exit code 128)
5. **MetaMCP Production** - Exited 7 hours ago

### 📈 Resource Usage Highlights
- **Highest Memory**: Prometheus (772MiB), Letta (481MiB), MetaMCP (330MiB)
- **Highest CPU**: cAdvisor (171%), Prometheus (2%), PostgreSQL (1.26%)
- **Network Activity**: Significant traffic through Traefik, Prometheus, and Letta

## Recommendations

1. **Immediate Actions**:
   - Investigate and restart cAdvisor to resolve CPU issue
   - Check AdGuard Redirect health check configuration
   - Review MetaMCP Production exit logs

2. **Optimization Opportunities**:
   - Consider resource limits for cAdvisor
   - Review unused created/exited containers for cleanup
   - Consolidate overlapping services

3. **Security Considerations**:
   - All exposed services properly routed through Traefik
   - SSL/TLS enabled via Let's Encrypt
   - SSRF proxy active for Dify stack

**Last Updated**: 2025-09-16
**Total Active Stacks**: 10+
`*` Special compose configuration
