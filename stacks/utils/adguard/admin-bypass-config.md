# 🛡️ Admin Bypass Configuration for AdGuard Home

## Method 1: Client-Based Bypass (Recommended)

### Via Web Interface:
1. Go to: **https://adguard.delo.sh**
2. Navigate to **Settings → Client Settings**
3. Click **"Add Client"**
4. Configure:
   - **Name**: Admin Device
   - **Identifier**: IP address or MAC address of admin device
   - **Use global settings**: ❌ (Uncheck)
   - **Filtering enabled**: ❌ (Uncheck)
   - **Safe Browsing**: ❌ (Uncheck)
   - **Parental Control**: ❌ (Uncheck)

### For Multiple Admin Devices:
Add each admin device separately with filtering disabled.

## Method 2: DNS-Based Bypass

### Via Upstream DNS Override:
1. Go to **Settings → DNS Settings**
2. Under **"Private reverse DNS servers"**, add:
   ```
   [/admin.local/]8.8.8.8
   ```
3. Configure admin devices to use `.admin.local` suffix

## Method 3: Network-Based Bypass

### For Specific IP Ranges:
1. **Settings → Client Settings**
2. Add client with IP range: `192.168.1.100-192.168.1.110`
3. Disable all filtering for this range

## Method 4: Tailscale Tag-Based (Advanced)

### Using Tailscale ACLs + AdGuard:
```json
// In Tailscale ACL
"tagOwners": {
  "tag:admin": ["your-email@domain.com"]
}

// AdGuard client config for tagged IPs
// Add Tailscale IPs of tagged devices as unfiltered clients
```

## Implementation Steps:

### Step 1: Identify Admin Devices
```bash
# Get current device info
ip addr show | grep "inet 192"
tailscale ip  # For Tailscale IP
```

### Step 2: Add to AdGuard
- **Your current IP**: Configure as unfiltered client
- **Other admin devices**: Add their IPs/MACs

### Step 3: Test
```bash
# From admin device - should work unfiltered
nslookup roblox.com
# From regular device - should be blocked
```

## Recommended Configuration:

1. **Main admin device**: Use your current IP (192.168.1.12 or Tailscale IP)
2. **Other admin devices**: Add specific IPs
3. **Emergency bypass**: Keep one device always unfiltered

Would you like me to help configure this via the web interface, or do you have specific IP addresses/devices to whitelist?