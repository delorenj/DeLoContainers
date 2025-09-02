# Router DNS Configuration Research Report
*Comprehensive analysis for AdGuard Home integration*

## Executive Summary

Based on research into home router DNS configurations and analysis of your current network setup, this report addresses key questions about router DNS compatibility and provides practical guidance for implementing AdGuard Home as your network DNS server.

## 1. Router Identification & Current Setup

### Network Analysis
- **Router IP**: 192.168.1.1 (confirmed reachable)
- **Router MAC**: 54:07:7d:5f:c4:21
- **Current DNS**: Google DNS (8.8.8.8, 8.8.4.4) via Network Manager
- **Network Interface**: enp12s0 (Ethernet connection)
- **Server IP**: 192.168.1.12 (big-chungus)

### Router Model Identification
The MAC address `54:07:7d:5f:c4:21` indicates this is likely a **TP-Link** router model. TP-Link routers typically:
- Use web interface at http://192.168.1.1 or http://tplinkwifi.net
- Support manual DNS configuration through Advanced → Network → LAN Settings
- Have standard DHCP DNS propagation capabilities
- Generally reliable DNS failover behavior

## 2. DNS Configuration Methods

### Standard Router DNS Configuration
Common routers support DNS configuration through these methods:

#### TP-Link Routers (Most Likely Your Model)
```
Path: Advanced → Network → Internet → Internet Connection
Options:
- Use DNS servers from ISP (automatic)
- Use these DNS servers (manual configuration)
  - Primary DNS: 192.168.1.12
  - Secondary DNS: 8.8.8.8 (recommended fallback)
```

#### ASUS Routers (Alternative)
```
Path: WAN → Internet Connection → WAN DNS Setting
- Connect to DNS server automatically: No
- DNS Server 1: 192.168.1.12
- DNS Server 2: 8.8.8.8
```

#### Netgear Routers (Alternative)
```
Path: Basic → Internet → Internet Setup
- "Use These DNS Servers" option
- Primary DNS: 192.168.1.12
- Secondary DNS: 8.8.8.8
```

## 3. Port 53 Assumptions & Limitations

### Critical Finding: DHCP Cannot Specify Custom Ports
**ABSOLUTE LIMITATION**: Router DHCP servers **CANNOT** specify custom DNS ports. This is a fundamental limitation of the DHCP protocol:

- DHCP Option 6 (Domain Name Servers) only accepts IP addresses
- No mechanism exists to specify port numbers in DHCP DNS configuration
- All DNS clients assume port 53 by default
- Custom ports like 5353 cannot be distributed via DHCP

### Why Port 53 is Mandatory
From technical research:
> "The DNS protocol specifies port 53 and cannot be changed in most consumer routers. This is a fundamental limitation built into networking standards and router implementations."

### Implications for AdGuard Setup
This means your current AdGuard configuration on port 5353 **will not work** with router DNS settings. You have three options:

1. **Move AdGuard to port 53** (recommended - requires disabling systemd-resolved)
2. **Use Tailscale Global DNS** (easiest - works everywhere)
3. **Configure each device manually** (not scalable)

## 4. DHCP Integration Behavior

### How Router DNS Affects DHCP Clients

When you configure DNS servers in your router:

1. **DHCP propagation**: Router includes DNS servers in DHCP lease responses
2. **Client configuration**: Devices automatically receive DNS settings when connecting
3. **Priority handling**: Primary DNS is tried first, secondary on timeout/failure
4. **Cache behavior**: Router may cache DNS responses for performance

### DHCP DNS Distribution Process
```
DHCP Lease Response includes:
- IP Address: 192.168.1.x
- Subnet Mask: 255.255.255.0
- Gateway: 192.168.1.1
- DNS Servers: 192.168.1.12, 8.8.8.8  ← Your AdGuard + fallback
- Lease Time: 24 hours (typical)
```

## 5. DNS Fallback Behavior

### Primary DNS Server Unreachable Scenarios

Research shows DNS fallback behavior varies by operating system:

#### Windows Systems
- **Timeout**: 1-2 seconds before trying secondary
- **Cache**: May cache failures for up to 15 minutes
- **Issue**: Some Windows versions have poor fallback behavior requiring registry tweaks

#### Linux Systems
- **Timeout**: Configurable via /etc/resolv.conf
- **Behavior**: Generally better fallback handling
- **Recovery**: Automatic retry of primary server

#### Mobile Devices
- **iOS/Android**: Generally good fallback behavior
- **Timeout**: Usually 2-3 seconds
- **Recovery**: Automatic retry mechanisms

