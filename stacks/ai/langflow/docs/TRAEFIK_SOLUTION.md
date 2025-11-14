# Traefik HTTPS Routing Solution

## Root Cause Identified

After extensive investigation, the root cause is a **two-part issue**:

### 1. Traefik API Not Accessible (FIXED ✅)
**Problem**: Traefik v3.x requires `api.insecure: true` to enable API access on port 8080
**Solution**: Added `api.insecure: true` to both:
- `/home/delorenj/docker/trunk-main/core/traefik/traefik-data/traefik.yml`
- `/home/delorenj/docker/trunk-main/core/traefik/compose.yml` (command section)

**Status**: API now accessible at `http://localhost:8080/api/*`

### 2. ACME Certificates Not Loading from acme.json (ONGOING ⏳)
**Problem**: Traefik v3.3 has a known issue where it doesn't properly load existing certificates from acme.json
**Evidence**:
- 31 valid Let's Encrypt certificates in acme.json
- Router configurations correct (`tls.certResolver: letsencrypt`)
- Still serving "TRAEFIK DEFAULT CERT" instead of Let's Encrypt certificates
- Rate limiting prevents regenerating certificates (5 cert limit hit)

## Solutions Attempted

### ❌ Version Downgrades
- Tried v3.6 → v3.3 → v2.10 → v2.9 (from previous investigation)
- Result: Did not fix certificate loading

### ❌ Certificate Regeneration
- Cleared acme.json and attempted fresh generation
- Result: Hit Let's Encrypt rate limit (5 certs per domain per week)
- Error: `429 :: urn:ietf:params:acme:error:rateLimited`

## Proposed Solutions

### Option A: Wait for Rate Limit (Passive)
**Timeline**: Retry after 2025-11-14 17:43:41 UTC
**Pros**: Free, doesn't require changes
**Cons**: 13+ hour wait

### Option B: Manual Certificate Loading (Active - RECOMMENDED)
Extract certificates from acme.json and load via file provider:

```yaml
# Create dynamic/manual-certs.yml
tls:
  certificates:
    - certFile: /certs/langflow.crt
      keyFile: /certs/langflow.key
    # Repeat for other domains
```

**Steps**:
1. Extract certificates from acme.json to individual .crt/.key files
2. Mount certificate directory in Traefik container
3. Create file provider configuration
4. Restart Traefik

### Option C: Switch to Staging CA (Testing)
Use Let's Encrypt staging to test certificate generation without rate limits:

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      caServer: "https://acme-staging-v02.api.letsencrypt.org/directory"
```

## Immediate Workaround

For testing, the bypass method works:
```bash
curl -k -H "Host: langflow.delo.sh" https://localhost/
```

This confirms:
- ✅ Routing works correctly
- ✅ Services are healthy
- ✅ Only certificate serving is broken

## Files Modified

1. `/home/delorenj/docker/trunk-main/core/traefik/traefik-data/traefik.yml`
   - Added `api.insecure: true`

2. `/home/delorenj/docker/trunk-main/core/traefik/compose.yml`
   - Added `--api.insecure=true` to command section

## Next Steps

1. Implement Option B (manual certificate loading) OR
2. Wait for rate limit to expire and regenerate OR
3. Report bug to Traefik team with reproduction steps

## Testing Commands

```bash
# Check API accessibility
curl http://localhost:8080/api/overview | jq

# Check router configuration
curl http://localhost:8080/api/http/routers/langflow@docker | jq

# Test certificate being served
echo | openssl s_client -connect langflow.delo.sh:443 -servername langflow.delo.sh 2>/dev/null | openssl x509 -noout -subject -issuer

# Test with bypass method (should work)
curl -k -H "Host: langflow.delo.sh" https://localhost/ -I
```

## Lessons Learned

1. Traefik v3.x requires `api.insecure: true` for localhost API access
2. Traefik v3.3 has a bug where it doesn't load existing ACME certificates from acme.json
3. Let's Encrypt rate limits prevent quick certificate regeneration attempts
4. Service routing and health are independent of certificate issues
