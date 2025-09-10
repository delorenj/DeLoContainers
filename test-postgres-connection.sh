#!/bin/bash

# Test script for PostgreSQL connection from Docker containers
# This script tests if containers can connect to your native PostgreSQL

set -e

echo "Testing PostgreSQL connection from Docker containers..."

# Load environment variables
if [ -f .env ]; then
    source .env
    echo "Loaded environment variables from .env"
else
    echo "❌ .env file not found"
    exit 1
fi

# Test connection using a temporary container
echo "Testing connection to PostgreSQL at ${POSTGRES_HOST}:${POSTGRES_PORT}..."

docker run --rm \
    --add-host="host.docker.internal:host-gateway" \
    postgres:latest \
    psql -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "SELECT version();" \
    || {
        echo "❌ PostgreSQL connection failed!"
        echo ""
        echo "Troubleshooting steps:"
        echo "1. Ensure PostgreSQL is running on your host machine"
        echo "2. Check that PostgreSQL is listening on ${POSTGRES_HOST}:${POSTGRES_PORT}"
        echo "3. Verify user '${POSTGRES_USER}' exists and has access to database '${POSTGRES_DB}'"
        echo "4. Check PostgreSQL configuration (postgresql.conf and pg_hba.conf)"
        echo "5. Ensure PostgreSQL allows connections from Docker containers"
        echo ""
        echo "PostgreSQL configuration tips:"
        echo "- In postgresql.conf: listen_addresses = '*'"
        echo "- In pg_hba.conf: host all all 172.16.0.0/12 md5"
        echo "  (This allows connections from Docker's default networks)"
        exit 1
    }

echo "✅ PostgreSQL connection successful!"
echo ""
echo "Your services can connect to PostgreSQL using:"
echo "  Host: ${POSTGRES_HOST}"
echo "  Port: ${POSTGRES_PORT}"
echo "  Database: ${POSTGRES_DB}"
echo "  User: ${POSTGRES_USER}"
echo "  Password: ${POSTGRES_PASSWORD}"
echo ""
echo "Remember to add this to your service configurations:"
echo "  extra_hosts:"
echo "    - \"host.docker.internal:host-gateway\""
