# 🌐 Tailscale + AdGuard Integration Plan
*Infrastructure Whisperer Implementation - "Shodan" MCP Server*

## Current Infrastructure Assessment

### ✅ Discovered Configuration
- **Tailscale Status**: Active and healthy
- **Tailscale IP**: `100.66.29.76` (big-chungus)
- **AdGuard Status**: Running on port `5353` (avoiding systemd-resolved conflict)
- **Current DNS Flow**: systemd-resolved (127.0.0.53) → upstream
- **Tailnet**: 10 devices (7 offline, 3 online including big-chungus)

### 🎯 Integration Objective
Create seamless DNS flow: **Tailnet Devices → Tailscale MagicDNS → AdGuard (100.66.29.76:5353) → Upstream DNS**

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐    ┌────────────────┐
│ Tailnet Devices │───▶│ Tailscale        │───▶│ AdGuard         │───▶│ Upstream DNS   │
│ (100.x.x.x)     │    │ MagicDNS         │    │ 100.66.29.76    │    │ (Cloudflare,   │
│                 │    │ Global Nameserver│    │ Port 5353       │    │  Quad9, etc.)  │
└─────────────────┘    └──────────────────┘    └─────────────────┘    └────────────────┘
```

## Implementation Plan

### Phase 1: AdGuard Configuration Updates

#### 1.1 Configure AdGuard to Listen on Tailscale Interface

**Objective**: Ensure AdGuard accepts DNS queries from all Tailnet devices

**Action Required**: Update AdGuard configuration to bind to both local and Tailscale interfaces:
- Local: `127.0.0.1:5353` (for local queries)
- Tailscale: `100.66.29.76:5353` (for Tailnet queries)
- All interfaces: `0.0.0.0:5353` (current - already correct)

**Status**: ✅ Already configured correctly in compose.yml

#### 1.2 Upstream DNS Configuration
Configure AdGuard with reliable upstream DNS servers:
- Primary: `1.1.1.1` (Cloudflare)
- Secondary: `9.9.9.9` (Quad9)
- Fallback: `8.8.8.8` (Google)

### Phase 2: Tailscale Admin Console Configuration

#### 2.1 Global Nameserver Setup
**Critical Configuration**: In Tailscale Admin Console → DNS settings:

```
Global nameserver: 100.66.29.76:5353
```

**This ensures**:
- All Tailnet DNS queries route through big-chungus AdGuard instance
- MagicDNS still resolves `.ts.net` domains internally
- AdGuard filters all external DNS requests

#### 2.2 MagicDNS Preservation
**Important**: Keep MagicDNS enabled to maintain:
- `big-chungus.tailnet-name.ts.net` resolution
- Inter-device connectivity via friendly names
- Tailscale's internal DNS magic

#### 2.3 Search Domains (Optional)
Configure search domain for your network:
```
Search domains: delo.sh (if desired for local services)
```

### Phase 3: Docker Network Integration

#### 3.1 Tailscale Container Access
**Current Status**: AdGuard runs in Docker with host networking effective through port mapping

**Optimization Opportunity**: Consider adding Tailscale to the proxy network for direct access:

```yaml
# Future enhancement - Tailscale sidecar
services:
  tailscale:
    image: tailscale/tailscale:latest
    container_name: tailscale-sidecar
    hostname: tailscale-adguard
    environment:
      - TS_AUTHKEY=${TAILSCALE_AUTH_KEY}
      - TS_STATE_DIR=/var/lib/tailscale
      - TS_HOSTNAME=adguard-relay
    volumes:
      - tailscale-data:/var/lib/tailscale
    networks:
      - proxy
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    restart: unless-stopped
```

**Current Approach**: Use host networking (simpler, already working)

### Phase 4: DNS Flow Validation

#### 4.1 Test Scenarios
1. **Tailnet Device → AdGuard**: `nslookup google.com 100.66.29.76 -port=5353`
2. **Tailnet Device → MagicDNS**: `ping big-chungus.tailnet-name.ts.net`
3. **Local System**: `nslookup google.com 127.0.0.53`
4. **Filtering Test**: `nslookup malware.testing.com 100.66.29.76 -port=5353`

#### 4.2 Expected Results
- External domains: Resolved through AdGuard with filtering applied
- `.ts.net` domains: Resolved through MagicDNS
- Blocked domains: Return NXDOMAIN or custom block page
- Performance: <50ms latency for most queries

### Phase 5: Monitoring and Optimization

#### 5.1 AdGuard Metrics to Monitor
- Query volume from Tailnet devices
- Block rate effectiveness
- Upstream DNS latency
- Cache hit ratio

#### 5.2 Tailscale Metrics
- DNS query success rate
- MagicDNS resolution times
- Peer connectivity stability

## Implementation Steps

### Step 1: Backup Current Configuration
```bash
# Backup AdGuard configuration
cp -r /home/delorenj/docker/trunk-main/stacks/utils/adguard/conf ./backup-$(date +%Y%m%d)

