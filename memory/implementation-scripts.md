# qBittorrent Infrastructure Fix - Implementation Scripts Documentation

## Overview

This document provides comprehensive documentation for the qBittorrent infrastructure fix implementation scripts. The scripts are designed to address critical issues with file permissions, stale torrent data, web authentication, and DNS resolution.

## Script Architecture

### Directory Structure
```
/home/delorenj/docker/trunk-main/scripts/
├── phase1-permission-fix.sh      # Critical permission fix (PUID 502→911)
├── phase2-stale-cleanup.sh       # Remove problematic torrent files
├── phase3-web-auth-reset.sh      # Reset to admin/adminpass credentials
├── phase4-dns-improvement.sh     # Add reliable DNS servers to gluetun
├── master-script.sh              # Orchestrates all phases with error handling
├── rollback-phase1.sh            # Rollback permission changes
├── rollback-phase2.sh            # Restore torrent backup data
├── rollback-phase3.sh            # Restore original auth configuration
├── rollback-phase4.sh            # Remove DNS_SERVERS configuration
└── rollback-all.sh               # Complete system rollback
```

## Phase-by-Phase Implementation

### Phase 1: Critical Permission Fix
**File**: `phase1-permission-fix.sh`
**Purpose**: Fix PUID mismatch between container (502) and NFS permissions (911)
**Downtime**: ~2 minutes

**Key Operations**:
- Updates PUID from 502 to 911 in environment files or compose.yml
- Restarts qBittorrent container with new permissions
- Verifies no permission denied errors remain
- Creates automatic backups of configuration files

**Safety Features**:
- Comprehensive backup of environment files before changes
- Verification of container status before and after changes
- Error detection and logging for permission issues
- Automatic rollback capability through backup restoration

### Phase 2: Stale Torrent Cleanup
**File**: `phase2-stale-cleanup.sh`
**Purpose**: Remove problematic torrents causing file size mismatch errors
**Downtime**: ~5 minutes

**Key Operations**:
- Creates full backup of BT_backup directory with timestamp
- Removes specific problematic torrent hashes identified in logs:
  - `2e727b5af8a3e4f52f8453eecf1702f0dd2164e9` (reFX Nexus)
  - `4238ac2ab9c2de7e3c6bf216bfeea60713f2094c` (Applied Acoustics)
  - `690ca26d623ae367f0f2c1a867407dcc7c15f8fb` (FabFilter Bundle)
- Automatically detects and removes zero-byte fastresume files (corruption indicators)
- Provides detailed logging of removed files and counts

**Safety Features**:
- Complete backup of torrent data before any changes
- Backup path tracking for rollback procedures
- Graceful handling of missing files or directories
- Verification of successful cleanup through log analysis

### Phase 3: Web Authentication Reset
**File**: `phase3-web-auth-reset.sh`
**Purpose**: Reset qBittorrent web interface to default admin/adminpass credentials
**Downtime**: ~1 minute

**Key Operations**:
- Backs up existing qBittorrent.conf configuration
- Applies default PBKDF2 password hash for "adminpass"
- Sets username to "admin"
- Ensures WebUI is enabled in configuration
- Tests web interface authentication post-restart

**Safety Features**:
- Configuration file backup with timestamp
- Ownership correction for configuration files
- Authentication testing with retry logic
- Detailed logging of configuration changes

### Phase 4: DNS Improvement
**File**: `phase4-dns-improvement.sh`
**Purpose**: Add reliable DNS servers to gluetun VPN container
**Downtime**: ~1 minute (no qBittorrent downtime)

**Key Operations**:
- Adds DNS_SERVERS environment variable to gluetun service
- Uses reliable DNS servers: 1.1.1.1, 8.8.8.8, 1.0.0.1
- Restarts only gluetun container (preserves qBittorrent uptime)
- Tests DNS resolution for common tracker domains

**Safety Features**:
- Compose file backup before modifications
- Detection of existing DNS configuration
- DNS resolution testing with multiple domains
- VPN connection status verification

## Master Orchestration Script

### Master Script Features
**File**: `master-script.sh`
**Purpose**: Orchestrate all phases with comprehensive error handling

**Command Line Options**:
```bash
# Run all phases
./master-script.sh

# Skip specific phases
./master-script.sh --skip-phase2 --skip-phase4

# Disable automatic rollback
./master-script.sh --no-auto-rollback

# Skip verification after each phase
./master-script.sh --no-verify
```

**Key Features**:
- **Pre-flight Checks**: Validates environment, scripts, and Docker access
- **Phase Orchestration**: Executes phases in sequence with proper error handling
- **Automatic Rollback**: Triggers complete rollback on any phase failure
- **Progress Tracking**: Maintains phase status throughout execution
- **Comprehensive Verification**: Tests system state after each phase
- **Detailed Reporting**: Generates complete execution summary

**Error Handling**:
- Immediate rollback on critical failures (configurable)
- Detailed error logging with timestamps
- Phase status tracking for partial recovery scenarios
- Safe execution environment with `set -euo pipefail`

## Rollback System

### Individual Phase Rollbacks
Each phase has a dedicated rollback script that safely reverts changes:

- **Rollback Phase 1**: Restores original PUID settings from backups
- **Rollback Phase 2**: Restores complete torrent data from backup directory
- **Rollback Phase 3**: Restores original authentication configuration
- **Rollback Phase 4**: Removes DNS_SERVERS configuration from compose file

### Complete System Rollback
**File**: `rollback-all.sh`
**Purpose**: Execute all rollbacks in reverse order (4→3→2→1)

