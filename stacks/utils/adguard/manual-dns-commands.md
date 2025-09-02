# Manual DNS Implementation Commands

**Run these commands to implement dual DNS:**

```bash
# 1. Create systemd-resolved configuration
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/adguard.conf > /dev/null <<EOF
[Resolve]
DNSStubListener=no
DNS=127.0.0.1#53
Cache=yes
EOF

# 2. Update resolv.conf
sudo rm -f /etc/resolv.conf
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

# 3. Restart systemd-resolved
sudo systemctl restart systemd-resolved

# 4. Verify port 53 is free
ss -tulnp | grep :53

# 5. Deploy AdGuard
cd /home/delorenj/docker/trunk-main/stacks/utils/adguard
docker compose down
docker compose up -d

# 6. Test DNS
dig @127.0.0.1 google.com
dig @100.66.29.76 google.com
```