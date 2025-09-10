# MetaMCP Emergency Response Protocol

## 🚨 IMMEDIATE CRISIS RESPONSE

### Current Status: CRITICAL
- **Process Count**: 515+ processes (EXPLOSIVE GROWTH)
- **Memory Usage**: 10.72GB+ and climbing  
- **Growth Rate**: ~30 processes every 30 seconds
- **Risk Level**: SYSTEM STABILITY THREAT

## Phase 1: IMMEDIATE INTERVENTION (Execute NOW!)

### Option A: Emergency Process Cleanup
```bash
# Execute immediate nuclear cleanup
cd /home/delorenj/docker/trunk-main/scripts
chmod +x EMERGENCY-METAMCP-REMEDIATION.sh
./EMERGENCY-METAMCP-REMEDIATION.sh crisis
```

### Option B: Container Restart (If cleanup fails)
```bash
# Force restart with enhanced limits
docker stop metamcp
sleep 10
docker start metamcp

# Apply immediate monitoring
./EMERGENCY-METAMCP-REMEDIATION.sh monitor
```

### Option C: Nuclear Option (Last resort)
```bash
# Complete container recreation
docker stop metamcp
docker rm metamcp
cd /home/delorenj/docker/trunk-main/stacks/utils/metamcp
docker-compose up -d
```

## Phase 2: RESOURCE ENFORCEMENT

### Deploy Hard Limits
```bash
# Apply multiple enforcement layers
chmod +x metamcp-docker-enforcer.sh
./metamcp-docker-enforcer.sh enforce
```

**Enforcement Methods Applied:**
1. **Docker Limits**: 4GB memory, 25 process limit
2. **Cgroup Controls**: Direct kernel resource limits  
3. **Container ulimits**: Internal process restrictions
4. **Active Monitoring**: Real-time enforcement

## Phase 3: STARTUP PROTECTION

### Prevent Re-explosion on Restart
```bash
# Deploy startup explosion prevention
chmod +x metamcp-startup-preventer.sh
./metamcp-startup-preventer.sh prevent
```

**Prevention Measures:**
- Process spawn rate limiting
- npm/node wrapper controls
- Startup sequence monitoring
- Resource limit enforcement

## Phase 4: CONTINUOUS MONITORING

### Multi-Layer Monitoring System

#### Nuclear Monitor (Aggressive)
- **Check Interval**: 10 seconds
- **Nuclear Threshold**: 30 processes
- **Action**: Immediate kill -9 all npm/node
- **Log**: `/tmp/metamcp-nuclear-monitor.log`

#### Host Monitor (Container Level)  
- **Check Interval**: 30 seconds
- **Triggers**: >8GB memory OR >100 processes
- **Action**: Container restart
- **Log**: `/tmp/metamcp-host-monitor.log`

#### Resource Enforcer (Gradual)
- **Check Interval**: 15 seconds  
- **Actions**: Memory cleanup, process limiting
- **Method**: Kill highest memory/oldest processes
- **Log**: `/tmp/metamcp-resource-enforcer.log`

## Crisis Response Decision Tree

```
Process Count Check
├── <15 processes: ✅ NORMAL
│   └── Deploy monitoring only
├── 15-30 processes: ⚠️ WARNING  
│   └── Deploy enhanced monitoring
├── 30-100 processes: 🔥 CRITICAL
│   └── Execute emergency cleanup
└── >100 processes: ☢️ NUCLEAR
    └── Container restart required
```

## Container Configuration (Applied)

```yaml
# Current safety limits in docker-compose.yml
services:
  metamcp:
    mem_limit: 4g           # Hard memory limit
    mem_reservation: 1g     # Reserved memory
    cpus: 2.0              # CPU limit
    pids_limit: 25         # Process limit
    
    # Additional security
    security_opt:
      - no-new-privileges:true
    
    # Process limits via ulimits
    ulimits:
      nproc: 100           # User process limit
      nofile:
        soft: 1024
        hard: 2048
        
    # Resource monitoring environment
    environment:
      - MAX_PROCESSES=15
      - MAX_MEMORY_MB=4096
      - ENABLE_RESOURCE_MONITORING=true
```

## Monitoring Dashboard Access

- **URL**: http://localhost:3001/monitor
- **Traefik**: https://monitor.metamcp.local.delorenj.dev
- **Real-time Metrics**: Process count, memory, alerts
- **Log Access**: All monitoring logs centralized

## Alert Thresholds

### Memory Alerts
- **Warning**: >75% of 4GB limit (3GB)
- **Critical**: >90% of 4GB limit (3.6GB)  
- **Emergency**: >95% of 4GB limit (3.8GB)

