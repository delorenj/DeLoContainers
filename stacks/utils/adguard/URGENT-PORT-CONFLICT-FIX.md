# 🚨 URGENT: DNS Port Conflict Resolution
*Hive Mind Collective Intelligence - Critical Fix Required*

## Issue Diagnosed
**systemd-resolved** is using port 53, preventing AdGuard Home from starting.

## 🎯 EXPERT-APPROVED SOLUTION (Choose One):

### Option 1: Alternative Port Configuration (RECOMMENDED)
Configure AdGuard to use alternative ports and update compose.yml:

```yaml
services:
  adguard:
    # ... existing config ...
    ports:
      # Use alternative DNS ports
      - "5353:53/udp"
      - "5353:53/tcp"
    # ... rest of config ...
```

**Then configure clients to use**: `192.168.1.12:5353` as DNS server

### Option 2: Disable systemd-resolved Stub Listener (ADVANCED)
**⚠️ Requires system-level changes:**

```bash
# Create resolved configuration override
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/adguard.conf <<EOF
[Resolve]
DNSStubListener=no
EOF

# Restart systemd-resolved
sudo systemctl restart systemd-resolved

# Verify port 53 is free
sudo netstat -tulnp | grep :53

# Then deploy AdGuard with standard port 53
docker compose up -d
```

### Option 3: Hybrid Approach (SECURE)
Keep systemd-resolved for system DNS, use AdGuard on alternative port for network filtering:

```yaml
# Modified compose.yml
services:
  adguard:
    image: adguard/adguardhome:latest
    container_name: adguard
    hostname: adguard
    volumes:
      - ./conf:/opt/adguardhome/conf
      - ./work:/opt/adguardhome/work
      - ./filters:/opt/adguardhome/filters
    ports:
      # Alternative DNS ports - no conflict
      - "5353:53/udp"  
      - "5353:53/tcp"
    networks:
      - proxy
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.adguard.entrypoints=websecure"
      - "traefik.http.routers.adguard.rule=Host(\`adguard.delo.sh\`)"
      - "traefik.http.routers.adguard.tls=true"
      - "traefik.http.routers.adguard.tls.certresolver=letsencrypt"
      - "traefik.http.services.adguard.loadbalancer.server.port=80"
      - "traefik.docker.network=proxy"
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

networks:
  proxy:
    external: true
```

## 🎯 RECOMMENDED IMPLEMENTATION

**Hive Mind Consensus**: Use **Option 3 (Hybrid)** for maximum compatibility.

### Steps to Implement:
1. Update compose.yml with port 5353
2. Deploy: `docker compose up -d`
3. Configure router/devices to use `192.168.1.12:5353` for DNS
4. Test Roblox blocking effectiveness

### Network Configuration:
- **Router DNS**: Set to `192.168.1.12:5353`
- **Individual devices**: Can point to `192.168.1.12:5353`
- **System DNS**: Remains on systemd-resolved (127.0.0.53)

## 🧪 Validation After Fix:
```bash
# Check AdGuard is running
docker compose ps

# Test DNS resolution with custom port
nslookup roblox.com 192.168.1.12 -port=5353

# Should return blocked/filtered response
```

## 🛡️ Security Impact:
- **POSITIVE**: No system DNS changes required
- **POSITIVE**: Maintains system stability  
- **NEUTRAL**: Requires manual client configuration
- **POSITIVE**: AdGuard gets full DNS filtering control

---

🎯 **NEXT ACTIONS**:
1. Choose implementation option
2. Apply the fix
3. Deploy and test
4. Configure network devices

**Hive Mind Status**: Standing by for implementation decision.