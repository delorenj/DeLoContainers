# Docker Memory Diagnostics Suite

This directory contains comprehensive diagnostic scripts to identify and resolve Docker-related memory issues, specifically designed to address the 120GB memory consumption problem.

## 🚨 Critical Findings

Based on the analysis, the following containers are consuming excessive memory:

1. **MetaMCP**: 70.22GB (57.93% of total memory) - **CRITICAL ISSUE**
2. **Windows VM**: 68.72GB volume data + 32GB RAM allocation
3. **Qdrant**: 2.529GB + 20GB+ volume storage
4. **Build Cache**: 11.26GB

## 📋 Available Scripts

### 1. `docker-memory-leak-detector.sh`
**Primary diagnostic script** - Comprehensive analysis of Docker memory usage.

```bash
# Run full memory analysis
./docker-memory-leak-detector.sh

# View generated report
cat memory-leak-report-*.txt
```

**Features:**
- Identifies high memory consuming containers
- Analyzes container configurations for memory limits
- Checks for dangling images and unused volumes
- Examines container restart patterns (indicates memory issues)
- Provides specific recommendations for each problem

### 2. `container-memory-monitor.sh`
**Real-time monitoring** - Continuous memory leak detection.

```bash
# Start continuous monitoring
./container-memory-monitor.sh

# Runs in background, alerts when:
# - Container exceeds 1GB memory usage
# - Memory grows by 20%+ in 5 minutes
```

**Features:**
- Real-time memory growth detection
- Configurable alert thresholds
- Automated logging to `container-memory-monitor.log`
- Extensible for email/Slack notifications

### 3. `memory-cleanup.sh`
**Resource cleanup** - Safe cleanup of Docker resources.

```bash
# Dry run (see what would be cleaned)
./memory-cleanup.sh --dry-run

# Actually perform cleanup
./memory-cleanup.sh
```

**Features:**
- Removes dangling images and unused volumes
- Cleans up stopped containers and unused networks
- Manages build cache
- Restarts problematic containers
- Safe operation with dry-run mode

### 4. `metamcp-memory-analyzer.sh`
**Specific analysis** for the MetaMCP container (primary culprit).

```bash
./metamcp-memory-analyzer.sh
```

**Features:**
- Deep analysis of MetaMCP container memory usage
- Process and filesystem analysis inside container
- Claude Flow specific diagnostics
- Memory leak pattern detection
- Specific recommendations for MetaMCP

### 5. `fix-memory-issues.sh`
**Automated fixes** - Apply solutions for identified memory issues.

```bash
# Dry run - see what would be fixed
./fix-memory-issues.sh

# Apply fixes
./fix-memory-issues.sh --apply
```

**Features:**
- Adds memory limits to containers without limits
- Restarts problematic containers
- Stops Windows VM if not needed
- Sets up automated monitoring
- Backs up configuration files before changes

## 🚨 Immediate Actions Required

Based on the analysis, take these immediate steps:

### 1. Critical Memory Leak - MetaMCP
```bash
# Restart MetaMCP to clear memory leaks
docker restart metamcp

# Add memory limits (see fix-memory-issues.sh)
# Add to metamcp/compose.yml:
deploy:
  resources:
    limits:
      memory: 4G
    reservations:
      memory: 2G
```

### 2. Windows VM Resource Management
```bash
# Stop if not actively needed
docker stop windows

# Or reduce RAM allocation in compose.yml:
# Change RAM_SIZE from "32G" to "16G" or "8G"
```

### 3. Resource Cleanup
```bash
# Clean up Docker resources
./memory-cleanup.sh --apply

# Remove unused volumes
docker volume prune -f

# Clean build cache
docker builder prune -f
```

## 📊 Usage Examples

### Quick Memory Check
```bash
# Current memory usage
docker stats --no-stream

# Full analysis
./docker-memory-leak-detector.sh
```

