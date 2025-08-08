#!/bin/bash
# Performance monitoring script for qBittorrent stack
# Usage: ./performance-monitor.sh [--duration=seconds] [--output=file]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="/home/delorenj/docker/trunk-main/stacks/media"
MONITORING_DIR="$SCRIPT_DIR/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Default configuration
MONITOR_DURATION=300  # 5 minutes
OUTPUT_FILE="$MONITORING_DIR/performance_$TIMESTAMP.json"
INTERVAL=10  # 10 seconds between samples

mkdir -p "$MONITORING_DIR"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --duration=*)
            MONITOR_DURATION="${1#*=}"
            shift
            ;;
        --output=*)
            OUTPUT_FILE="${1#*=}"
            shift
            ;;
        --interval=*)
            INTERVAL="${1#*=}"
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --duration=SECONDS  Monitoring duration (default: 300)"
            echo "  --output=FILE      Output file (default: auto-generated)"
            echo "  --interval=SECONDS Sampling interval (default: 10)"
            echo "  --help             Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "=== qBittorrent Performance Monitor ==="
echo "Duration: ${MONITOR_DURATION}s"
echo "Interval: ${INTERVAL}s"
echo "Output: $OUTPUT_FILE"

# Initialize output file
cat > "$OUTPUT_FILE" << EOF
{
    "monitoring_session": {
        "start_time": "$(date -Iseconds)",
        "duration_seconds": $MONITOR_DURATION,
        "interval_seconds": $INTERVAL
    },
    "samples": []
}
EOF

cd "$STACK_DIR"

START_TIME=$(date +%s)
SAMPLE_COUNT=0

