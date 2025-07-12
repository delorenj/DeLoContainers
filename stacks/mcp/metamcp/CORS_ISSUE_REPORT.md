# MetaMCP CORS Issue Report

## Executive Summary
MetaMCP enforces a strict CORS policy that prevents access from any URL other than localhost, even when `APP_URL` is correctly configured. This makes the application inaccessible from remote domains.

## Problem Description
- **Symptom**: When accessing MetaMCP from a configured domain (e.g., `https://mcp.delo.sh`), users are redirected to `/cors-error` page
- **Impact**: Application is only accessible via localhost, preventing remote access
- **Severity**: High - blocks production deployment

## Root Cause Analysis

### Technical Details
The CORS enforcement is hardcoded in the backend authentication layer at `apps/backend/src/auth.ts`:

```javascript
trustedOrigins: [
    "http://localhost",
    "http://localhost:3000",
    "http://localhost:12008",
    "http://127.0.0.1",
    "http://127.0.0.1:12008",
    "http://127.0.0.1:3000",
    "http://0.0.0.0",
    "http://0.0.0.0:3000",
    "http://0.0.0.0:12008",
]
```

### Why Current Implementation Fails
1. The `trustedOrigins` array is hardcoded with only localhost addresses
2. The `APP_URL` environment variable is not added to trusted origins
3. No mechanism exists to configure additional trusted origins via environment variables
4. The better-auth library rejects all requests from non-trusted origins

## Attempted Workarounds

### 1. Traefik Configuration (Failed)
- **Approach**: Added CORS headers and middlewares in Traefik
- **Result**: Ineffective - CORS check happens at application level, not proxy level
- **Files**: `/core/traefik/traefik-data/dynamic/metamcp.yml`

### 2. JavaScript Patching (Temporary)
- **Approach**: Created `fix-cors.sh` to patch compiled JavaScript files
- **Result**: Temporarily bypasses redirects but doesn't fix authentication
- **Command**: `./fix-cors.sh`

### 3. Environment Variables (Failed)
- **Approach**: Modified `APP_URL` and `NEXT_PUBLIC_APP_URL`
- **Result**: Ineffective due to hardcoded trusted origins
- **Files**: `.env`, `compose.yml`

## Proposed Solution

### Short-term Fix
Modify `apps/backend/src/auth.ts` to support dynamic trusted origins:

```javascript
// Add at the top of the file
const defaultLocalOrigins = [
    "http://localhost",
    "http://localhost:3000",
    "http://localhost:12008",
    "http://127.0.0.1",
    "http://127.0.0.1:12008",
    "http://127.0.0.1:3000",
    "http://0.0.0.0",
    "http://0.0.0.0:3000",
    "http://0.0.0.0:12008",
];

// In the auth configuration
trustedOrigins: [
    ...defaultLocalOrigins,
    ...(process.env.TRUSTED_ORIGINS ? process.env.TRUSTED_ORIGINS.split(',') : []),
    process.env.APP_URL
].filter(Boolean),
```

### Long-term Fix
Submit a pull request to the MetaMCP repository to make CORS configuration more flexible.

## Implementation Steps

### For Immediate Use
1. Fork the repository: https://github.com/metatool-ai/metamcp
2. Modify `apps/backend/src/auth.ts` as shown above
3. Build custom Docker image:
   ```bash
   cd metamcp
   docker build -t metamcp-custom:latest .
   ```
4. Update `compose.yml` to use custom image
5. Add `TRUSTED_ORIGINS` to `.env`:
   ```
   TRUSTED_ORIGINS=https://mcp.delo.sh,https://metamcp.delo.sh
   ```

### For Community Benefit
1. Create issue on MetaMCP GitHub repository
2. Submit pull request with configurable CORS origins
3. Suggest adding documentation about CORS configuration

## Current Workaround
Use SSH tunnel for remote access:
```bash
# On your local machine
ssh -L 12008:localhost:12008 your-server-address

# Access in browser
http://localhost:12008
```

## Files Created During Troubleshooting
- `fix-cors.sh` - JavaScript patching script (temporary)
- `cors-bypass.js` - Proxy attempt (incomplete)
- `bypass-cors.sh` - Alternative patch (unused)
- `CORS_ISSUE_REPORT.md` - This documentation

## References
- MetaMCP Repository: https://github.com/metatool-ai/metamcp
- Better-Auth Documentation: https://better-auth.com
- Issue Discussion: Not yet created

## Contact
For questions about this issue, refer to the MetaMCP GitHub issues or create a new issue describing this CORS limitation.

---
*Document created: 2025-01-11*
*Issue discovered while deploying MetaMCP in production environment*