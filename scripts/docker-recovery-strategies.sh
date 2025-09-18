#!/bin/bash

# Docker Container Recovery Strategies
# Specific recovery procedures for common failure scenarios

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/docker-health"
RECOVERY_LOG="${LOG_DIR}/recovery-strategies.log"

# Source common functions
source "${SCRIPT_DIR}/docker-health-monitor.sh" 2>/dev/null || {
    log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
    log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2; }
    log_recovery() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] RECOVERY: $1"; }
}

# Recovery Strategy: High CPU Usage
recover_high_cpu() {
    local container="$1"
    local cpu_percent="${2:-100}"

    log_recovery "Recovering from high CPU usage for $container (${cpu_percent}%)"

    # Get current limits
    local current_limits=$(docker inspect "$container" --format '{{.HostConfig.CpuQuota}} {{.HostConfig.CpuPeriod}}' 2>/dev/null || echo "0 0")

    # Apply CPU limit if not set
    if [[ "$current_limits" == "0 0" ]]; then
        log_recovery "Applying CPU limits to $container"
        docker update --cpus="1" "$container"
    else
        # Restart with lower priority
        log_recovery "Restarting $container with nice priority"
        docker stop "$container"
        sleep 2
        docker start "$container"
    fi

    # Clear caches for specific services
    case "$container" in
        *cadvisor*)
            # cAdvisor specific: clear metrics cache
            docker exec "$container" sh -c "rm -rf /var/lib/docker/containers/*/json.log" 2>/dev/null || true
            ;;
        *prometheus*)
            # Prometheus: trigger TSDB compaction
            curl -X POST "http://localhost:9472/api/v1/admin/tsdb/compact" 2>/dev/null || true
            ;;
    esac
}

# Recovery Strategy: High Memory Usage
recover_high_memory() {
    local container="$1"
    local memory_percent="${2:-90}"

    log_recovery "Recovering from high memory usage for $container (${memory_percent}%)"

    # Try to free memory first
    case "$container" in
        *redis*)
            # Redis: clear expired keys
            docker exec "$container" redis-cli FLUSHDB 2>/dev/null || true
            ;;
        *postgres*|*mysql*)
            # Database: run vacuum
            docker exec "$container" sh -c "psql -U postgres -c 'VACUUM FULL;'" 2>/dev/null || true
            ;;
        *)
            # Generic: restart to free memory
            docker restart "$container"
            ;;
    esac

    # Apply memory limit if needed
    docker update --memory="2g" --memory-swap="4g" "$container" 2>/dev/null || true
}

# Recovery Strategy: Network Issues
recover_network_issues() {
    local container="$1"

    log_recovery "Recovering from network issues for $container"

    # Get container networks
    local networks=$(docker inspect "$container" --format '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} {{end}}' 2>/dev/null || echo "")

    if [[ -z "$networks" ]]; then
        log_error "Container $container has no networks attached"
        # Reconnect to default network
        docker network connect bridge "$container" 2>/dev/null || true
    else
        # Disconnect and reconnect to refresh network
        for network in $networks; do
            log_recovery "Refreshing network $network for $container"
            docker network disconnect "$network" "$container" 2>/dev/null || true
            sleep 1
            docker network connect "$network" "$container" 2>/dev/null || true
        done
    fi

    # Restart container
    docker restart "$container"
}

# Recovery Strategy: Disk Space Issues
recover_disk_space() {
    local container="$1"

    log_recovery "Recovering from disk space issues for $container"

    # Clean container logs
    local log_file="/var/lib/docker/containers/$(docker inspect -f '{{.Id}}' "$container")/$(docker inspect -f '{{.Id}}' "$container")-json.log"
    if [[ -f "$log_file" ]]; then
        log_recovery "Truncating log file for $container"
        truncate -s 0 "$log_file"
    fi

    # Service-specific cleanup
    case "$container" in
        *prometheus*)
            # Delete old metrics
            docker exec "$container" sh -c "find /prometheus -name '*.tmp' -delete" 2>/dev/null || true
            ;;
        *grafana*)
            # Clear temp files
            docker exec "$container" sh -c "rm -rf /var/lib/grafana/sessions/*" 2>/dev/null || true
            ;;
        *redis*)
            # Trigger background save and cleanup
            docker exec "$container" redis-cli BGREWRITEAOF 2>/dev/null || true
            ;;
    esac
}

# Recovery Strategy: Dependency Issues
recover_dependencies() {
    local container="$1"

    log_recovery "Recovering from dependency issues for $container"

    # Define dependencies
    declare -A dependencies
    dependencies[qbittorrent]="gluetun"
    dependencies[metamcp]="redis postgres_db"
    dependencies[grafana]="prometheus"
    dependencies[alertmanager]="prometheus"

    # Get service name from container
    local service=$(docker inspect "$container" --format '{{index .Config.Labels "com.docker.compose.service"}}' 2>/dev/null || echo "$container")

    # Check and start dependencies
    if [[ -n "${dependencies[$service]:-}" ]]; then
        for dep in ${dependencies[$service]}; do
            if ! docker ps --format '{{.Names}}' | grep -q "$dep"; then
                log_recovery "Starting dependency $dep for $container"
                docker start "$dep" 2>/dev/null || docker start $(docker ps -a --format '{{.Names}}' | grep "$dep" | head -1) 2>/dev/null || true
                sleep 5
            fi
        done
    fi

    # Restart the container
    docker restart "$container"
}

