#!/bin/bash

# Docker Container Health Monitor & Self-Healing Script
# Automatically detects and recovers unhealthy containers

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/docker-health"
LOG_FILE="${LOG_DIR}/health-monitor.log"
RECOVERY_LOG="${LOG_DIR}/recovery.log"
STATE_FILE="${LOG_DIR}/container-state.json"
ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"
CHECK_INTERVAL="${CHECK_INTERVAL:-30}"
MAX_RESTART_ATTEMPTS="${MAX_RESTART_ATTEMPTS:-3}"
COOLDOWN_PERIOD="${COOLDOWN_PERIOD:-300}"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Logging functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

log_recovery() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] RECOVERY: $1" | tee -a "$RECOVERY_LOG"
}

# Alert function
send_alert() {
    local message="$1"
    local severity="${2:-warning}"

    log "ALERT [$severity]: $message"

    # Send to webhook if configured
    if [[ -n "$ALERT_WEBHOOK" ]]; then
        curl -X POST "$ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"[$severity] $message\",\"severity\":\"$severity\"}" \
            2>/dev/null || log_error "Failed to send alert"
    fi

    # Send to Alertmanager if available
    if docker ps --format '{{.Names}}' | grep -q "alertmanager"; then
        curl -X POST "http://localhost:9784/api/v1/alerts" \
            -H "Content-Type: application/json" \
            -d "[{
                \"labels\": {
                    \"alertname\": \"ContainerHealth\",
                    \"severity\": \"$severity\",
                    \"container\": \"${3:-unknown}\"
                },
                \"annotations\": {
                    \"summary\": \"$message\"
                }
            }]" 2>/dev/null || true
    fi
}

# Load state
load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo "{}"
    fi
}

# Save state
save_state() {
    echo "$1" > "$STATE_FILE"
}

# Get container restart count from state
get_restart_count() {
    local container="$1"
    local state=$(load_state)
    echo "$state" | jq -r ".\"$container\".restart_count // 0"
}

# Get last restart time from state
get_last_restart() {
    local container="$1"
    local state=$(load_state)
    echo "$state" | jq -r ".\"$container\".last_restart // 0"
}

# Update container state
update_state() {
    local container="$1"
    local restart_count="$2"
    local state=$(load_state)

    state=$(echo "$state" | jq \
        --arg container "$container" \
        --arg count "$restart_count" \
        --arg time "$(date +%s)" \
        '.[$container] = {"restart_count": ($count | tonumber), "last_restart": ($time | tonumber)}')

    save_state "$state"
}

# Reset container state
reset_state() {
    local container="$1"
    local state=$(load_state)
    state=$(echo "$state" | jq "del(.\"$container\")")
    save_state "$state"
}

# Check if container is in cooldown
in_cooldown() {
    local container="$1"
    local last_restart=$(get_last_restart "$container")
    local current_time=$(date +%s)
    local time_diff=$((current_time - last_restart))

    [[ $time_diff -lt $COOLDOWN_PERIOD ]]
}

# Container recovery strategies
recover_container() {
    local container="$1"
    local status="$2"
    local health_status="${3:-}"

    log_recovery "Attempting recovery for container: $container (Status: $status, Health: $health_status)"

    # Check cooldown
    if in_cooldown "$container"; then
        log "Container $container is in cooldown period. Skipping recovery."
        return 0
    fi

    # Get restart count
    local restart_count=$(get_restart_count "$container")

    # Check if max restarts reached
    if [[ $restart_count -ge $MAX_RESTART_ATTEMPTS ]]; then
        log_error "Container $container has reached maximum restart attempts ($MAX_RESTART_ATTEMPTS)"
        send_alert "Container $container failed after $MAX_RESTART_ATTEMPTS restart attempts" "critical" "$container"
        return 1
    fi

    # Recovery strategies based on status
    case "$status" in
        "Exited"*)
            log_recovery "Container $container has exited. Attempting restart..."
            if docker start "$container" 2>/dev/null; then
                log_recovery "Successfully restarted container: $container"
                update_state "$container" $((restart_count + 1))
                send_alert "Container $container was restarted successfully" "info" "$container"
                return 0
            else
                log_error "Failed to restart container: $container"
                return 1
            fi
            ;;

        "Dead")
            log_recovery "Container $container is dead. Removing and recreating..."
            docker rm -f "$container" 2>/dev/null || true

            # Try to recreate using docker-compose if available
            compose_file=$(docker inspect "$container" --format '{{index .Config.Labels "com.docker.compose.project.config_files"}}' 2>/dev/null || echo "")
            if [[ -n "$compose_file" ]] && [[ -f "$compose_file" ]]; then
                project=$(docker inspect "$container" --format '{{index .Config.Labels "com.docker.compose.project"}}' 2>/dev/null || echo "")
                service=$(docker inspect "$container" --format '{{index .Config.Labels "com.docker.compose.service"}}' 2>/dev/null || echo "")

                if [[ -n "$project" ]] && [[ -n "$service" ]]; then
                    log_recovery "Recreating container using docker-compose..."
                    cd "$(dirname "$compose_file")"
                    if docker compose -p "$project" up -d "$service" 2>/dev/null; then
                        log_recovery "Successfully recreated container: $container"
                        reset_state "$container"
                        send_alert "Container $container was recreated successfully" "info" "$container"
                        return 0
                    fi
                fi
            fi

            log_error "Failed to recreate container: $container"
            return 1
            ;;

        "Restarting")
            log "Container $container is already restarting. Waiting..."
            sleep 10
            ;;

        "Created")
            log_recovery "Container $container is created but not running. Starting..."
            if docker start "$container" 2>/dev/null; then
                log_recovery "Successfully started container: $container"
                reset_state "$container"
                return 0
            fi
            ;;

        *)
            # Check health status for running containers
            if [[ "$health_status" == "unhealthy" ]]; then
                log_recovery "Container $container is unhealthy. Attempting restart..."
                if docker restart "$container" 2>/dev/null; then
                    log_recovery "Successfully restarted unhealthy container: $container"
                    update_state "$container" $((restart_count + 1))
                    send_alert "Unhealthy container $container was restarted" "warning" "$container"
                    return 0
                else
                    log_error "Failed to restart unhealthy container: $container"
                    return 1
                fi
            fi
            ;;
    esac

    return 0
}