**Features**:
- Reverse-order execution to minimize conflicts
- Individual phase rollback tracking
- Continue-on-error option for partial rollbacks
- Final system state verification
- Comprehensive rollback reporting

## Verification and Testing

### Built-in Verification Steps
Each script includes specific verification procedures:

1. **Phase 1 Verification**:
   - Container status check
   - Permission error log scanning
   - PUID configuration verification

2. **Phase 2 Verification**:
   - File size mismatch error detection
   - Torrent count validation
   - Startup error analysis

3. **Phase 3 Verification**:
   - Web interface authentication testing
   - Configuration setting validation
   - API endpoint accessibility

4. **Phase 4 Verification**:
   - DNS resolution testing for multiple domains
   - VPN connection status verification
   - Gluetun container health check

### Manual Verification Commands
```bash
# Test file permissions
docker logs qbittorrent --tail 20 | grep -i "permission denied"

# Test web interface
curl -d "username=admin&password=adminpass" "http://localhost:8091/api/v2/auth/login"

# Test torrent API
curl -b /tmp/qb_cookies "http://localhost:8091/api/v2/torrents/info"

# Test DNS resolution
docker exec gluetun nslookup tracker.opentrackr.org
```

## Safety and Security Considerations

### Data Protection
- **Complete Backups**: All configuration and data files backed up before changes
- **Atomic Operations**: Changes applied atomically where possible
- **Rollback Capability**: Every change can be safely reverted
- **Timestamped Backups**: Multiple backup versions preserved

### Security Best Practices
- **Credential Management**: Default credentials documented and testable
- **Permission Handling**: Proper file ownership and permissions maintained
- **Container Security**: No unnecessary privilege escalation
- **Log Security**: Sensitive information excluded from logs

### Error Recovery
- **Graceful Degradation**: Scripts continue safely when non-critical operations fail
- **Error Logging**: Comprehensive error information for troubleshooting
- **Status Tracking**: Clear phase completion status for partial recovery
- **Manual Intervention Points**: Clear instructions for manual recovery steps

## Execution Guidelines

### Pre-Execution Checklist
1. ✅ Verify Docker and docker-compose are running
2. ✅ Ensure sufficient disk space for backups
3. ✅ Review current container status
4. ✅ Confirm network connectivity to required services
5. ✅ Verify script permissions and executability

### Recommended Execution Sequence
```bash
# 1. Run master script with full verification
./scripts/master-script.sh

# 2. Monitor execution logs
tail -f /tmp/qbittorrent-master-*.log

# 3. If issues occur, manual rollback available
./scripts/rollback-all.sh

# 4. Individual phase rollback if needed
./scripts/rollback-phase2.sh  # Example for phase 2 only
```

### Post-Execution Monitoring
- Monitor qBittorrent logs for 10-15 minutes
- Test downloading a new torrent file
- Verify web interface accessibility at https://get.delo.sh
- Check VPN connection status periodically
- Confirm no permission or file size mismatch errors

## Troubleshooting Guide

### Common Issues and Solutions

1. **Permission Denied Errors Persist**:
   - Verify NFS mount permissions (should be 911:911 or 1024:1024)
   - Check container user mapping in compose.yml
   - Ensure PGID is also set correctly (typically 20 or 1024)

2. **Web Interface Still Inaccessible**:
   - Verify Traefik configuration for get.delo.sh routing
   - Check if qBittorrent WebUI port (8091) is accessible locally
   - Confirm authentication credentials: admin/adminpass

3. **Torrent Files Still Showing Errors**:
   - Review qBittorrent logs for additional problematic hashes
   - Consider clearing entire BT_backup directory (nuclear option)
   - Verify file system integrity on NFS mount

4. **DNS Resolution Issues**:
   - Test DNS servers individually within gluetun container
   - Verify VPN provider doesn't block custom DNS
   - Check gluetun logs for DNS-related errors

### Emergency Recovery
If all automated recovery fails:
```bash
# Nuclear option - complete reset
docker compose down
rm -rf qbittorrent/BT_backup
rm -f qbittorrent/qBittorrent.conf
docker compose up -d
```

## Logging and Monitoring

### Log File Locations
- Master script: `/tmp/qbittorrent-master-YYYYMMDD-HHMMSS.log`
- Individual phases: `/tmp/qbittorrent-phase[1-4]-YYYYMMDD-HHMMSS.log`
- Rollback scripts: `/tmp/qbittorrent-rollback[1-4]-YYYYMMDD-HHMMSS.log`

### Log Analysis
Scripts generate structured logs with timestamps and severity levels:
- `INFO`: Normal operational messages
- `WARNING`: Non-critical issues that should be noted
- `ERROR`: Critical issues requiring attention
- `SUCCESS`: Successful completion indicators

## Performance Metrics

### Expected Execution Times
- **Phase 1**: 1-2 minutes (container restart time dependent)
- **Phase 2**: 3-5 minutes (depends on backup size and torrent count)
- **Phase 3**: 30-60 seconds (minimal container restart)
- **Phase 4**: 30-60 seconds (gluetun restart only)
- **Total**: 6-9 minutes for complete execution

### Success Criteria
- ✅ No permission denied errors in qBittorrent logs
- ✅ Web interface accessible with admin/adminpass
- ✅ No file size mismatch errors on startup
- ✅ DNS resolution working for tracker domains
- ✅ VPN connection maintained throughout process
- ✅ Active torrents resume downloading/uploading

---

**Implementation Status**: ✅ Complete
**Last Updated**: 2025-08-05
**Scripts Version**: 1.0.0
**Tested Environment**: Docker Compose with qBittorrent 4.x + Gluetun VPN