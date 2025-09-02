# AdGuard Custom Redirect Setup

## Overview
This configuration redirects blocked requests to your custom landing page at `https://nope.delo.sh?sound=true` using a lightweight nginx-based redirect service.

## Architecture
```
Blocked Request → AdGuard DNS → Custom IP (redirect service) → Your Landing Page
```

## Components

### 1. Redirect Service (`adguard-redirect`)
- **Image**: Custom nginx-alpine build
- **Port**: 8888 (host) → 80 (container)
- **Function**: Captures blocked requests and redirects to your landing page
- **Features**:
  - 3-second countdown with visual feedback
  - Passes blocked domain info to your landing page
  - Prevents caching of redirect page
  - Health check endpoint at `/health`

### 2. Modified AdGuard Configuration
- **Blocking Mode**: Custom IP
- **Target IP**: Container IP of redirect service
- **TTL**: 300 seconds (5 minutes)

## Setup Instructions

### Step 1: Deploy the Services
```bash
cd /home/delorenj/docker/trunk-main/stacks/utils/adguard
docker compose up -d
```

### Step 2: Configure AdGuard
Run the configuration script:
```bash
./configure-redirect.sh
```

**OR** Manual Configuration:
1. Access AdGuard admin panel: `https://adguard.delo.sh`
2. Go to **Settings** > **DNS settings**
3. Set **Blocking mode** to **Custom IP**
4. Set **Custom blocking IPv4** to the redirect service IP
5. Set **Custom blocking IPv6** to `::`
6. Set **Blocked response TTL** to `300`

### Step 3: Test the Configuration
1. Try accessing a blocked domain (e.g., if Roblox is blocked)
2. You should see the redirect page with countdown
3. After 3 seconds, you'll be forwarded to `https://nope.delo.sh?sound=true`

## How It Works

### Request Flow
1. **User requests blocked domain** → `roblox.com`
2. **AdGuard DNS lookup** → Returns redirect service IP instead of NXDOMAIN
3. **Browser connects** → Redirect service on port 8888
4. **Redirect page loads** → Shows countdown and blocked domain info
5. **Automatic redirect** → Forwards to `https://nope.delo.sh?sound=true&blocked=roblox.com`

### Redirect Page Features
- **Visual feedback**: Animated block icon and countdown
- **Domain information**: Shows which domain was blocked
- **Flexible redirect**: Includes blocked domain as parameter
- **No caching**: Ensures fresh redirects every time
- **Responsive design**: Works on desktop and mobile

## Advanced Configuration

### Custom Redirect Timing
Edit `redirect-service/index.html` and change the countdown value:
```javascript
let count = 3; // Change this value (seconds)
```

### Immediate Redirect
Add `?immediate=true` to any blocked request to skip countdown:
```
http://blocked-domain.com/?immediate=true
```

### Additional URL Parameters
The redirect includes useful information:
- `sound=true` - Your requested sound parameter
- `blocked=<domain>` - The domain that was blocked
- Original query parameters are preserved

## Monitoring & Troubleshooting

### Check Service Status
```bash
docker compose ps
docker compose logs adguard-redirect
```

### Health Check
```bash
curl http://localhost:8888/health
# Should return: OK
```

### View AdGuard Logs
```bash
docker compose logs adguard
```

### Verify DNS Configuration
```bash
nslookup blocked-domain.com localhost
# Should return the redirect service IP
```

## Files Created

### Service Files
- `redirect-service/index.html` - Redirect page with countdown
- `redirect-service/nginx.conf` - Nginx configuration
- `redirect-service/Dockerfile` - Container build instructions

### Configuration Files
- `compose.yml` - Updated with redirect service
- `configure-redirect.sh` - Automated configuration script
- `docs/CUSTOM-REDIRECT-SETUP.md` - This documentation

## Security Considerations

- **No external access**: Redirect service only accessible via AdGuard
- **No privilege escalation**: Running with `no-new-privileges:true`
- **Minimal attack surface**: Simple nginx with no unnecessary features
- **No persistent data**: Stateless redirect service

## Customization Options

### Different Landing Page
Edit `redirect-service/index.html` and change the redirect URL:
```javascript
window.location.href = 'https://your-custom-page.com';
```

### Custom Styling
Modify the CSS in `redirect-service/index.html` for different appearance.

### Different Port
Change the port mapping in `compose.yml`:
```yaml
ports:
  - "9999:80"  # Use port 9999 instead of 8888
```

## Rollback Instructions

### Restore Original Configuration
```bash
# Stop services
docker compose down

# Remove redirect service from compose.yml
# Restore AdGuard blocking mode to NXDOMAIN

# Restart AdGuard only
docker compose up -d adguard
```

### Remove Custom Files
```bash
rm -rf redirect-service/
rm configure-redirect.sh
```

This setup provides a seamless way to redirect blocked requests to your custom landing page while maintaining the security and performance benefits of AdGuard Home.