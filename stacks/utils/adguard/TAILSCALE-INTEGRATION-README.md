# 🌐 Tailscale + AdGuard Integration
*"Shodan" MCP Server - Infrastructure Whisperer Implementation*

## Quick Start

This integration configures AdGuard Home as the Global nameserver for your entire Tailnet, providing centralized DNS filtering while preserving MagicDNS functionality.

### 🚀 One-Command Setup
```bash
# Run the integration script
./scripts/tailscale-integration.sh
```

### ✅ Current Status
- **Tailscale IP**: `100.66.29.76` (big-chungus)
- **AdGuard Port**: `5354` (avoiding systemd-resolved and mDNS conflicts)
- **Integration Status**: ⚠️ Requires Tailscale Admin Console configuration

## 🎯 What This Does

### Before Integration
```
Device → Local DNS → Internet
(No centralized filtering)
```

### After Integration
```
Tailnet Device → Tailscale MagicDNS → AdGuard (100.66.29.76:5354) → Upstream DNS
```

**Benefits**:
- ✅ All Tailnet traffic filtered through AdGuard
- ✅ MagicDNS preserved for `.ts.net` domains
- ✅ Centralized DNS logging and control
- ✅ No local device configuration needed

## 📋 Prerequisites Met

Your system is already configured correctly:
- ✅ Tailscale installed and running (`100.66.29.76`)
- ✅ AdGuard running on port `5353` (healthy)
- ✅ No port conflicts (systemd-resolved uses port 53)
- ✅ Docker networking configured properly

## 🔧 Implementation Steps

### Step 1: Run Integration Script
```bash
cd /home/delorenj/docker/trunk-main/stacks/utils/adguard
./scripts/tailscale-integration.sh
```

### Step 2: Configure Tailscale Admin Console
**MANUAL ACTION REQUIRED**:
1. Go to: https://login.tailscale.com/admin/dns
2. Set **Global nameserver** to: `100.66.29.76:5354`
3. Ensure **MagicDNS** is enabled
4. Click **Save**

### Step 3: Validate Integration
```bash
# Run comprehensive validation
./scripts/validate-dns-flow.sh

# Quick test
./scripts/validate-dns-flow.sh --quick
```

## 🧪 Testing Commands

### Test DNS Resolution via AdGuard
```bash
# Test external domain
nslookup google.com 100.66.29.76 -port=5353

# Test potentially blocked domain
nslookup roblox.com 100.66.29.76 -port=5353

# Test with dig (more detailed)
dig @100.66.29.76 -p 5353 google.com
```

### Test MagicDNS Functionality
```bash
# These should still work after integration
ping big-chungus
ping tiny-chungus.tailnet-name.ts.net
```

### Test from Other Tailnet Devices
Once configured, from any device on your Tailnet:
```bash
# Should resolve via AdGuard automatically
nslookup google.com

# Should be blocked if filters are active
nslookup malware.testing.com
```

## 📊 Monitoring

### AdGuard Admin Interface
- **URL**: https://adguard.delo.sh
- **Monitor**: Query logs, blocked requests, client activity

### AdGuard Container Logs
```bash
# View real-time logs
cd /home/delorenj/docker/trunk-main/stacks/utils/adguard
docker compose logs -f adguard

# Check container health
docker compose ps
```

### Tailscale Status
```bash
# Check Tailscale connectivity
tailscale status

# Check DNS configuration
tailscale status --json | jq '.DNS'
```

## 🔍 Troubleshooting

### Common Issues

#### DNS Resolution Fails
```bash
# Check AdGuard is accessible
nc -zv 100.66.29.76 5353

# Check container health
docker compose ps adguard

# Restart if needed
docker compose restart adguard
```

#### MagicDNS Not Working
- Ensure MagicDNS is enabled in Tailscale admin console
- Verify `.ts.net` domains resolve locally: `ping big-chungus`

#### Slow DNS Resolution
```bash
# Check DNS latency
dig @100.66.29.76 -p 5353 google.com | grep "Query time"

# Consider upstream DNS optimization in AdGuard settings
```

### Debug Mode
```bash
# Enable verbose Tailscale logging
sudo tailscale set --debug

# Check detailed DNS flow
./scripts/validate-dns-flow.sh
```

## 🎯 Expected Performance

### Metrics
- **DNS Resolution**: <50ms average latency
- **Uptime**: >99.9% (depends on big-chungus availability)
- **Filtering**: Based on your AdGuard filter configuration
- **MagicDNS**: Preserved functionality

### Success Indicators
- ✅ Tailnet devices resolve DNS via AdGuard automatically
- ✅ Query logs show traffic from other Tailnet IPs (100.x.x.x)
- ✅ Blocked domains return NXDOMAIN or custom block page
- ✅ `.ts.net` domains resolve correctly
- ✅ No DNS resolution failures

## 🔄 Rollback Procedure

If you need to revert:
1. Remove Global nameserver from Tailscale admin console
2. Devices will use local DNS settings
3. MagicDNS continues to work
4. AdGuard remains available for manual use

## 🛡️ Security Considerations

### Strengths
- All DNS queries encrypted in Tailscale tunnel
- Centralized filtering and logging
- No external DNS exposure
- Protected against DNS spoofing

### Limitations
- Single point of failure (big-chungus)
- Requires big-chungus to be online
- AdGuard configuration needs security review

## 📈 Advanced Optimizations

### DNS Caching
Configure AdGuard caching for better performance:
- TTL optimization
- Cache size tuning
- Prefetch popular domains

### Upstream DNS Optimization
Consider multiple upstream DNS providers:
- Primary: Cloudflare (1.1.1.1)
- Secondary: Quad9 (9.9.9.9)
- Fallback: Google (8.8.8.8)

### Redundancy Planning
For high availability:
- Secondary AdGuard instance on different Tailnet node
- Multiple Global nameservers in Tailscale
- Health monitoring and alerting

## 📞 Support

### Files and Scripts
- **Integration Plan**: `/docs/TAILSCALE-ADGUARD-INTEGRATION-PLAN.md`
- **Setup Script**: `./scripts/tailscale-integration.sh`
- **Validation Script**: `./scripts/validate-dns-flow.sh`

### Key Commands
```bash
# Check integration status
./scripts/tailscale-integration.sh --test-only

# Full validation
./scripts/validate-dns-flow.sh

# Monitor AdGuard
docker compose logs -f adguard

# Tailscale diagnostics
tailscale netcheck
```

---

**Infrastructure Whisperer** - *Making complex integrations feel like natural evolution*

*The "Shodan" naming reflects this system's omnipresent visibility into all network DNS traffic - like the System Shock AI, it provides comprehensive oversight and control over your digital domain.*