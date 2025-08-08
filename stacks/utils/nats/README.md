# NATS Messaging Stack

This directory contains a robust Docker Compose configuration for running NATS with JetStream support, monitoring, and helpful tooling.

## What is NATS?

NATS is a high-performance messaging system that enables:
- **Publish/Subscribe**: Send messages to topics that multiple subscribers can receive
- **Request/Reply**: Synchronous communication patterns
- **JetStream**: Persistent messaging with guaranteed delivery, replay, and stream processing

## Quick Start

### 1. Start the Stack

From the repository root:
```bash
docker-compose -f stacks/utils/nats/compose.yml up -d
```

### 2. Verify Everything is Running

```bash
# Check container status
docker ps | grep nats

# Test the connection
./stacks/utils/nats/scripts/test-connection.sh
```

### 3. Access the Monitoring Dashboard

Open your browser to: `http://localhost:8222`

## Available Services

| Service | Port | Purpose |
|---------|------|---------|
| NATS Client | 4222 | Application connections |
| HTTP Monitor | 8222 | Web dashboard & health checks |
| Cluster | 6222 | Server clustering (internal) |

## Basic Usage Examples

### Using the CLI Helper Script

```bash
# Get server info
./scripts/nats-cli.sh server info

# Publish a message
./scripts/nats-cli.sh pub greeting.hello "Hello World!"

# Subscribe to messages (run in separate terminal)
./scripts/nats-cli.sh sub greeting.hello

# List JetStream streams
./scripts/nats-cli.sh stream ls
```

### Direct Docker Commands

```bash
# Enter the NATS CLI container
docker exec -it nats-cli bash

# Or run commands directly
docker exec nats-cli nats pub test.subject "My message"
```

## JetStream (Persistent Messaging)

JetStream provides persistent, reliable messaging:

```bash
# Create a stream
./scripts/nats-cli.sh stream add ORDERS --subjects="orders.>" --storage=file

# Publish to the stream
./scripts/nats-cli.sh pub orders.new '{"id": 123, "item": "widget"}'

# Create a consumer
./scripts/nats-cli.sh consumer add ORDERS order_processor --pull

# Pull messages
./scripts/nats-cli.sh consumer next ORDERS order_processor
```

## Application Integration

### Connection URLs
- **Local Development**: `nats://localhost:4222`
- **From Docker Containers**: `nats://nats:4222`
- **External (via Traefik)**: `nats://nats.delo.sh:4222`

### Example Code (Node.js)

```javascript
import { connect } from 'nats';

const nc = await connect({ servers: 'nats://localhost:4222' });

// Simple pub/sub
nc.publish('greeting.hello', 'Hello World!');

const sub = nc.subscribe('greeting.hello');
for await (const m of sub) {
  console.log(`Received: ${m.string()}`);
}
```

## Configuration

- **Main Config**: `config/nats.conf`
- **Data Persistence**: Docker volume `nats_data`
- **Memory Limit**: 1GB for JetStream
- **File Storage**: 10GB for JetStream

## Monitoring & Health

### Health Check Endpoint
```bash
curl http://localhost:8222/healthz
```

### Key Monitoring URLs
- **Server Stats**: http://localhost:8222/varz
- **Connections**: http://localhost:8222/connz
- **Subscriptions**: http://localhost:8222/subsz
- **JetStream**: http://localhost:8222/jsz

## Development Tools

### Start with CLI Tools
```bash
docker-compose -f stacks/utils/nats/compose.yml --profile tools up -d
```

This includes the `nats-cli` container with the full NATS toolbox.

### Useful Commands

```bash
# Server statistics
./scripts/nats-cli.sh server info

# List all subjects with activity
./scripts/nats-cli.sh server report connections

# Monitor real-time message flow
./scripts/nats-cli.sh server report jetstream

# Benchmark performance
./scripts/nats-cli.sh bench test.perf --pub 10 --sub 10
```

## Security Notes

The current setup is configured for development. For production:

1. Enable authentication in `config/nats.conf`
2. Use TLS certificates
3. Configure proper firewall rules
4. Set resource limits appropriately

## Troubleshooting

### Common Issues

1. **Connection Refused**: Check if port 4222 is accessible
2. **Permission Denied**: Ensure Docker has proper permissions
3. **Out of Memory**: Adjust JetStream memory limits in config

### Debug Commands

```bash
# Check container logs
docker logs nats

# Test network connectivity
docker exec nats-cli nats server check connection

# Verify JetStream is enabled
./scripts/nats-cli.sh server info | grep -i jetstream
```

## Next Steps

1. Try the examples above
2. Read the [NATS documentation](https://docs.nats.io/)
3. Explore JetStream for persistent messaging needs
4. Set up monitoring alerts using the HTTP endpoints

## Architecture

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────┐
│   Applications  │────│     NATS     │────│  JetStream  │
│                 │    │   (Port 4222)│    │  (Persist)  │
└─────────────────┘    └──────────────┘    └─────────────┘
                              │
                       ┌──────────────┐
                       │  Monitoring  │
                       │  (Port 8222) │
                       └──────────────┘
```
