#!/usr/bin/env bash
set -euo pipefail

# ensure the service always runs from the project root
declare -r PROJECT_ROOT="/home/delorenj/docker/trunk-main"
cd "$PROJECT_ROOT"

# default port matches Traefik backend configuration
export PORT=${PORT:-45035}
export HOST=${HOST:-0.0.0.0}

exec npx vibe-kanban --host "$HOST"