### Process Alerts  
- **Warning**: >15 processes
- **Critical**: >30 processes
- **Emergency**: >50 processes
- **Nuclear**: >100 processes

### Response Actions
- **Warning**: Log alert, continue monitoring
- **Critical**: Begin process cleanup
- **Emergency**: Aggressive process termination
- **Nuclear**: Container restart

## Manual Intervention Commands

### Check Current Status
```bash
# Process count
docker exec metamcp ps aux | wc -l

# Memory usage
docker stats --no-stream metamcp

# Container health
docker ps | grep metamcp
```

### Emergency Cleanup (Manual)
```bash
# Kill all npm processes
docker exec metamcp pkill -f npm

# Kill all node processes (except essential)  
docker exec metamcp sh -c 'ps aux | grep node | grep -v "docker-entrypoint" | awk "{print \$2}" | xargs kill'

# Clean zombies
docker exec metamcp sh -c 'ps aux | awk "\$8 ~ /^[Zz]/ {print \$2}" | xargs kill -9'
```

### Resource Enforcement (Manual)
```bash
# Apply Docker limits
docker update --memory=4g --memory-swap=4g --pids-limit=25 metamcp

# Check limits applied
docker inspect metamcp | grep -E "(Memory|Pids)"
```

## Recovery Validation

### Success Criteria
- ✅ Process count: <15 processes
- ✅ Memory usage: <2GB stable
- ✅ No exponential growth for 10+ minutes
- ✅ All monitoring systems active
- ✅ Container healthy status

### Validation Commands
```bash
# Full status check
./EMERGENCY-METAMCP-REMEDIATION.sh crisis

# Monitor for 5 minutes
watch -n 30 'docker exec metamcp ps aux | wc -l; docker stats --no-stream metamcp'

# Check logs for growth patterns
tail -f /tmp/metamcp-*.log
```

## Long-term Prevention

### Container Image Modifications (Future)
- Process lifecycle management system
- Built-in resource monitoring  
- Singleton process managers
- Health check endpoints

### Infrastructure Changes
- Kubernetes resource quotas
- Pod security policies  
- Horizontal Pod Autoscaler with limits
- Resource monitoring with Prometheus

### Operational Procedures
- Daily process count checks
- Weekly memory usage reports
- Monthly container restart cycles
- Quarterly limit adjustments

## Escalation Procedures

### Level 1: Automated Response
- Monitoring systems handle automatically
- No manual intervention required
- Alerts logged only

### Level 2: Operations Alert  
- Process count >30 or memory >3GB
- Operations team notified
- Manual validation required

### Level 3: Critical Incident
- Process explosion continues after cleanup
- Multiple container restarts required  
- Engineering team involvement

### Level 4: System Emergency
- Host system impact detected
- Multiple services affected
- Immediate engineering response
- Consider service isolation

## Communication Templates

### Alert Notification
```
Subject: MetaMCP Process Explosion Alert - Level [X]

Current Status:
- Process Count: [X] (limit: 15)
- Memory Usage: [X]GB (limit: 4GB)  
- Duration: [X] minutes
- Trend: [Growing/Stable/Declining]

Actions Taken:
- [Automatic/Manual cleanup]
- [Monitoring deployed]
- [Container restart: Y/N]

Next Steps:
- [Continue monitoring]
- [Engineering investigation]
- [Schedule restart]

Monitoring: http://monitor.metamcp.local.delorenj.dev
```

### Resolution Notification  
```
Subject: MetaMCP Process Explosion - RESOLVED

Resolution Summary:
- Issue Duration: [X] minutes
- Peak Process Count: [X]
- Peak Memory Usage: [X]GB
- Resolution Method: [Cleanup/Restart/Other]

Current Status:
- Process Count: [X] (normal)
- Memory Usage: [X]GB (normal)
- System Stable: Yes

Prevention Measures:
- Enhanced monitoring: Active
- Resource limits: Enforced  
- Startup controls: Deployed

No further action required.
```

## Post-Incident Actions

### Immediate (Within 1 hour)
- [ ] Validate all monitoring systems active
- [ ] Confirm resource limits applied
- [ ] Document timeline and actions taken
- [ ] Verify no related system impacts

### Short-term (Within 24 hours)
- [ ] Analyze root cause from logs
- [ ] Review monitoring thresholds
- [ ] Update runbooks if needed
- [ ] Schedule follow-up check

### Long-term (Within 1 week)
- [ ] Implement additional preventive measures
- [ ] Update container image if needed
- [ ] Review resource allocation
- [ ] Train team on new procedures

---

**Document Status**: ACTIVE EMERGENCY PROTOCOL  
**Last Updated**: 2025-09-09  
**Next Review**: After incident resolution