# Document current Tailscale DNS settings
tailscale status --json > tailscale-backup-$(date +%Y%m%d).json
```

### Step 2: Configure Tailscale Global Nameserver
**Manual Action Required in Tailscale Admin Console**:
1. Navigate to https://login.tailscale.com/admin/dns
2. Set Global nameserver to: `100.66.29.76:5353`
3. Ensure MagicDNS remains enabled
4. Apply configuration

### Step 3: Test Integration
```bash
# From any Tailnet device, test DNS resolution
nslookup google.com 100.66.29.76 -port=5353

# Test MagicDNS still works
ping big-chungus

# Test filtering (should be blocked if configured)
nslookup malware.testing.com 100.66.29.76 -port=5353
```

### Step 4: Monitor and Validate
- Check AdGuard query logs for Tailnet device queries
- Verify no DNS resolution failures across the network
- Confirm filtering is working as expected

## Advanced Optimizations (Future)

### 1. DNS-over-HTTPS (DoH) Support
Configure AdGuard to support DoH for enhanced privacy:
- Enable DoH in AdGuard settings
- Update Tailscale to use DoH endpoint if needed

### 2. Split DNS Configuration
Configure different upstream DNS servers for different domains:
- Work domains → Corporate DNS
- Personal domains → Public DNS
- Development domains → Internal DNS

### 3. GeoDNS Integration
Implement location-aware DNS resolution for optimal performance.

### 4. Redundancy Setup
Configure secondary AdGuard instance for failover:
- Second instance on different Tailnet node
- Tailscale configured with multiple nameservers

## Security Considerations

### ✅ Strengths
- All DNS traffic filtered through AdGuard
- Encrypted Tailscale tunnel protects DNS queries
- No external DNS exposure
- Centralized logging and monitoring

### ⚠️ Considerations
- Single point of failure (big-chungus down = no DNS)
- AdGuard configuration must be secured
- Monitor for DNS amplification attacks
- Regular filter list updates essential

### 🛡️ Mitigations
- Regular AdGuard backups
- Monitor AdGuard health via Docker healthchecks
- Implement alerting for DNS failures
- Keep alternative DNS fallback documented

## Success Metrics

### Primary Metrics
- **DNS Resolution Success Rate**: >99.5%
- **Query Latency**: <50ms average
- **Block Rate**: Appropriate to filtering goals
- **Uptime**: >99.9% availability

### Secondary Metrics
- MagicDNS functionality preserved
- No impact on Tailnet connectivity
- Proper filtering effectiveness
- Performance meets or exceeds current setup

## Rollback Plan

If integration fails:
1. Remove Global nameserver from Tailscale admin console
2. Devices will revert to local DNS settings
3. MagicDNS continues to work normally
4. AdGuard remains available for manual configuration

## Implementation Timeline

- **Planning & Backup**: 15 minutes
- **Tailscale Configuration**: 5 minutes
- **Testing & Validation**: 30 minutes
- **Monitoring Setup**: 15 minutes
- **Total**: ~65 minutes

## Conclusion

This integration leverages the existing stable AdGuard setup on port 5353 and Tailscale's robust Global nameserver feature to create a seamless DNS filtering experience across the entire Tailnet. The approach respects both systems' strengths while creating a powerful, centralized DNS filtering solution.

The "Shodan" naming reflects the omnipresent nature of this DNS infrastructure - like the System Shock AI, it will have visibility into and control over all network communications, ensuring security and filtering across your entire digital domain.