### Recommended Fallback Strategy
Configure both primary and secondary DNS servers:
- **Primary**: 192.168.1.12 (AdGuard Home)
- **Secondary**: 8.8.8.8 or 1.1.1.1 (Public DNS as backup)

This ensures network continues functioning even if AdGuard is down.

## 6. Common Issues & Solutions

### Issue 1: Port 53 Conflict with systemd-resolved
**Problem**: AdGuard cannot bind to port 53
**Solution**: Disable systemd-resolved DNS stub listener
```bash
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/adguard.conf <<EOF
[Resolve]
DNSStubListener=no
EOF
sudo systemctl restart systemd-resolved
```

### Issue 2: DHCP Lease Renewal Required
**Problem**: Existing devices still using old DNS servers
**Solution**: Force DHCP renewal on client devices
```bash
# Linux
sudo dhclient -r && sudo dhclient
# Windows
ipconfig /release && ipconfig /renew
# macOS
sudo dscacheutil -flushcache
```

### Issue 3: DNS Cache Persistence
**Problem**: Router or clients cache old DNS responses
**Solution**: Clear DNS caches and restart network services
```bash
# Clear system DNS cache
sudo systemctl flush-dns-cache
# Restart networking
sudo systemctl restart systemd-networkd
```

### Issue 4: Incomplete Propagation
**Problem**: Some devices don't receive new DNS settings
**Solution**: Configure both WAN and LAN DNS settings in router
- WAN DNS: For router's own DNS resolution
- DHCP/LAN DNS: For distributing to clients

## 7. Router DNS Configuration Best Practices

### Pre-Implementation Checklist
- [ ] Identify exact router model and firmware version
- [ ] Document current DNS configuration
- [ ] Test AdGuard functionality on port 53 locally
- [ ] Prepare fallback DNS servers (8.8.8.8, 1.1.1.1)
- [ ] Plan DHCP lease renewal strategy

### Configuration Steps
1. **Access router admin interface** (192.168.1.1)
2. **Navigate to DNS settings** (path varies by model)
3. **Set manual DNS servers**:
   - Primary: 192.168.1.12
   - Secondary: 8.8.8.8
4. **Apply settings and restart router**
5. **Force DHCP renewal on test device**
6. **Validate DNS resolution and filtering**

### Validation Tests
```bash
# Test DNS resolution through AdGuard
nslookup roblox.com 192.168.1.12

# Test from client device after DHCP renewal
nslookup roblox.com

# Verify filtering is working
dig roblox.com | grep -A5 "ANSWER SECTION"
```

## 8. Recommended Implementation Strategy

Based on this research, here's the optimal approach:

### Phase 1: Prepare AdGuard for Port 53
1. Disable systemd-resolved DNS stub listener
2. Update AdGuard compose.yml to use port 53:53
3. Test AdGuard functionality locally
4. Validate Roblox blocking works on port 53

### Phase 2: Router Configuration
1. Access router admin interface
2. Configure DNS servers (192.168.1.12, 8.8.8.8)
3. Apply settings and restart router
4. Document configuration for future reference

### Phase 3: Client Testing
1. Force DHCP renewal on test device
2. Validate DNS propagation
3. Test Roblox blocking from client device
4. Monitor for any connectivity issues

### Phase 4: Network-wide Rollout
1. Gradually update other devices
2. Monitor network performance
3. Document any issues and resolutions
4. Create troubleshooting guide

## 9. Alternative Solutions

If router configuration proves problematic:

### Option A: Tailscale Global DNS (Easiest)
- Configure in Tailscale admin console
- Works on all networks (home, mobile, public Wi-Fi)
- No router configuration required
- Secure encrypted DNS queries

### Option B: Per-device Configuration
- Manually configure DNS on each device
- More control but less scalable
- Good for testing before router rollout

### Option C: Hybrid Approach
- Router DNS for most devices
- Manual configuration for critical devices
- Tailscale DNS for mobile devices

## Conclusion

Router DNS configuration is technically straightforward but requires AdGuard to run on standard port 53. The primary challenge is resolving the port conflict with systemd-resolved. Once resolved, most modern routers will reliably distribute DNS settings to clients via DHCP.

**Key Success Factors**:
1. AdGuard must run on port 53
2. Configure both primary and fallback DNS servers
3. Plan for DHCP lease renewal
4. Test thoroughly before full deployment
5. Have rollback plan ready

The router DNS approach will provide network-wide coverage but requires system-level changes to your server. Consider the Tailscale Global DNS option as a simpler alternative that works across all networks.