### Set Up Monitoring
```bash
# Start background monitor
nohup ./container-memory-monitor.sh > /dev/null 2>&1 &

# Add to cron for regular checks
echo "0 */2 * * * $PWD/docker-memory-leak-detector.sh" | crontab -
```

### Emergency Memory Relief
```bash
# Quick memory relief
docker restart metamcp
docker stop windows
docker system prune -f

# Full automated fix
./fix-memory-issues.sh --apply
```

## 🔍 Understanding the Memory Issue

### Root Causes Identified:

1. **MetaMCP Container (Primary Issue)**:
   - No memory limits set
   - Consuming 70GB+ memory
   - Likely memory leak in Claude Flow or MCP processes
   - Long-running container accumulating memory

2. **Windows VM (Secondary Issue)**:
   - 32GB RAM allocation
   - 68.72GB volume storage
   - May not be actively needed

3. **Resource Accumulation**:
   - 11.26GB build cache
   - Multiple dangling images
   - Unused volumes consuming space

### Why This Happens "Without Doing Anything":

- **Memory leaks**: Long-running processes gradually consume more memory
- **No limits**: Containers without memory limits can consume all available RAM
- **Resource accumulation**: Docker builds and operations leave behind unused resources
- **Background processes**: Services like MetaMCP run continuously, slowly leaking memory

## 🛠️ Configuration Recommendations

### Add Memory Limits to All Services

Example for any service in `compose.yml`:
```yaml
services:
  your-service:
    # ... other configuration
    deploy:
      resources:
        limits:
          memory: 2G      # Maximum memory
          cpus: '1.0'     # CPU limit
        reservations:
          memory: 512M    # Reserved memory
          cpus: '0.5'     # Reserved CPU
```

### Health Checks for Memory Monitoring
```yaml
services:
  your-service:
    healthcheck:
      test: ["CMD", "sh", "-c", "ps aux | awk '{sum += $$4} END {exit (sum > 80) ? 1 : 0}'"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

## 📈 Monitoring and Alerting

### Log Files
- `memory-leak-report-*.txt` - Detailed analysis reports
- `container-memory-monitor.log` - Real-time monitoring logs
- `memory-cleanup.log` - Cleanup operation logs
- `memory-fixes.log` - Applied fixes log

### Set Up Automated Monitoring
```bash
# Add to crontab for regular monitoring
crontab -e

# Add these lines:
# Run memory check every 2 hours
0 */2 * * * /path/to/docker-diagnostics/docker-memory-leak-detector.sh

# Run cleanup weekly
0 2 * * 0 /path/to/docker-diagnostics/memory-cleanup.sh
```

## 🔧 Troubleshooting

### If Memory Usage Remains High:

1. **Check for hidden processes**:
   ```bash
   # Check host processes
   ps aux --sort=-%mem | head -20
   
   # Check inside containers
   for container in $(docker ps -q); do
       echo "=== $container ==="
       docker exec $container ps aux 2>/dev/null || echo "Cannot access"
   done
   ```

2. **Investigate specific containers**:
   ```bash
   # Deep dive into problematic container
   ./metamcp-memory-analyzer.sh
   
   # Check container logs
   docker logs --tail 1000 container_name | grep -i memory
   ```

3. **System-level investigation**:
   ```bash
   # Check system memory
   free -h
   cat /proc/meminfo
   
   # Check for memory-mapped files
   lsof | grep -i mem
   ```

## 📞 Support

If memory issues persist after running these scripts:

1. Save all generated report files
2. Run `docker system info` and save output
3. Check system logs: `journalctl -u docker.service --since "1 hour ago"`
4. Consider restarting the Docker daemon (last resort)

## ⚠️  Safety Notes

- All scripts include dry-run modes for safety
- Configuration files are automatically backed up
- Scripts are designed to be non-destructive
- Test in development environment first if possible

---

**Remember**: The primary issue is MetaMCP consuming 70GB+ memory without limits. Start there for maximum impact.