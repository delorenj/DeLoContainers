# Docker Service Map

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
    │   ├── letta/
    │   │   └── compose.yml
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
    ├── media/
    │   ├── exportarr/
    │   │   └── compose.yml
    │   ├── gluetun/
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
    │   ├── qbittorrent/
    │   │   ├── BT_backup/
    │   │   ├── GeoDB/
    │   │   ├── nova3/
    │   │   ├── qBittorrent/
    │   │   └── rss/
    │   ├── radarr/
    │   │   ├── asp/
    │   │   └── Sentry/
    │   └── compose.yml*
    ├── monitoring/
    │   └── compose.yml
    ├── persistence/
    │   ├── couchdb/
    │   │   └── compose.yml
    │   ├── qdrant/
    │   │   └── compose.yml
    │   ├── redis/
    │   └── compose.yml
    ├── utils/
    │   ├── adguard/
    │   │   └── compose.yml
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
    └── websites/
```

**Summary**  
74 directories, 23 files  
`*` Special compose configuration
