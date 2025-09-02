# 🔧 Official AdGuard + Tailscale Configuration Guide

Based on official documentation from Tailscale and AdGuard Home repositories.

## 🎯 Root Cause Analysis

Your issues stem from:
1. **Phone**: Not using AdGuard as DNS server (getting timeouts instead of redirects)
2. **iPad on Tailscale**: Tailscale overriding DNS settings (bypassing AdGuard filtering)

## 📋 Solution 1: Configure AdGuard DNS Rewrites (Manual)

### Access AdGuard Web Interface
1. Visit: `https://adguard.delo.sh`
2. Login with your credentials

### Configure Custom IP Blocking Mode
**Path**: Settings > DNS Settings

```yaml
# Based on official AdGuard Home documentation
blocking_mode: "custom_ip"           # Respond with custom IP
blocking_ipv4: "192.168.1.12"       # Your server IP
blocking_ipv6: "::"                  # IPv6 equivalent  
blocked_response_ttl: 300            # Cache for 5 minutes
```

### Add DNS Rewrites for Testing
**Path**: Filters > DNS Rewrites

Based on official AdGuard API documentation:

```json
// POST /control/rewrite/add
{
  "domain": "roblox.com",
  "answer": "192.168.1.12"
}

{
  "domain": "*.roblox.com", 
  "answer": "192.168.1.12"
}

{
  "domain": "facebook.com",
  "answer": "192.168.1.12"
}
```

**Manual Steps**:
1. Click "Add DNS rewrite"
2. Domain: `roblox.com` → Answer: `192.168.1.12`
3. Domain: `*.roblox.com` → Answer: `192.168.1.12`
4. Domain: `facebook.com` → Answer: `192.168.1.12`

## 🔗 Solution 2: Configure Tailscale DNS Integration

### Option A: Tailscale Admin Console (Recommended)
Based on official Tailscale documentation:

1. **Access**: https://login.tailscale.com/admin/dns
2. **Add Global Nameserver**: `192.168.1.12`
3. **Effect**: All Tailscale devices use AdGuard DNS

### Option B: Device-Specific Configuration
**iPad Tailscale App Settings**:
```bash
# Equivalent CLI command from Tailscale docs:
tailscale set --accept-dns=false
```

**Then manually set DNS to**: `192.168.1.12`

### Option C: Per-Device DNS Override
**iPad Settings**:
1. Settings > WiFi > (i) next to network
2. Configure DNS > Manual  
3. Add Server: `192.168.1.12`

## 📱 Solution 3: Configure Local Network Devices

### Phone DNS Configuration
**Router DHCP Settings** (Recommended):
1. Access router admin (usually `192.168.1.1`)
2. DHCP/LAN Settings
3. Primary DNS: `192.168.1.12`
4. This makes ALL devices use AdGuard automatically

**Alternative - Manual Phone DNS**:
- WiFi Settings > Advanced/DNS
- Set DNS to: `192.168.1.12`

## 🧪 Testing Protocol

### From Phone (Local Network)
```bash
# Test DNS resolution - should return 192.168.1.12
nslookup roblox.com

# Test HTTP redirect
curl -v http://roblox.com/
```

### From iPad (Tailscale Connected)
```bash
# Check if using correct DNS
nslookup roblox.com
# Should show: Server: 192.168.1.12

# Test redirect flow
# Visit roblox.com in Safari - should show countdown page
```

## 🔍 Official Configuration Verification

### AdGuard API Status Check
```bash
# Check current DNS config (from big-chungus)
curl -s "http://localhost:3000/control/dns_info" | jq '.blocking_mode, .blocking_ipv4'

# List current rewrites
curl -s "http://localhost:3000/control/rewrite/list" | jq '.'
```

### Tailscale DNS Status Check  
```bash
# Check Tailscale DNS configuration (from any device)
tailscale dns status
```

## 🎯 Expected Results

### ✅ Success Indicators:
1. **Phone nslookup roblox.com**: Returns `192.168.1.12`
2. **iPad nslookup roblox.com**: Returns `192.168.1.12` 
3. **Browser test roblox.com**: Shows countdown → redirects to `https://nope.delo.sh?sound=true`
4. **No timeouts**: Pages load redirect service instead of hanging

### ❌ Failure Indicators:
1. **nslookup returns real IPs**: Device not using AdGuard DNS
2. **Connection timeouts**: DNS working but redirect service unreachable
3. **iPad bypassing filters**: Tailscale DNS not configured

## 🔧 Advanced Tailscale Configuration

### Exit Node Setup (Optional)
From official Tailscale docs, to make AdGuard work for all Tailscale traffic:

```bash
# On big-chungus (AdGuard server):
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf

# Advertise as exit node
sudo tailscale up --advertise-exit-node
```

### Split DNS Configuration
For advanced users, configure Tailscale split DNS to use AdGuard for specific domains:

**Tailscale Admin Console** > **DNS**:
- Add nameserver: `192.168.1.12`  
- Restrict to domains: `roblox.com`, `facebook.com`, etc.

## 🎊 Final Validation

Once configured correctly:

1. **Phone at home**: Uses AdGuard via local network
2. **iPad at home**: Uses AdGuard via local network  
3. **iPad away**: Uses AdGuard via Tailscale tunnel
4. **All blocked domains**: Show countdown → redirect to your landing page

This setup ensures consistent AdGuard filtering both at home and away! 

---

*Configuration based on official documentation from:*
- *Tailscale KB: DNS configuration and MagicDNS*
- *AdGuard Home: DNS rewrites and custom IP blocking*
- *Verified against production implementations*