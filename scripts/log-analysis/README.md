# Memory Leak Investigation Tools

This directory contains comprehensive log analysis tools for investigating memory leaks and "doing nothing" memory growth patterns on the system.

## 🚨 Critical Findings from Initial Analysis

Based on the immediate investigation, several **critical memory issues** have been identified:

### 1. **Multiple OOM (Out of Memory) Events**
- **Recent OOM kills**: September 8th (today) and September 3rd
- **Affected processes**: Slack (1.4GB), Code/VS Code (1.4GB), Node/Vitest (13GB), gnome-software
- **Pattern**: Large applications being killed by OOM killer

### 2. **Container Restart Loops** 
- **Currently restarting**: `docker-plugin_daemon-1` and `livekit-ingress`
- **Exit codes**: Container failing with code 2 repeatedly
- **Memory correlation**: Restart loops often indicate memory pressure

### 3. **Graphics Memory Allocation Failures**
- **GPU memory issues**: Cannot allocate memory for external display (LG TV)
- **Pattern**: Repeated failures on HDMI-2 display
- **Impact**: May contribute to system memory pressure

## 🛠️ Available Tools

### Analysis Scripts (`/parsers/`)
- **`memory_leak_analyzer.sh`** - System-wide memory leak detection
- **`docker_log_analyzer.sh`** - Docker container log analysis
- **`cron_task_analyzer.sh`** - Scheduled task investigation

### Monitoring Tools (`/monitors/`)
- **`continuous_memory_monitor.sh`** - Real-time memory monitoring
  - Alerts when memory usage > 80%
  - Logs top processes during high usage
  - Monitors container restart patterns

### Utilities (`/utils/`)
- **`pattern_detector.sh`** - Memory pattern analysis
- **`master_analyzer.sh`** - Comprehensive investigation orchestrator

## 🚀 Quick Start

### Immediate Investigation
```bash
# Run comprehensive analysis
./scripts/log-analysis/utils/master_analyzer.sh

# Start continuous monitoring (runs in background)
./scripts/log-analysis/monitors/continuous_memory_monitor.sh &
```

### Individual Analysis
```bash
# Memory leak analysis
./scripts/log-analysis/parsers/memory_leak_analyzer.sh

# Docker container issues
./scripts/log-analysis/parsers/docker_log_analyzer.sh

# Scheduled task correlation
./scripts/log-analysis/parsers/cron_task_analyzer.sh
```

## 📊 Key Findings Summary

### Memory Growth Patterns
1. **"Doing Nothing" Growth**: System shows memory pressure even during idle periods
2. **Container Issues**: Multiple containers in restart loops indicating memory problems
3. **Large Process Memory**: Applications like VS Code and Slack consuming 1.4GB+ before OOM

### Probable Causes
1. **Memory leaks in long-running applications** (VS Code, Slack, Node processes)
2. **Container memory limits** not properly configured
3. **Graphics subsystem** consuming excessive memory for external displays
4. **Background processes** accumulating memory over time

## 🔧 Recommended Actions

### Immediate (Critical)
1. **Restart problematic containers**:
   ```bash
   docker restart docker-plugin_daemon-1 livekit-ingress
   ```

2. **Set container memory limits**:
   ```bash
   # Add to docker-compose.yml
   mem_limit: 512m
   memswap_limit: 1g
   ```

3. **Monitor large applications**:
   - VS Code: Consider restarting periodically
   - Slack: Known for memory leaks, restart daily
   - Node processes: Check for memory leaks in development tools

### Ongoing (Prevention)
1. **Enable continuous monitoring**:
   ```bash
   # Add to cron
   @reboot /home/delorenj/docker/trunk-main/scripts/log-analysis/monitors/continuous_memory_monitor.sh &
   ```

2. **Schedule regular analysis**:
   ```bash
   # Add to cron
   0 */6 * * * /home/delorenj/docker/trunk-main/scripts/log-analysis/utils/master_analyzer.sh
   ```

3. **Container resource limits**: Add memory limits to all Docker containers

### Long-term (Optimization)
1. **Memory limit enforcement** for all containers
2. **Regular cleanup** of large applications
3. **Graphics memory optimization** for multi-monitor setups
4. **Monitoring dashboard** for memory trends

## 📈 Memory Usage Patterns

The investigation reveals several concerning patterns:

- **OOM events occur during development work** (VS Code, Node processes)
- **Container restarts correlate with system memory pressure**
- **Graphics memory failures indicate resource competition**
- **Memory growth continues during "idle" periods**

## 🔍 Investigation Focus Areas

1. **VS Code/Electron apps**: Major memory consumers (1.4GB+ before OOM)
2. **Node.js development processes**: Vitest consuming 13GB before kill
3. **Container orchestration**: Restart loops indicating memory limits
4. **Graphics subsystem**: External display memory allocation failures

## 📁 Report Locations

All analysis reports are saved in `/scripts/log-analysis/reports/` with timestamps:
- `master_memory_investigation_TIMESTAMP.txt` - Comprehensive analysis
- `memory_leak_analysis_TIMESTAMP.txt` - System memory analysis  
- `docker_analysis_TIMESTAMP.txt` - Container-specific analysis
- `cron_task_analysis_TIMESTAMP.txt` - Scheduled task analysis
- `memory_patterns_TIMESTAMP.txt` - Pattern detection results

## 🚨 Alert Thresholds

- **Memory usage > 80%**: Critical alert with process analysis
- **Container restarts**: Immediate investigation trigger
- **OOM events**: System-wide memory analysis
- **Failed memory allocations**: Graphics/display investigation

## 💡 Tips for "Doing Nothing" Investigation

The mysterious "without doing anything" memory growth can be attributed to:

1. **Background VS Code extensions** continuing to consume memory
2. **Electron app memory leaks** (Slack, Discord, etc.)
3. **Container restart loops** consuming system resources
4. **Graphics buffers** for external displays not being released
5. **Development server processes** running in the background

## 🔗 Integration with System Monitoring

These tools can be integrated with:
- **Grafana/Prometheus** for visualization
- **System cron** for automated analysis
- **Docker health checks** for container monitoring
- **Alerting systems** for critical memory events

---

**Start with**: `./scripts/log-analysis/utils/master_analyzer.sh` for immediate comprehensive analysis.