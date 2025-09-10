# Server Lockup Investigation and Resolution

## Executive Summary

This document details the investigation into a server lockup incident that occurred on June 5, 2025. The primary cause was identified as Docker networking issues, specifically DNS resolution timeouts, compounded by high CPU usage from the Amazon Q process. The issues have been resolved by implementing proper DNS configuration for Docker and installing monitoring tools for early detection of similar problems.

## Incident Details

**Date:** June 5, 2025  
**Symptoms:** Complete server lockup during a terminal session  
**Impact:** System became unresponsive, requiring a reboot

## Root Cause Analysis

### Primary Issues Identified

1. **Docker DNS Resolution Failures**
   - Multiple errors in Docker logs showing DNS resolution timeouts
   - Failed queries to external DNS servers
   - Error messages: `failed to query external DNS server` with `i/o timeout` errors

2. **High CPU Usage**
   - Amazon Q chat process consuming excessive CPU resources (335-437%)
   - Multiple instances of the process running simultaneously

3. **Docker Network Configuration Issues**
   - Multiple Docker errors related to container networking
   - Failed container host entry deletions
   - Atomic operation failures with endpoints

### Contributing Factors

- Missing Docker DNS configuration
- No resource monitoring tools installed
- No resource limits on high-CPU processes

## Resolution Steps Implemented

### 1. Docker DNS Configuration

Created and configured `/etc/docker/daemon.json` with Google DNS servers:

```json
{
  "dns": ["8.8.8.8", "8.8.4.4"]
}
```

This resolved the DNS timeout issues by providing reliable DNS servers for Docker to use instead of relying on the system resolver.

### 2. Monitoring Tools Installation

Installed essential monitoring tools:

- **htop**: For real-time CPU and memory monitoring
- **iotop**: For I/O usage monitoring
- **smartmontools**: For disk health checking

### 3. System Updates

Verified system packages were up to date:

```bash
sudo apt update && sudo apt upgrade -y
```

### 4. Disk Health Verification

Checked disk health using smartmontools:

```bash
sudo smartctl -a /dev/nvme0n1
```

Results showed the disk is healthy with no issues:
- SMART overall health: PASSED
- SSD usage: 0% of lifespan
- No media errors detected

## System Status After Fixes

- Docker service running properly with new DNS configuration
- All containers restarted successfully
- Memory usage normal (5.27GB out of 121GB)
- No swap usage
- Disk health verified good

## Recommendations for Preventing Future Incidents

### Immediate Actions

1. **Regular Monitoring**
   - Run `htop` periodically to check CPU and memory usage
   - Use `iotop` to monitor disk I/O activity
   - Check `smartctl -a /dev/nvme0n1` monthly for disk health

2. **Docker Configuration Management**
   - Maintain proper DNS configuration in Docker
   - Consider implementing Docker resource limits

### Long-term Recommendations

1. **Resource Limits**
   - Consider implementing CPU limits for resource-intensive processes like Amazon Q
   - Use Docker resource constraints for containerized applications

2. **Automated Monitoring**
   - Set up automated monitoring with alerts for:
     - High CPU usage (>80% sustained)
     - DNS resolution failures
     - Disk I/O bottlenecks

3. **Regular Maintenance**
   - Schedule regular system updates
   - Perform periodic Docker pruning to clean unused resources:
     ```bash
     docker system prune -a
     ```

## Conclusion

The server lockup was primarily caused by Docker DNS resolution failures combined with high CPU usage. The implemented fixes have addressed these issues by providing proper DNS configuration and installing monitoring tools. Regular monitoring and maintenance should prevent similar incidents in the future.

## References

- Docker DNS Configuration: https://docs.docker.com/config/daemon/systemd/#custom-docker-daemon-options
- System Monitoring Best Practices: https://www.digitalocean.com/community/tutorials/how-to-monitor-system-resources-on-ubuntu
- Docker Resource Constraints: https://docs.docker.com/config/containers/resource_constraints/
