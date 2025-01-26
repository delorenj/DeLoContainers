# DeLoNET Squid Proxy

Network proxy service for content filtering and access control.

## Deployment
Service auto-deploys on push to main. For manual deployment:

1. Create passwords file:
```bash
htpasswd -c passwords kids
```

2. Create blocklists directory:
```bash
mkdir blocklists
```

3. Start service:
```bash
docker compose up -d
```

## Configuration

### Time Restrictions
- No access between 11 PM - 7 AM daily

### Blocking Rules
- Adult content (auto-updated from StevenBlack/hosts)
- Violence/gore sites
- Gambling domains
- Known malware domains (urlhaus database)
- VPN/Proxy services

### Client Setup
Run as Administrator on Windows clients:
```powershell
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyServer -Value "http://proxy.delonet.home:3128"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 1
```

## Maintenance
Blocklists auto-update weekly via `update-blocklists.sh`