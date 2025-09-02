# 🔗 Tailscale + AdGuard Integration Guide

## Problem: iPad on Tailscale Not Filtering

Your iPad connected to Tailscale is bypassing AdGuard filtering because Tailscale manages its own DNS settings.

## Solution Options

### Option 1: Configure Tailscale DNS (Recommended)
Make Tailscale use your AdGuard server for all devices.

**Steps:**
1. **Tailscale Admin Panel**: https://login.tailscale.com/admin/dns
2. **Add Global Nameserver**:
   - Click "Add nameserver"
   - Enter: `192.168.1.12` (your AdGuard server)
   - This applies to ALL Tailscale devices
3. **Test**: iPad should now use AdGuard DNS even when on Tailscale

### Option 2: Per-Device DNS Override
Configure specific devices to use AdGuard.

**iPad Settings:**
1. Open Tailscale app
2. Settings > Use DNS server
3. Enter: `192.168.1.12`
4. Save

**Alternative - iOS DNS Settings:**
1. Settings > WiFi > (i) next to network
2. Configure DNS > Manual
3. Add Server: `192.168.1.12`
4. Save

### Option 3: Tailscale MagicDNS Integration
Use Tailscale's MagicDNS with AdGuard as upstream.

**Tailscale Admin Panel:**
1. DNS tab > MagicDNS (enable)
2. Global nameservers > Add `192.168.1.12`
3. Override local DNS: Enable

## Advanced: AdGuard as Tailscale Exit Node

If you want AdGuard filtering for ALL Tailscale traffic:

**On big-chungus (AdGuard server):**
```bash
# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Configure as Tailscale exit node
sudo tailscale up --advertise-exit-node

# In Tailscale admin panel, approve the exit node
```

**On devices:**
```bash
# Use big-chungus as exit node
tailscale up --exit-node=big-chungus
```

## Testing Tailscale DNS Integration

### From iPad (Tailscale connected):
```bash
# Test 1: Check DNS resolution
nslookup roblox.com
# Expected: 192.168.1.12 (if Tailscale DNS configured correctly)

# Test 2: Check what DNS server is being used
nslookup google.com
# Should show 192.168.1.12 as the server if configured correctly

# Test 3: Test AdGuard filtering
# Visit roblox.com in Safari - should show countdown page
```

## Troubleshooting

### iPad Still Not Filtering:
1. **Check Tailscale DNS**: App settings > Current DNS
2. **Disable/Re-enable**: Turn Tailscale off/on
3. **Check iOS DNS**: Settings > WiFi > DNS (should show 192.168.1.12)
4. **Clear DNS cache**: Restart iPad

### Tailscale Admin Panel Issues:
1. **Permissions**: Ensure you're admin of the Tailscale network
2. **Propagation**: DNS changes may take 5-10 minutes
3. **Device restart**: Restart devices after DNS changes

### Mixed Network Behavior:
If you want different behavior for home vs. away:
- **Home**: Direct AdGuard (192.168.1.12)
- **Away**: Tailscale with AdGuard DNS
- **Both**: Should work the same if configured correctly

## Expected Results

### ✅ Success Indicators:
- **iPad at home**: Uses AdGuard via local network
- **iPad away**: Uses AdGuard via Tailscale tunnel
- **Phone at home**: Uses AdGuard via local DNS/router
- **All devices**: Show countdown → redirect to nope.delo.sh

### 🔧 Configuration Summary:
1. **Router DHCP**: Primary DNS = 192.168.1.12 (for all local devices)
2. **Tailscale DNS**: Global nameserver = 192.168.1.12 (for remote access)
3. **AdGuard**: Custom IP blocking = 192.168.1.12, DNS rewrites for test domains
4. **Redirect service**: Running on port 8888 with Traefik HTTPS support

This setup ensures AdGuard filtering works both at home and away! 🎯