echo "Starting performance monitoring..."

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    
    if [ $ELAPSED -ge $MONITOR_DURATION ]; then
        break
    fi
    
    SAMPLE_TIMESTAMP=$(date -Iseconds)
    ((SAMPLE_COUNT++))
    
    echo "Collecting sample $SAMPLE_COUNT (${ELAPSED}s elapsed)"
    
    # Collect container stats
    QBIT_STATS=$(docker stats qbittorrent --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null | tail -1 || echo "N/A	N/A	N/A	N/A")
    GLUETUN_STATS=$(docker stats gluetun --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null | tail -1 || echo "N/A	N/A	N/A	N/A")
    
    # Parse qBittorrent stats
    QBIT_CPU=$(echo "$QBIT_STATS" | awk '{print $1}' | tr -d '%' || echo "0")
    QBIT_MEM=$(echo "$QBIT_STATS" | awk '{print $2}' | cut -d'/' -f1 || echo "0")
    QBIT_NET_IN=$(echo "$QBIT_STATS" | awk '{print $3}' | cut -d'/' -f1 || echo "0")
    QBIT_NET_OUT=$(echo "$QBIT_STATS" | awk '{print $3}' | cut -d'/' -f2 || echo "0")
    QBIT_DISK_READ=$(echo "$QBIT_STATS" | awk '{print $4}' | cut -d'/' -f1 || echo "0")
    QBIT_DISK_WRITE=$(echo "$QBIT_STATS" | awk '{print $4}' | cut -d'/' -f2 || echo "0")
    
    # Parse Gluetun stats
    GLUETUN_CPU=$(echo "$GLUETUN_STATS" | awk '{print $1}' | tr -d '%' || echo "0")
    GLUETUN_MEM=$(echo "$GLUETUN_STATS" | awk '{print $2}' | cut -d'/' -f1 || echo "0")
    
    # Get system load
    SYSTEM_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',' || echo "0")
    
    # Get disk usage
    DOWNLOADS_DISK=$(docker exec qbittorrent df -h /downloads 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%' || echo "0")
    VIDEO_DISK=$(docker exec qbittorrent df -h /video 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%' || echo "0")
    
    # Get network throughput via VPN
    VPN_RX_BYTES=$(docker exec gluetun cat /sys/class/net/tun0/statistics/rx_bytes 2>/dev/null || echo "0")
    VPN_TX_BYTES=$(docker exec gluetun cat /sys/class/net/tun0/statistics/tx_bytes 2>/dev/null || echo "0")
    
    # Get qBittorrent specific metrics via API (if accessible)
    QB_API_RESPONSE=$(curl -s http://localhost:8091/api/v2/transfer/info 2>/dev/null || echo "{}")
    
    # Create sample JSON
    cat > /tmp/performance_sample.json << EOF
{
    "timestamp": "$SAMPLE_TIMESTAMP",
    "elapsed_seconds": $ELAPSED,
    "containers": {
        "qbittorrent": {
            "cpu_percent": "$QBIT_CPU",
            "memory_usage": "$QBIT_MEM",
            "network_io": {
                "rx": "$QBIT_NET_IN",
                "tx": "$QBIT_NET_OUT"
            },
            "disk_io": {
                "read": "$QBIT_DISK_READ",
                "write": "$QBIT_DISK_WRITE"
            }
        },
        "gluetun": {
            "cpu_percent": "$GLUETUN_CPU",
            "memory_usage": "$GLUETUN_MEM"
        }
    },
    "system": {
        "load_average": "$SYSTEM_LOAD",
        "disk_usage": {
            "downloads_percent": $DOWNLOADS_DISK,
            "video_percent": $VIDEO_DISK
        }
    },
    "vpn": {
        "tun0_rx_bytes": $VPN_RX_BYTES,
        "tun0_tx_bytes": $VPN_TX_BYTES
    },
    "qbittorrent_api": $QB_API_RESPONSE
}
EOF
    
    # Add sample to output file
    jq '.samples += [input]' "$OUTPUT_FILE" /tmp/performance_sample.json > /tmp/updated_performance.json
    mv /tmp/updated_performance.json "$OUTPUT_FILE"
    rm -f /tmp/performance_sample.json
    
    sleep $INTERVAL
done

# Finalize output file with summary
END_TIME=$(date -Iseconds)
TOTAL_SAMPLES=$(jq '.samples | length' "$OUTPUT_FILE")

# Calculate basic statistics
AVG_QBIT_CPU=$(jq '[.samples[].containers.qbittorrent.cpu_percent | tonumber] | add / length' "$OUTPUT_FILE" 2>/dev/null || echo "0")
MAX_QBIT_CPU=$(jq '[.samples[].containers.qbittorrent.cpu_percent | tonumber] | max' "$OUTPUT_FILE" 2>/dev/null || echo "0")
AVG_SYSTEM_LOAD=$(jq '[.samples[].system.load_average | tonumber] | add / length' "$OUTPUT_FILE" 2>/dev/null || echo "0")

jq --arg end_time "$END_TIME" --arg total_samples "$TOTAL_SAMPLES" \
   --arg avg_cpu "$AVG_QBIT_CPU" --arg max_cpu "$MAX_QBIT_CPU" --arg avg_load "$AVG_SYSTEM_LOAD" \
   '.monitoring_session.end_time = $end_time | 
    .monitoring_session.total_samples = ($total_samples|tonumber) |
    .summary = {
        "qbittorrent": {
            "avg_cpu_percent": ($avg_cpu|tonumber),
            "max_cpu_percent": ($max_cpu|tonumber)
        },
        "system": {
            "avg_load": ($avg_load|tonumber)
        }
    }' \
   "$OUTPUT_FILE" > /tmp/final_performance.json
mv /tmp/final_performance.json "$OUTPUT_FILE"

echo "Performance monitoring completed"
echo "Total samples: $TOTAL_SAMPLES"
echo "Average CPU: ${AVG_QBIT_CPU}%"
echo "Max CPU: ${MAX_QBIT_CPU}%"
echo "Average Load: $AVG_SYSTEM_LOAD"
echo "Results saved to: $OUTPUT_FILE"