# Nats

This directory contains the `docker-compose` configuration for running Nats.

## Usage

To start the Nats service, run the following command from the root of the repository:

```bash
docker-compose -f stacks/utils/compose.yml up -d nats
```

The Nats server will be available at `nats://localhost:4222` and the monitoring interface will be at `http://nats.localhost:8222`.
