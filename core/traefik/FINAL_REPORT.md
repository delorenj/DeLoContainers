# Traefik HTTPS Routing Investigation Report

## Executive Summary

After extensive investigation involving multiple Traefik version downgrades (3.6 → 3.3 → 2.10 → 2.9), the root cause was identified as a **certificate loading/SNI matching issue** rather than a version compatibility problem. All services are healthy and routing works correctly when SNI is bypassed, but fail when accessed via standard HTTPS due to Traefik serving default self-signed certificates instead of Let's Encrypt certificates.

## Initial Symptoms

- **Primary Issue**: All HTTPS requests to services return `404 Not Found`
- **Affected Services**: Both Docker provider services (AdGuard, etc.) and file provider services (n8n - native installation)
- **HTTP Behavior**: HTTP requests work correctly (proper 301 redirects to HTTPS)
- **Service Health**: Backend services are healthy and responding correctly
- **Certificate Status**: Self-signed "TRAEFIK DEFAULT CERT" served instead of Let's Encrypt certificates

## Investigation Process

### Phase 1: Version Rollback Attempts
**Hypothesis**: Traefik version compatibility issue
**Actions Taken**:
- Downgraded from v3.6 → v3.3 → v2.10 → v2.9
- Each rollback failed to resolve the issue
**Outcome**: ❌ Version rollbacks did not fix the problem

### Phase 2: Provider Analysis
**Hypothesis**: Docker provider overriding file provider configurations
**Findings**:
- Both providers loading correctly
- File provider services (n8n) visible in Traefik API
- Docker provider services also visible and configured
- No provider conflict identified
**Outcome**: ❌ Provider configuration was correct

### Phase 3: Service Health Verification
**Tests Performed**:
```bash
# Direct service test - SUCCESS
curl -H "Host: n8n.delo.sh" http://192.168.1.12:5678/healthz
# Response: {"status":"ok"}

# Traefik bypass method - SUCCESS  
curl -k -H "Host: n8n.delo.sh" https://localhost/healthz
# Response: {"status":"ok"}

# Direct HTTPS - FAILURE
curl https://n8n.delo.sh/healthz
# Response: 404 Not Found with self-signed certificate
```
**Outcome**: ✅ Services are healthy, routing works when SNI is bypassed

### Phase 4: Certificate Analysis
**ACME File Investigation**:
- 18-23 valid Let's Encrypt certificates present in acme.json
- n8n certificate confirmed valid: `CN=n8n.delo.sh`, issued by Let's Encrypt R13
- Certificate dates: `notBefore=Nov 13 15:25:39 2025 GMT`, `notAfter=Feb 11 15:25:38 2026 GMT`
- JSON structure valid and readable

**Certificate Loading Analysis**:
```
time="2025-11-13T16:15:25Z" level=debug msg="No default certificate, fallback to the internal generated certificate" tlsStoreName=default
```
**Outcome**: ❌ Certificates exist but are not loaded into TLS store

### Phase 5: Manual Certificate Loading Attempts
**Actions Taken**:
- Extracted certificates from ACME file to separate .crt/.key files
- Created manual certificate configuration in `manual-certs.yml`
- Added certificate directory mount to Docker container
- Attempted to override TLS store configuration

**Results**:
```
time="2025-11-13T16:28:39Z" level=warning msg="TLS store default already configured, skipping" providerName=file filename=tls-store.yml
time="2025-11-13T16:28:39Z" level=debug msg="Skipping addition of certificate for domain(s) \"n8n.delo.sh\", to TLS Store default, as it already exists for this store."
```
**Outcome**: ❌ Certificate loading conflicts prevented manual certificate installation

## Key Technical Findings

### 1. SNI vs Non-SNI Behavior
| Method | SNI Used | Result | Certificate Served |
|--------|----------|--------|-------------------|
| `https://n8n.delo.sh` | ✅ Yes | ❌ 404 | Default self-signed |
| `https://localhost` + Host header | ❌ No | ✅ 200 OK | Default self-signed (but routing works) |

### 2. Certificate Status
- **ACME File**: ✅ Valid, 18+ Let's Encrypt certificates
- **Certificate Content**: ✅ Valid Let's Encrypt certificate for n8n.delo.sh
- **TLS Store Loading**: ❌ Certificates not loaded into Traefik TLS store
- **SNI Matching**: ❌ Default certificate served for all SNI requests

### 3. Service Discovery
- **File Provider**: ✅ n8n and other native services discovered
- **Docker Provider**: ✅ Container services discovered
- **API Visibility**: ✅ All services visible in Traefik API
- **Health Checks**: ✅ All services passing health checks

### 4. Routing Logic
- **HTTP Routing**: ✅ Works correctly (301 redirects)
- **HTTPS Routing (no SNI)**: ✅ Works correctly
- **HTTPS Routing (with SNI)**: ❌ Fails due to certificate mismatch

## Root Cause Analysis

The issue is **not** related to:
- ❌ Traefik version compatibility
- ❌ Provider configuration conflicts
- ❌ Service health or availability
- ❌ Router rule configuration
- ❌ Certificate validity or expiration

The issue **is** related to:
- ✅ **Certificate loading mechanism failure**: Traefik cannot load Let's Encrypt certificates from ACME file into TLS store
- ✅ **SNI matching failure**: Without proper certificates, SNI requests get default certificate and routing fails
- ✅ **TLS store configuration conflicts**: Multiple TLS store configurations preventing proper certificate loading

## Conclusion

The root cause is a **certificate loading and SNI matching failure** in Traefik's TLS subsystem. The ACME certificates exist and are valid, but Traefik cannot properly load them into the TLS store, causing all HTTPS requests with SNI to receive the default self-signed certificate and subsequently fail routing.

## Recommended Solutions

### Immediate Workaround
- Services can be accessed using the bypass method for testing/debugging
- HTTP access works correctly for non-sensitive operations

### Long-term Fixes (in order of preference)
1. **ACME File Regeneration**: Delete existing acme.json and allow Traefik to generate fresh certificates
2. **TLS Configuration Cleanup**: Remove conflicting TLS store configurations and simplify certificate management
3. **Certificate Resolver Debugging**: Enable more detailed ACME logging to identify specific loading failures
4. **Alternative Certificate Management**: Consider using external certificate management tools if Traefik's built-in ACME continues to fail

## Lessons Learned

1. **Avoid Version Rollback Trap**: Multiple version changes without addressing root cause led to circular reasoning
2. **Focus on Symptoms vs Assumptions**: The bypass method working was the key clue that routing itself was functional
3. **Certificate Loading ≠ Certificate Existence**: Valid certificates in storage don't guarantee proper loading into TLS store
4. **SNI is Critical**: Modern HTTPS relies heavily on SNI for certificate selection and routing

The investigation revealed that the fundamental Traefik functionality (routing, service discovery, health checks) is working correctly, but the certificate loading subsystem has a critical failure preventing proper HTTPS operation.
