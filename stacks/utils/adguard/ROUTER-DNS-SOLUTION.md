# Router DNS Configuration - Port 53 Solution

## The Problem
Routers expect DNS on port 53, but systemd-resolved is using it.

## ✅ RECOMMENDED SOLUTION: Disable systemd-resolved DNS stub

This will free up port 53 for AdGuard:

```bash
# 1. Disable DNS stub listener
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/adguard.conf <<EOF
[Resolve]
DNSStubListener=no
EOF

# 2. Backup and update resolv.conf
sudo cp /etc/resolv.conf /etc/resolv.conf.backup
sudo rm /etc/resolv.conf
sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

# 3. Restart systemd-resolved
sudo systemctl restart systemd-resolved

# 4. Update AdGuard to use port 53
cd /home/delorenj/docker/trunk-main/stacks/utils/adguard
# Edit compose.yml to use port 53:53 instead of 5353:53
docker compose up -d
```

## Alternative: Use Tailscale Global DNS (EASIER)
Instead of configuring your router, use Tailscale's Global nameserver:

1. Go to: https://login.tailscale.com/admin/dns
2. Add nameserver: `100.66.29.76`
3. Enable "Override local DNS"
4. This works on ALL networks (home, mobile, public Wi-Fi)

**Benefits of Tailscale approach:**
- ✅ Works everywhere, not just home network
- ✅ No router configuration needed  
- ✅ Secure encrypted DNS queries
- ✅ No system-level changes required

## If You Must Use Router DNS
After freeing port 53, set router DNS to: `192.168.1.12`

Which approach would you prefer?