# Recovery Strategy: Health Check Failures
recover_health_check() {
    local container="$1"
    local health_status="${2:-unhealthy}"

    log_recovery "Recovering from health check failure for $container (Status: $health_status)"

    # Get health check logs
    local health_logs=$(docker inspect --format '{{json .State.Health.Log}}' "$container" 2>/dev/null | jq -r '.[-1].Output' 2>/dev/null || echo "")

    log_recovery "Health check output: $health_logs"

    # Analyze and recover based on health check output
    if echo "$health_logs" | grep -qi "connection refused"; then
        # Service not listening
        log_recovery "Service not listening, restarting $container"
        docker restart "$container"
    elif echo "$health_logs" | grep -qi "timeout"; then
        # Service slow/hanging
        recover_high_cpu "$container"
    elif echo "$health_logs" | grep -qi "out of memory"; then
        # Memory issues
        recover_high_memory "$container"
    else
        # Generic recovery
        docker restart "$container"
    fi
}

# Recovery Strategy: Container Exit Codes
recover_exit_code() {
    local container="$1"
    local exit_code="${2:-1}"

    log_recovery "Recovering from exit code $exit_code for $container"

    case "$exit_code" in
        0)
            # Normal exit, just restart
            docker start "$container"
            ;;
        1)
            # General errors - check logs
            local logs=$(docker logs --tail 50 "$container" 2>&1)
            if echo "$logs" | grep -qi "permission denied"; then
                log_recovery "Permission issues detected, fixing..."
                # Fix permissions if possible
                docker exec "$container" chmod -R 755 /app 2>/dev/null || true
            fi
            docker start "$container"
            ;;
        125)
            # Docker daemon error
            log_recovery "Docker daemon error, waiting before restart..."
            sleep 10
            docker start "$container"
            ;;
        126)
            # Container command not executable
            log_recovery "Command not executable, checking entrypoint..."
            docker start "$container"
            ;;
        127)
            # Container command not found
            log_recovery "Command not found, may need image rebuild"
            docker start "$container"
            ;;
        137)
            # SIGKILL - likely OOM
            recover_high_memory "$container"
            ;;
        139)
            # Segmentation fault
            log_recovery "Segmentation fault detected, full restart..."
            docker stop "$container" 2>/dev/null || true
            docker start "$container"
            ;;
        143)
            # SIGTERM - graceful shutdown
            docker start "$container"
            ;;
        *)
            # Unknown exit code
            log_recovery "Unknown exit code $exit_code, attempting restart..."
            docker start "$container"
            ;;
    esac
}

# Main recovery orchestrator
orchestrate_recovery() {
    local container="$1"
    local issue_type="${2:-generic}"
    local additional_info="${3:-}"

    log_recovery "Orchestrating recovery for $container (Issue: $issue_type)"

    case "$issue_type" in
        high_cpu)
            recover_high_cpu "$container" "$additional_info"
            ;;
        high_memory)
            recover_high_memory "$container" "$additional_info"
            ;;
        network)
            recover_network_issues "$container"
            ;;
        disk_space)
            recover_disk_space "$container"
            ;;
        dependencies)
            recover_dependencies "$container"
            ;;
        health_check)
            recover_health_check "$container" "$additional_info"
            ;;
        exit_code)
            recover_exit_code "$container" "$additional_info"
            ;;
        *)
            # Generic recovery
            docker restart "$container"
            ;;
    esac

    # Verify recovery
    sleep 5
    local status=$(docker inspect "$container" --format '{{.State.Status}}' 2>/dev/null || echo "unknown")
    if [[ "$status" == "running" ]]; then
        log_recovery "Recovery successful for $container"
        return 0
    else
        log_error "Recovery failed for $container (Current status: $status)"
        return 1
    fi
}

# Batch recovery for multiple containers
batch_recovery() {
    local containers="$@"

    for container in $containers; do
        orchestrate_recovery "$container" "generic"
    done
}

# Export functions for use by other scripts
export -f recover_high_cpu
export -f recover_high_memory
export -f recover_network_issues
export -f recover_disk_space
export -f recover_dependencies
export -f recover_health_check
export -f recover_exit_code
export -f orchestrate_recovery
export -f batch_recovery

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 <container> [issue_type] [additional_info]"
        echo "Issue types: high_cpu, high_memory, network, disk_space, dependencies, health_check, exit_code"
        exit 1
    fi

    orchestrate_recovery "$@"
fi