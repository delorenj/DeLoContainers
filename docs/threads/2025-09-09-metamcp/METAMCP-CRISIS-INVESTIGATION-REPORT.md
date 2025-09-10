# MetaMCP Container Process Explosion Crisis Investigation Report

## Executive Summary

**CRITICAL ISSUE IDENTIFIED**: MetaMCP container experiencing exponential process growth from 226→346→387→406→426→536+ processes, with BusyBox environment limiting our emergency response capabilities.

**IMMEDIATE STATUS**:
- Current Process Count: **536+ processes** (Target: ≤15)
- Growth Pattern: **Exponential** (120+ new processes since last check)
- Container Status: Running but critical resource pressure
- Emergency Scripts: **FAILING** due to BusyBox limitations

## Root Cause Analysis

### 1. Process Explosion Pattern

**Evidence from Container Analysis**:
```bash
# Process Count Progression
Initial: 226 processes
+2 hours: 346 processes (+120, +53% growth)
+1 hour: 387 processes (+41, +12% growth)
+1 hour: 406 processes (+19, +5% growth)
+30 min: 426 processes (+20, +5% growth)
Current: 536+ processes (+110+, +26% growth)
```

**Key Findings**:
- **229 npm exec processes** out of 536 total (43% of all processes)
- Each MCP server spawning multiple instances instead of singleton
- No process deduplication or cleanup mechanism working
- Container resource limits not preventing process spawning

### 2. BusyBox Environment Limitations

**Critical Command Limitations**:
```bash
# FAILING: BusyBox uniq doesn't support --all-repeated=separate
uniq: unrecognized option: all-repeated=separate

# Available BusyBox uniq options:
-c    Prefix lines by the number of occurrences
-d    Only print duplicate lines
-u    Only print unique lines
-i    Ignore case
-z    NUL terminated output
-f N  Skip first N fields
-s N  Skip first N chars
-w N  Compare N characters in line
```

**Tool Availability**:
- ✅ Basic `ps`, `awk`, `grep`, `kill` available
- ❌ Advanced `uniq` options not available
- ❌ `pgrep`, `pkill` not available
- ❌ Process management tools limited

### 3. Docker Resource Limits Analysis

**Current Configuration** (from docker-compose.yml):
```yaml
mem_limit: 4g
mem_reservation: 1g
cpus: 2.0
pids_limit: 25          # ← NOT BEING ENFORCED
```

**CRITICAL FINDING**: `pids_limit: 25` is being ignored or not enforced properly.

**Actual Resource Usage**:
- Container shows as "healthy" despite 536+ processes
- No memory pressure alerts triggering
- Process count massively exceeding PID limit

## Process Spawning Analysis

### MCP Server Duplication Pattern

**Evidence from Process List**:
```bash
# Multiple instances of same MCP servers:
npm exec @21st-dev/magic@latest        # Multiple instances
npm exec ruv-swarm mcp start           # Multiple instances
npm exec claude-flow@alpha mcp start   # Multiple instances
npm exec kapture-mcp@latest bridge     # Multiple instances
npm exec figma-mcp                     # Multiple instances
[... 229 npm exec processes total]
```

**Root Cause**: No singleton process management preventing duplicate spawning.

### Startup Sequence Issues

**Problem**: MCP servers being spawned repeatedly without:
1. Checking for existing instances
2. Process registry management
3. Proper cleanup of failed/stopped instances
4. Resource limit enforcement

## Emergency Response Limitations

### 1. BusyBox Compatibility Issues

**Failing Script Components**:
```bash
# This fails in BusyBox:
uniq --all-repeated=separate

# Must use BusyBox-compatible alternatives:
awk 'seen[$0]++'  # For finding duplicates
sort | uniq -d    # For duplicate lines only
```

### 2. Process Management Constraints

**Available BusyBox Commands**:
- `kill PID` - Basic process termination
- `ps aux` - Process listing
- `awk` - Text processing (limited)
- `grep` - Pattern matching
- `sort`, `uniq` - Basic deduplication

**Missing Commands**:
- `pgrep` - Process finding by name
- `pkill` - Process killing by name
- Advanced `uniq` options for duplicate handling

## Immediate Solutions Developed

### 1. Emergency BusyBox-Compatible Script

**File**: `/scripts/emergency-metamcp-busybox-killer.sh`

**Key Features**:
- BusyBox-compatible process deduplication
- Escalating cleanup strategy (duplicates → oldest → all npm exec)
- Emergency container restart as last resort
- Simple temp file approach for tracking seen commands

**Usage**:
```bash
# Standard mode - selective cleanup
./emergency-metamcp-busybox-killer.sh

# Emergency mode - kill all npm/node processes
./emergency-metamcp-busybox-killer.sh true
```

### 2. Host-Based Monitoring Solution

**File**: `/scripts/host-metamcp-monitor.sh`

**Key Features**:
- External monitoring from host system
- Avoids BusyBox limitations entirely
- JSON processing with jq for container stats
- Automatic emergency response triggers
- Comprehensive logging and alerting

**Monitoring Capabilities**:
- Process count tracking
- Memory usage monitoring
- Container health checks
- Automatic cleanup triggers
- Emergency restart procedures

## Docker Resource Enforcement Issues

### PID Limit Not Working

**Investigation Required**:
```bash
# Check if PID limit is actually enforced
docker inspect metamcp | jq '.HostConfig.PidsLimit'

# Check systemd/cgroup enforcement
cat /sys/fs/cgroup/pids/docker/CONTAINER_ID/pids.max
cat /sys/fs/cgroup/pids/docker/CONTAINER_ID/pids.current
```