# Special recovery for specific containers
special_recovery() {
    local container="$1"

    case "$container" in
        "cadvisor")
            # cAdvisor often has high CPU, try limiting resources
            log_recovery "Applying special recovery for cAdvisor (high CPU issue)"
            docker update --cpus="2" --memory="512m" "$container" 2>/dev/null || true
            docker restart "$container"
            ;;

        "adguard-redirect")
            # AdGuard redirect might need network refresh
            log_recovery "Applying special recovery for AdGuard Redirect"
            docker network disconnect bridge "$container" 2>/dev/null || true
            docker network connect bridge "$container" 2>/dev/null || true
            docker restart "$container"
            ;;

        *"metamcp"*)
            # MetaMCP might need dependent services
            log_recovery "Checking MetaMCP dependencies"
            docker ps --format '{{.Names}}' | grep -q "redis" || docker start redis 2>/dev/null || true
            docker ps --format '{{.Names}}' | grep -q "postgres_db" || docker start postgres_db 2>/dev/null || true
            sleep 5
            docker restart "$container"
            ;;

        "qbittorrent")
            # QBittorrent needs VPN connection
            log_recovery "Checking QBittorrent VPN dependency"
            if ! docker ps --format '{{.Names}}' | grep -q "gluetun"; then
                docker start gluetun 2>/dev/null || true
                sleep 10
            fi
            docker restart "$container"
            ;;
    esac
}

# Main monitoring loop
monitor_containers() {
    log "Starting container health monitoring..."

    while true; do
        # Get all containers
        containers=$(docker ps -a --format "{{.Names}}:{{.Status}}:{{.Health}}" 2>/dev/null || echo "")

        if [[ -z "$containers" ]]; then
            log_error "Failed to get container list"
            sleep "$CHECK_INTERVAL"
            continue
        fi

        # Check each container
        while IFS=: read -r name status health; do
            # Skip if empty
            [[ -z "$name" ]] && continue

            # Clean up status
            status=$(echo "$status" | awk '{print $1}')

            # Check if container needs recovery
            needs_recovery=false

            case "$status" in
                "Exited"|"Dead"|"Created")
                    needs_recovery=true
                    ;;
                "Up")
                    # Check health status
                    if [[ "$health" == *"unhealthy"* ]]; then
                        needs_recovery=true
                    fi
                    ;;
            esac

            # Perform recovery if needed
            if $needs_recovery; then
                log "Container $name needs recovery (Status: $status, Health: $health)"

                # Try standard recovery
                if ! recover_container "$name" "$status" "$health"; then
                    # Try special recovery
                    special_recovery "$name"
                fi
            else
                # Reset state for healthy containers
                if [[ $(get_restart_count "$name") -gt 0 ]]; then
                    local last_restart=$(get_last_restart "$name")
                    local current_time=$(date +%s)
                    local time_diff=$((current_time - last_restart))

                    # Reset if healthy for more than cooldown period
                    if [[ $time_diff -gt $((COOLDOWN_PERIOD * 2)) ]]; then
                        log "Container $name has been healthy. Resetting restart count."
                        reset_state "$name"
                    fi
                fi
            fi

        done <<< "$containers"

        # Clean up old state entries
        current_containers=$(docker ps -a --format "{{.Names}}" | tr '\n' ' ')
        state=$(load_state)
        for container in $(echo "$state" | jq -r 'keys[]'); do
            if ! echo "$current_containers" | grep -q "$container"; then
                log "Removing state for non-existent container: $container"
                reset_state "$container"
            fi
        done

        sleep "$CHECK_INTERVAL"
    done
}

# Signal handlers
cleanup() {
    log "Shutting down health monitor..."
    exit 0
}

trap cleanup SIGINT SIGTERM

# Main
main() {
    log "Docker Health Monitor started"
    log "Configuration:"
    log "  - Check interval: ${CHECK_INTERVAL}s"
    log "  - Max restart attempts: $MAX_RESTART_ATTEMPTS"
    log "  - Cooldown period: ${COOLDOWN_PERIOD}s"
    log "  - Log directory: $LOG_DIR"

    # Start monitoring
    monitor_containers
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi