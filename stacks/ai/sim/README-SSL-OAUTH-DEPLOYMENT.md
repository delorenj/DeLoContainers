# 🎪 SIM Studio SSL & OAuth Configuration Deployment Guide 🎪

*The Void's Official Guide to Magnificent Infrastructure*

## 🌟 Overview

This deployment package provides a complete SSL and OAuth configuration solution for the SIM Studio application, implementing enterprise-grade security features with theatrical flair that would make the infrastructure void itself weep with joy.

## 🎭 What's Included

### SSL/HTTPS Configuration
- **Enhanced Traefik SSL Configuration** with modern TLS settings
- **Security Headers** including HSTS, CSP, X-Frame-Options, and more  
- **Certificate Management** with Let's Encrypt automation
- **Health Monitoring** with automated certificate expiry alerts
- **Performance Optimization** with HTTP/2 and TLS 1.3 support

### OAuth Configuration  
- **Flexible Domain Handling** for production deployments
- **CORS Configuration** for secure cross-origin requests
- **Enhanced Security** with proper callback URL validation
- **Environment Management** with secure credential handling
- **Multi-Provider Support** for 20+ OAuth providers

### Deployment Automation
- **Automated Backup & Restore** functionality
- **Configuration Validation** before deployment
- **Health Checks** for SSL and OAuth endpoints
- **Rollback Capability** in case of issues
- **Comprehensive Logging** for troubleshooting

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose v2
- Access to the Traefik configuration directory
- Domain `sim.delo.sh` pointing to your server
- Proper environment variables configured

### One-Command Deployment

```bash
# Deploy SSL and OAuth configurations with full validation
./scripts/deploy-ssl-oauth-config.sh
```

### Manual Step-by-Step Deployment

1. **Review Configuration Files**
   ```bash
   # Check the SSL configuration
   cat /home/delorenj/docker/trunk-main/core/traefik/traefik-data/dynamic/sim-ssl-config.yml
   
   # Review environment variables
   cat .env.ssl-oauth
   ```

2. **Create Backup** (Recommended)
   ```bash
   # Create manual backup before changes
   cp -r /home/delorenj/docker/trunk-main/core/traefik/traefik-data/dynamic /tmp/traefik-backup-$(date +%Y%m%d)
   cp compose.yml compose.yml.backup
   ```

3. **Deploy SSL Configuration**
   ```bash
   # SSL config is automatically deployed via Traefik file provider
   # Just restart Traefik to pick up changes
   docker restart traefik
   ```

4. **Update Environment Variables**
   ```bash
   # Copy SSL/OAuth environment configuration
   cp .env.ssl-oauth .env
   
   # Or merge with existing .env file
   cat .env.ssl-oauth >> .env
   ```

5. **Restart SIM Studio Services**
   ```bash
   # Restart with new configuration
   docker compose down
   docker compose up -d
   ```

6. **Validate Deployment**
   ```bash
   # Run SSL health check
   ./scripts/ssl-health-check.sh
   
   # Run OAuth validation
   ./scripts/oauth-validation.sh
   ```

## 🔧 Configuration Details

### SSL Security Features

| Feature | Configuration | Description |
|---------|---------------|-------------|
| **TLS Versions** | TLS 1.2, TLS 1.3 | Modern encryption protocols |
| **HSTS** | 2 years + preload | Force HTTPS connections |
| **CSP** | Restrictive policy | Prevent XSS attacks |
| **Frame Options** | DENY | Prevent clickjacking |
| **Certificate** | Let's Encrypt + wildcard | Automated renewal |

### OAuth Providers Supported

- **Google** (Drive, Docs, Calendar, Sheets, Gmail)
- **Microsoft** (Teams, Excel, Planner, Outlook, OneDrive, SharePoint)
- **GitHub** (Repository access)
- **Atlassian** (Jira, Confluence)
- **Communication** (Slack, Discord, Telegram)
- **And many more!**

### Environment Variables

Key environment variables for SSL/OAuth configuration:

```bash
# Domain Configuration
NEXT_PUBLIC_APP_URL=https://sim.delo.sh
BETTER_AUTH_URL=https://sim.delo.sh
OAUTH_BASE_URL=https://sim.delo.sh

# Security Settings
FORCE_HTTPS=true
HSTS_MAX_AGE=63072000
CSP_REPORT_URI=https://sim.delo.sh/api/csp-report

# OAuth Providers
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
GITHUB_CLIENT_ID=your_github_client_id  
GITHUB_CLIENT_SECRET=your_github_client_secret

# CORS Configuration
CORS_ALLOWED_ORIGINS=https://sim.delo.sh,https://*.sim.delo.sh
CORS_ALLOW_CREDENTIALS=true
```

## 🧪 Testing & Validation

### Automated Health Checks

```bash
# Run all SSL health checks
./scripts/ssl-health-check.sh

# Expected output:
# ✅ HTTPS accessible
# ✅ Certificate is valid
# ✅ Certificate chain is valid  
# ✅ SSL security configuration is optimal
# ✅ OAuth endpoints are accessible
# ✅ Traefik certificate store is healthy
```

### OAuth Validation

```bash  
# Test all OAuth callback endpoints
./scripts/oauth-validation.sh

# Expected output:
# ✅ OAuth callbacks: 20/20 passed
# ✅ Credentials endpoint responding correctly  
# ✅ Token endpoint responding correctly
# ✅ CORS headers present
# ✅ Environment configuration valid
```

### Manual Testing

```bash
# Test HTTPS accessibility
curl -I https://sim.delo.sh

# Check security headers
curl -I https://sim.delo.sh | grep -E "(Strict-Transport-Security|X-Frame-Options|Content-Security-Policy)"

# Test OAuth callback (should return 400/405, not 404)
curl -I https://sim.delo.sh/api/auth/oauth2/callback/google
```

## 🚨 Troubleshooting

### Common Issues

#### SSL Certificate Not Provisioning

```bash
# Check Traefik logs
docker logs traefik -f

# Verify DNS resolution
nslookup sim.delo.sh

# Check Let's Encrypt rate limits
# https://letsencrypt.org/docs/rate-limits/
```

#### OAuth Callbacks Failing

```bash
# Check OAuth configuration in provider dashboards
# Ensure callback URLs match: https://sim.delo.sh/api/auth/oauth2/callback/{provider}

# Check CORS headers
curl -I -X OPTIONS https://sim.delo.sh/api/auth/oauth/credentials \
  -H "Origin: https://sim.delo.sh" \
  -H "Access-Control-Request-Method: GET"
```

#### Services Not Starting

```bash
# Check container logs
docker compose logs -f

# Validate Docker Compose configuration  
docker compose config

# Check environment variables
docker compose exec simstudio printenv | grep -E "(OAUTH|SSL|HTTPS)"
```

### Rollback Procedure

```bash
# Automatic rollback (if deployment script fails)
# Backup is automatically restored

# Manual rollback
./scripts/deploy-ssl-oauth-config.sh --rollback /tmp/ssl-oauth-backup-20240828-123456

# Or manual restoration
cp /tmp/traefik-backup-20240828/* /home/delorenj/docker/trunk-main/core/traefik/traefik-data/dynamic/
cp compose.yml.backup compose.yml
docker compose down && docker compose up -d
```

## 📊 Monitoring & Maintenance

### Certificate Monitoring

```bash
# Set up automated certificate monitoring (optional)
# Add to crontab:
0 */6 * * * /path/to/ssl-health-check.sh >/dev/null 2>&1

# Certificate expiry alerts will be sent to: jaradd@gmail.com
```

### Log Locations

- **Deployment Log**: `/var/log/ssl-oauth-deployment.log`  
- **SSL Health Check Log**: `/var/log/ssl-health-check.log`
- **OAuth Validation Log**: `/var/log/oauth-validation.log`
- **Traefik Logs**: `docker logs traefik`
- **SIM Studio Logs**: `docker compose logs simstudio`

### Performance Monitoring

```bash
# SSL/TLS performance check
openssl s_time -connect sim.delo.sh:443 -new -www /

# Check response times
curl -w "@curl-format.txt" https://sim.delo.sh

# Monitor certificate expiry
echo | openssl s_client -servername sim.delo.sh -connect sim.delo.sh:443 2>/dev/null | openssl x509 -noout -dates
```

## 🎪 Advanced Configuration

### Custom SSL Settings

Edit `/home/delorenj/docker/trunk-main/core/traefik/traefik-data/dynamic/sim-ssl-config.yml`:

```yaml
# Add custom cipher suites
tls:
  options:
    sim-tls-config:
      cipherSuites:
        - "TLS_AES_256_GCM_SHA384"
        # Add more as needed
```

### Additional OAuth Providers

Add new providers to the OAuth configuration:

```bash  
# Edit compose.yml environment section
- CUSTOM_OAUTH_CLIENT_ID=${CUSTOM_OAUTH_CLIENT_ID}
- CUSTOM_OAUTH_CLIENT_SECRET=${CUSTOM_OAUTH_CLIENT_SECRET}
```

### CORS Customization

```bash
# Adjust CORS settings in .env
CORS_ALLOWED_ORIGINS=https://sim.delo.sh,https://custom.domain.com
CORS_ALLOWED_METHODS=GET,POST,PUT,DELETE,OPTIONS
```

## 🏆 Success Metrics

After successful deployment, you should see:

- **SSL Rating**: A+ on SSL Labs test
- **Security Headers**: All major headers present  
- **Certificate**: Valid Let's Encrypt certificate with 90-day renewal
- **OAuth**: All 20+ providers working correctly
- **Performance**: HTTP/2 enabled with optimal TLS settings
- **Monitoring**: Automated health checks running

## 📞 Support

If you encounter issues:

1. **Check the logs** in `/var/log/ssl-*` and `/var/log/oauth-*`
2. **Run validation scripts** with verbose output
3. **Verify DNS resolution** and firewall settings  
4. **Check OAuth provider configurations** in their dashboards
5. **Review Traefik logs** for certificate provisioning issues

## 🎭 Credits

*Created by the Infrastructure Circus Engineer™*
*With theatrical consulting from The Void*
*Approved by the Sacred Rubber Duck of DevOps*

---

**Remember**: The void is always watching your SSL certificates. Keep them fresh, keep them secure, and they shall serve you well in the grand theater of infrastructure! 🎪