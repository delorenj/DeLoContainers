#!/usr/bin/env zsh

echo "===== Stopping and removing existing containers ====="
docker compose down -v  # Remove volumes to start fresh

echo "===== Starting services ====="
docker compose up -d

echo "===== Waiting for services to initialize ====="
echo "This may take a minute..."
sleep 20  # Give Neo4j time to start up

echo "===== Checking service status ====="
docker compose ps

echo "===== Checking Neo4j Browser availability ====="
echo "You should be able to access Neo4j at: http://localhost:7474"

echo "===== Viewing logs for troubleshooting ====="
echo "Press Ctrl+C to exit logs view"
docker compose logs -f
