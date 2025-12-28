# Manual Roblox Blocking Setup

## Current Status
- Roblox filter file exists at: `/home/delorenj/docker/trunk-main/stacks/utils/adguard/filters/roblox-block.txt`
- AdGuard Home is running at: `http://192.168.1.12` (DNS) and `https://adguard.delo.sh` (Web UI)
- Son's phone IP: `192.168.1.70` (NOT in bypass list - good!)

## Steps to Enable Roblox Blocking

### Option 1: Via Web UI (Recommended)

1. Open AdGuard Home web interface:
   - Visit: `https://adguard.delo.sh`
   - Or: `http://192.168.1.12:6767`

2. Log in with admin credentials

3. Add Custom Filter:
   - Go to: **Filters** → **DNS blocklists**
   - Click: **Add blocklist** → **Add a custom list**
   - Enter:
     - **Name**: `Roblox Block List`
     - **URL**: `file:///opt/adguardhome/filters/roblox-block.txt`
   - Click **Save**

4. Verify filter is enabled (toggle should be ON)

### Option 2: Via API (Alternative)

```bash
cd /home/delorenj/docker/trunk-main/stacks/utils/adguard

# Copy filter to container
docker cp filters/roblox-block.txt adguard:/opt/adguardhome/filters/roblox-block.txt

# Add via API (replace ADMIN_PASSWORD)
curl -X POST "http://localhost:6767/control/filtering/add_url" \
  -H "Content-Type: application/json" \
  -u "admin:ADMIN_PASSWORD" \
  -d '{
    "url": "file:///opt/adguardhome/filters/roblox-block.txt",
    "name": "Roblox Block List",
    "whitelist": false
  }'

# Force refresh
curl -X POST "http://localhost:6767/control/filtering/refresh" \
  -H "Content-Type: application/json" \
  -u "admin:ADMIN_PASSWORD" \
  -d '{"whitelist": false}'
```

## Configure Son's Phone to Use AdGuard DNS

### iPhone/iOS:
1. Open **Settings** → **Wi-Fi**
2. Tap the **(i)** next to your connected network
3. Scroll to **DNS** → Tap **Configure DNS**
4. Select **Manual**
5. Remove existing DNS servers
6. Add DNS Server: `192.168.1.12`
7. Tap **Save**

### Android:
1. Open **Settings** → **Network & Internet** → **Wi-Fi**
2. Long-press your connected network → **Modify network**
3. Show **Advanced options**
4. Change **IP settings** to **Static**
5. Set **DNS 1**: `192.168.1.12`
6. Leave **DNS 2** blank (or use `1.1.1.1` as backup)
7. Tap **Save**

## Testing

### From Son's Phone:
1. Open Safari/Chrome
2. Try visiting: `roblox.com`
3. Should see: Connection error or blocked page

### From Your Machine:
```bash
# Should return NXDOMAIN or block page IP
nslookup roblox.com 192.168.1.12
nslookup rbxcdn.com 192.168.1.12
```

## What Gets Blocked

The filter blocks 40+ domains including:
- `roblox.com` (main site)
- `rbxcdn.com` (critical - all game assets)
- `web.roblox.com` (web version)
- All API endpoints (auth, economy, friends, etc.)
- Mobile apps and CDN subdomains

## Bypass Verification

Your current bypasses (these will NOT be blocked):
- Your machines: `192.168.1.12`, `192.168.1.50`, `127.0.0.1`
- Mom's devices: `192.168.1.10`, `100.117.190.125`, "Mommy's iPhone"
- External: `73.195.114.125`

**Son's phone (192.168.1.70) is NOT bypassed** - blocking will work!

## Troubleshooting

### Roblox Still Works:
1. Verify filter is enabled in AdGuard UI
2. Confirm phone is using `192.168.1.12` as DNS
3. Restart phone's Wi-Fi connection
4. Check AdGuard query log for blocked requests

### Check AdGuard Logs:
```bash
docker logs adguard | grep roblox
```

### Force DNS Flush on Phone:
- iPhone: Airplane mode ON → wait 5 sec → OFF
- Android: Settings → Apps → Chrome → Storage → Clear cache

## Notes

- Blocking happens at DNS level (very effective)
- Works on home Wi-Fi only (not cellular data)
- For cellular data blocking, consider Tailscale DNS integration
- Admin devices (yours, mom's) remain unaffected
