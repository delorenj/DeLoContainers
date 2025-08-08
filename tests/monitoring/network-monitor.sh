#!/bin/bash
# Network monitoring script for qBittorrent VPN setup
# Usage: ./network-monitor.sh [--duration=seconds] [--check-leaks]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="/home/delorenj/docker/trunk-main/stacks/media"
MONITORING_DIR="$SCRIPT_DIR/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Default configuration
MONITOR_DURATION=300  # 5 minutes
CHECK_LEAKS=false
OUTPUT_FILE="$MONITORING_DIR/network_monitor_$TIMESTAMP.json"
INTERVAL=30  # 30 seconds between checks

mkdir -p "$MONITORING_DIR"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --duration=*)
            MONITOR_DURATION="${1#*=}"
            shift
            ;;
        --check-leaks)
            CHECK_LEAKS=true
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
            echo "  --check-leaks      Enable comprehensive leak testing"
            echo "  --interval=SECONDS Check interval (default: 30)"
            echo "  --help             Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "=== qBittorrent Network Monitor ==="
echo "Duration: ${MONITOR_DURATION}s"
echo "Leak testing: $([ "$CHECK_LEAKS" = true ] && echo "Enabled" || echo "Disabled")"
echo "Output: $OUTPUT_FILE"

# Initialize output file
cat > "$OUTPUT_FILE" << EOF
{
    "monitoring_session": {
        "start_time": "$(date -Iseconds)",
        "duration_seconds": $MONITOR_DURATION,
        "leak_testing": $CHECK_LEAKS
    },
    "checks": []
}
EOF

cd "$STACK_DIR"

# Helper function to add check result
add_check_result() {
    local check_type="$1"
    local status="$2"
    local details="$3"
    local timestamp=$(date -Iseconds)
    
    cat > /tmp/network_check.json << EOF
{
    "timestamp": "$timestamp",
    "check_type": "$check_type",
    "status": "$status",
    "details": $details
}
EOF
    
    jq '.checks += [input]' "$OUTPUT_FILE" /tmp/network_check.json > /tmp/updated_network.json
    mv /tmp/updated_network.json "$OUTPUT_FILE"
    rm -f /tmp/network_check.json
}

START_TIME=$(date +%s)
CHECK_COUNT=0