**Potential Causes**:
1. Docker version not supporting PID limits properly
2. SystemD/cgroup configuration issues
3. Container runtime not enforcing limits
4. Alpine/BusyBox bypassing PID tracking

### Memory Limit Bypassing

**Symptoms**:
- Container shows as healthy despite high process count
- No memory pressure events
- Resource monitoring not triggering alerts

## Process Lifecycle Architecture Issues

### Missing Components

Based on the comprehensive architecture document, the following critical components are **NOT IMPLEMENTED**:

1. **Process Pool Manager** - No singleton process management
2. **Process Registry** - No deduplication system
3. **Health Monitor** - No proactive process monitoring
4. **Cleanup Queue** - No graceful termination system
5. **Resource Monitor** - No automatic corrective actions

### Implementation Gap

**Status**: Architecture complete but **NOT DEPLOYED**
- Comprehensive lifecycle management designed
- All components specified and documented
- Implementation completed but not active
- Container still using old spawn-without-cleanup system

## Recommended Emergency Actions

### Immediate (Next 30 minutes)

1. **Deploy Emergency Script**:
```bash
# Run BusyBox-compatible cleanup
/home/delorenj/docker/trunk-main/scripts/emergency-metamcp-busybox-killer.sh

# Start host-based monitoring
/home/delorenj/docker/trunk-main/scripts/host-metamcp-monitor.sh monitor &
```

2. **Container Restart with Monitoring**:
```bash
# Emergency restart if cleanup fails
docker restart metamcp

# Monitor recovery
watch -n 5 'docker exec metamcp ps aux | grep -E "(npm|node)" | wc -l'
```

### Short Term (Next 24 hours)

1. **Deploy Process Lifecycle Management**:
   - Activate the completed lifecycle architecture
   - Enable singleton process management
   - Implement resource monitoring
   - Set up proper cleanup procedures

2. **Fix Docker Resource Limits**:
   - Investigate PID limit enforcement
   - Ensure memory limits are working
   - Add container-level process monitoring

3. **Implement External Monitoring**:
   - Deploy host-based monitoring daemon
   - Set up alerting and notification
   - Create automated response procedures

### Long Term (Next Week)

1. **Comprehensive Monitoring Dashboard**:
   - Deploy monitoring dashboard service
   - Implement metrics collection
   - Set up performance tracking

2. **Process Architecture Deployment**:
   - Full lifecycle management implementation
   - Health monitoring and recovery
   - Resource limit enforcement

## Alternative Solutions

### 1. Container Runtime Change

**Option**: Switch from current setup to more restrictive runtime:
- Use `--pids-limit` flag directly in docker run
- Implement systemd-based process limiting
- Use container orchestration with better resource control

### 2. External Process Control

**Option**: Host-level process management:
- Monitor from outside container
- Use host tools for process control
- Implement external kill switches

### 3. Application-Level Fixes

**Option**: Fix at MetaMCP application level:
- Implement proper process registry
- Add singleton pattern to MCP server spawning
- Fix startup sequence to prevent duplicates

## Success Metrics

### Immediate Success (24 hours)
- Process count ≤ 15 (down from 536+)
- No process growth over 1 hour periods
- Emergency scripts working in BusyBox environment
- Container resource limits enforced

### Short-term Success (1 week)
- Zero process explosions
- Memory usage < 4GB consistently
- Automated monitoring and recovery working
- Process lifecycle management active

### Long-term Success (1 month)
- 99.9% uptime with no manual intervention
- Comprehensive monitoring dashboard
- Proactive issue detection and resolution
- Documented operational procedures

## Critical Decision Points

### 1. Emergency Response Strategy

**DECISION NEEDED**: Immediate action approach:
- **Option A**: Emergency container restart now (2 minute downtime)
- **Option B**: Deploy BusyBox-compatible cleanup script first
- **Option C**: Implement full lifecycle management immediately

**RECOMMENDATION**: Option B followed by Option A if cleanup fails.

### 2. Resource Limit Enforcement

**DECISION NEEDED**: How to enforce PID limits:
- **Option A**: Fix Docker configuration
- **Option B**: Application-level limits
- **Option C**: External monitoring with kill switches

**RECOMMENDATION**: Combination of A and C for redundancy.

### 3. Monitoring Strategy

**DECISION NEEDED**: Monitoring approach:
- **Option A**: Internal container monitoring (limited by BusyBox)
- **Option B**: External host monitoring (full toolset)
- **Option C**: Hybrid approach with both

**RECOMMENDATION**: Option C - hybrid approach for comprehensive coverage.

## Next Steps

### Immediate Actions Required

1. **Execute Emergency Cleanup**:
   ```bash
   cd /home/delorenj/docker/trunk-main/scripts
   chmod +x emergency-metamcp-busybox-killer.sh
   ./emergency-metamcp-busybox-killer.sh
   ```

2. **Start Host Monitoring**:
   ```bash
   chmod +x host-metamcp-monitor.sh
   nohup ./host-metamcp-monitor.sh monitor > /tmp/monitor.log 2>&1 &
   ```

3. **Validate Process Count**:
   ```bash
   watch -n 10 'docker exec metamcp ps aux | grep -E "(npm|node)" | wc -l'
   ```

### Follow-up Actions

1. Investigate Docker PID limit enforcement
2. Deploy process lifecycle management architecture
3. Implement comprehensive monitoring dashboard
4. Create operational runbooks and procedures

---

**Report Status**: URGENT - IMMEDIATE ACTION REQUIRED  
**Process Count**: 536+ and growing  
**Risk Level**: CRITICAL - System instability imminent  
**Next Review**: Every 30 minutes until resolved  

**Investigation Team**: Claude Code Emergency Response  
**Document Version**: 1.0  
**Created**: 2025-09-09 (Current Crisis)