echo "Starting network monitoring..."

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    
    if [ $ELAPSED -ge $MONITOR_DURATION ]; then
        break
    fi
    
    ((CHECK_COUNT++))
    echo "Network check $CHECK_COUNT (${ELAPSED}s elapsed)"
    
    # Check 1: VPN IP Address
    VPN_IP=$(docker exec gluetun curl -s --connect-timeout 10 ipinfo.io/ip 2>/dev/null || echo "ERROR")
    if [[ "$VPN_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        VPN_DETAILS=$(docker exec gluetun curl -s --connect-timeout 10 "ipinfo.io/$VPN_IP/json" 2>/dev/null || echo '{}')
        add_check_result "vpn_ip" "PASS" "$VPN_DETAILS"
        echo "  ✓ VPN IP: $VPN_IP"
    else
        add_check_result "vpn_ip" "FAIL" "{\"error\": \"$VPN_IP\"}"
        echo "  ✗ VPN IP check failed: $VPN_IP"
    fi
    
    # Check 2: DNS Resolution
    DNS_SERVERS=$(docker exec qbittorrent cat /etc/resolv.conf | grep nameserver | awk '{print $2}' | tr '\n' ',' | sed 's/,$//')
    DNS_TEST=$(docker exec qbittorrent nslookup google.com 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}' || echo "FAILED")
    
    if [ "$DNS_TEST" != "FAILED" ]; then
        add_check_result "dns_resolution" "PASS" "{\"servers\": \"$DNS_SERVERS\", \"resolved_ip\": \"$DNS_TEST\"}"
        echo "  ✓ DNS resolution working"
    else
        add_check_result "dns_resolution" "FAIL" "{\"servers\": \"$DNS_SERVERS\", \"error\": \"Resolution failed\"}"
        echo "  ✗ DNS resolution failed"
    fi
    
    # Check 3: Interface Status
    TUN_STATUS=$(docker exec qbittorrent ip link show tun0 2>/dev/null | grep "state UP" || echo "DOWN")
    TUN_IP=$(docker exec qbittorrent ip addr show tun0 2>/dev/null | grep "inet " | awk '{print $2}' || echo "NO_IP")
    
    if echo "$TUN_STATUS" | grep -q "state UP"; then
        add_check_result "interface_status" "PASS" "{\"status\": \"UP\", \"ip\": \"$TUN_IP\"}"
        echo "  ✓ tun0 interface UP ($TUN_IP)"
    else
        add_check_result "interface_status" "FAIL" "{\"status\": \"DOWN\", \"details\": \"$TUN_STATUS\"}"
        echo "  ✗ tun0 interface DOWN"
    fi
    
    # Check 4: Routing Table
    VPN_ROUTES=$(docker exec qbittorrent ip route | grep tun0 | wc -l || echo "0")
    DEFAULT_ROUTE=$(docker exec qbittorrent ip route | grep "default" | grep tun0 || echo "NO_DEFAULT_VIA_TUN")
    
    if [ "$VPN_ROUTES" -gt 0 ] && echo "$DEFAULT_ROUTE" | grep -q "tun0"; then
        add_check_result "routing" "PASS" "{\"vpn_routes\": $VPN_ROUTES, \"default_via_vpn\": true}"
        echo "  ✓ Traffic routing through VPN"
    else
        add_check_result "routing" "FAIL" "{\"vpn_routes\": $VPN_ROUTES, \"default_route\": \"$DEFAULT_ROUTE\"}"
        echo "  ✗ Traffic not routing through VPN properly"
    fi
    
    # Check 5: Port Connectivity
    TORRENT_PORT_LISTEN=$(docker exec qbittorrent netstat -ln | grep ":49152" || echo "NOT_LISTENING")
    WEBUI_PORT_LISTEN=$(docker exec qbittorrent netstat -ln | grep ":8091" || echo "NOT_LISTENING")
    
    PORT_STATUS="PASS"
    [ "$TORRENT_PORT_LISTEN" = "NOT_LISTENING" ] && PORT_STATUS="WARN"
    [ "$WEBUI_PORT_LISTEN" = "NOT_LISTENING" ] && PORT_STATUS="FAIL"
    
    add_check_result "port_connectivity" "$PORT_STATUS" "{\"torrent_port\": \"$(echo $TORRENT_PORT_LISTEN | head -c 20)\", \"webui_port\": \"$(echo $WEBUI_PORT_LISTEN | head -c 20)\"}"
    echo "  $([ "$PORT_STATUS" = "PASS" ] && echo "✓" || echo "!")Port connectivity: $PORT_STATUS"
    
    # Check 6: Network Throughput
    RX_BYTES_START=$(docker exec qbittorrent cat /sys/class/net/tun0/statistics/rx_bytes 2>/dev/null || echo "0")
    TX_BYTES_START=$(docker exec qbittorrent cat /sys/class/net/tun0/statistics/tx_bytes 2>/dev/null || echo "0")
    
    sleep 5  # Wait 5 seconds to measure throughput
    
    RX_BYTES_END=$(docker exec qbittorrent cat /sys/class/net/tun0/statistics/rx_bytes 2>/dev/null || echo "0")
    TX_BYTES_END=$(docker exec qbittorrent cat /sys/class/net/tun0/statistics/tx_bytes 2>/dev/null || echo "0")
    
    RX_RATE=$(( (RX_BYTES_END - RX_BYTES_START) / 5 ))  # bytes per second
    TX_RATE=$(( (TX_BYTES_END - TX_BYTES_START) / 5 ))  # bytes per second
    
    add_check_result "throughput" "INFO" "{\"rx_bytes_per_sec\": $RX_RATE, \"tx_bytes_per_sec\": $TX_RATE}"
    echo "  📊 Throughput - RX: ${RX_RATE} B/s, TX: ${TX_RATE} B/s"
    
    # Extended leak testing if enabled
    if [ "$CHECK_LEAKS" = true ]; then
        echo "  🔍 Performing leak tests..."
        
        # DNS Leak Test
        DNS_LEAK_SERVERS=$(docker exec qbittorrent dig +short @8.8.8.8 whoami.akamai.net 2>/dev/null || echo "FAILED")
        DNS_LEAK_SERVERS2=$(docker exec qbittorrent dig +short @1.1.1.1 whoami.akamai.net 2>/dev/null || echo "FAILED")
        
        add_check_result "dns_leak_test" "INFO" "{\"server_8.8.8.8\": \"$DNS_LEAK_SERVERS\", \"server_1.1.1.1\": \"$DNS_LEAK_SERVERS2\"}"
        
        # WebRTC Leak Test (limited in container environment)
        WEBRTC_TEST=$(docker exec qbittorrent timeout 10 curl -s "https://www.whatismyipaddress.com/api/ipv4" 2>/dev/null || echo "TIMEOUT")
        add_check_result "webrtc_leak_test" "INFO" "{\"detected_ip\": \"$WEBRTC_TEST\"}"
        
        # IPv6 Leak Test
        IPV6_TEST=$(docker exec qbittorrent timeout 10 curl -6 -s "https://ipv6.google.com" 2>/dev/null && echo "IPV6_ACTIVE" || echo "IPV6_INACTIVE")
        add_check_result "ipv6_leak_test" "INFO" "{\"ipv6_status\": \"$IPV6_TEST\"}"
        
        echo "    - DNS leak test completed"
        echo "    - WebRTC leak test completed"
        echo "    - IPv6 leak test completed"
    fi
    
    # Wait for next check (accounting for time already spent)
    CHECK_TIME=$(($(date +%s) - CURRENT_TIME))
    SLEEP_TIME=$((INTERVAL - CHECK_TIME))
    [ $SLEEP_TIME -gt 0 ] && sleep $SLEEP_TIME
done

# Generate summary
END_TIME=$(date -Iseconds)
TOTAL_CHECKS=$(jq '.checks | length' "$OUTPUT_FILE")
VPN_FAILURES=$(jq '[.checks[] | select(.check_type == "vpn_ip" and .status == "FAIL")] | length' "$OUTPUT_FILE")
DNS_FAILURES=$(jq '[.checks[] | select(.check_type == "dns_resolution" and .status == "FAIL")] | length' "$OUTPUT_FILE")
INTERFACE_FAILURES=$(jq '[.checks[] | select(.check_type == "interface_status" and .status == "FAIL")] | length' "$OUTPUT_FILE")

NETWORK_STABILITY=$(echo "scale=2; (($TOTAL_CHECKS - $VPN_FAILURES - $DNS_FAILURES - $INTERFACE_FAILURES) * 100) / $TOTAL_CHECKS" | bc -l 2>/dev/null || echo "0")

jq --arg end_time "$END_TIME" --arg total_checks "$TOTAL_CHECKS" \
   --arg vpn_failures "$VPN_FAILURES" --arg dns_failures "$DNS_FAILURES" \
   --arg interface_failures "$INTERFACE_FAILURES" --arg stability "$NETWORK_STABILITY" \
   '.monitoring_session.end_time = $end_time | 
    .summary = {
        "total_checks": ($total_checks|tonumber),
        "failures": {
            "vpn_connection": ($vpn_failures|tonumber),
            "dns_resolution": ($dns_failures|tonumber),
            "interface_status": ($interface_failures|tonumber)
        },
        "network_stability_percent": ($stability|tonumber)
    }' \
   "$OUTPUT_FILE" > /tmp/final_network.json
mv /tmp/final_network.json "$OUTPUT_FILE"

echo ""
echo "Network monitoring completed"
echo "Total checks: $TOTAL_CHECKS"
echo "VPN failures: $VPN_FAILURES"
echo "DNS failures: $DNS_FAILURES"
echo "Network stability: ${NETWORK_STABILITY}%"
echo "Results saved to: $OUTPUT_FILE"