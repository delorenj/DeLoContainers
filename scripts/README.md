# Memory Leak Investigation Scripts

This directory contains comprehensive system monitoring scripts designed to establish baseline metrics and detect memory leaks, particularly the "without doing anything" memory growth pattern.

## Scripts Overview

### 1. memory_monitor.sh
**Purpose**: Continuous memory monitoring with detailed metrics collection

**Features**:
- System memory usage tracking over time
- Process-level memory consumption analysis
- Docker container memory usage monitoring
- Memory fragmentation analysis via buddy allocator and slab info
- Swap usage pattern tracking
- Memory pressure detection via PSI (Pressure Stall Information)

**Usage**:
```bash
# Monitor for 60 minutes with 30-second intervals (default)
./memory_monitor.sh

# Custom duration and interval
./memory_monitor.sh 120 15  # 120 minutes, 15-second intervals
```

**Output**: Creates timestamped log files in `/var/log/memory-monitor/`
- `memory_monitor_TIMESTAMP_memory.log` - System memory metrics
- `memory_monitor_TIMESTAMP_processes.log` - Process memory usage
- `memory_monitor_TIMESTAMP_docker.log` - Container metrics
- `memory_monitor_TIMESTAMP_fragmentation.log` - Memory fragmentation data
- `memory_monitor_TIMESTAMP_swap.log` - Swap usage patterns
- `memory_monitor_TIMESTAMP_summary.log` - Consolidated summary

### 2. process_analyzer.sh
**Purpose**: In-depth process analysis for identifying memory growth patterns and leaks

**Features**:
- Top memory consumers identification (RSS and VSZ)
- Memory growth pattern analysis over 5-minute periods
- Zombie process detection and parent tracking
- File descriptor leak analysis
- Shared memory usage investigation
- Process memory mapping details via /proc/PID/smaps
- Automated alert generation

**Usage**:
```bash
# Use default output location
./process_analyzer.sh

# Specify custom output file
./process_analyzer.sh /path/to/analysis-report.log
```

**Key Metrics**:
- Memory growth rates per process
- File descriptor usage patterns  
- Shared vs private memory ratios
- System V and POSIX shared memory segments

### 3. boot_diagnostics.sh
**Purpose**: Automated diagnostics that run on boot to capture baseline and detect autonomous memory growth

**Features**:
- Captures initial system state at boot
- Monitors memory growth without user interaction
- Tracks kernel memory allocation patterns
- Logs critical system events via journalctl
- Automatic alert generation for anomalies
- Can be installed as systemd service for automatic execution

**Usage**:
```bash
# Run manual diagnostics (2-hour monitoring)
sudo ./boot_diagnostics.sh

# Install as systemd service for automatic boot execution
sudo ./boot_diagnostics.sh --install-service

# Check service status
sudo systemctl status boot-diagnostics.service
```

**Output**: Creates session-based logs in `/var/log/boot-diagnostics/`
- `boot-TIMESTAMP_boot.log` - Initial boot state
- `boot-TIMESTAMP_memory.log` - Memory growth tracking (CSV format)
- `boot-TIMESTAMP_processes.log` - Process monitoring
- `boot-TIMESTAMP_kernel.log` - Kernel memory analysis
- `boot-TIMESTAMP_system.log` - System events
- `boot-TIMESTAMP_alerts.log` - Automated alerts
- `boot-TIMESTAMP_summary.log` - Session summary

## Key Investigation Targets

### "Without Doing Anything" Memory Growth
These scripts are specifically designed to detect autonomous memory growth:

1. **Boot Diagnostics** captures baseline immediately after boot
2. **Memory Monitor** tracks continuous growth patterns
3. **Process Analyzer** identifies which processes are growing

### Critical Metrics Tracked

**System Level**:
- Total/Available/Used memory trends
- Memory pressure (PSI) indicators
- Swap usage patterns
- Memory fragmentation (buddy allocator)
- Kernel slab allocation

**Process Level**:
- RSS (Resident Set Size) growth
- VSZ (Virtual Size) expansion  
- Memory mapping changes
- File descriptor accumulation
- Shared memory usage

**Container Level** (if Docker present):
- Container memory limits vs usage
- Docker system space consumption
- Per-container memory statistics

## Quick Start Investigation

1. **Install boot diagnostics service** (run once):
   ```bash
   sudo ./boot_diagnostics.sh --install-service
   ```

2. **Run immediate analysis**:
   ```bash
   # Start continuous monitoring
   ./memory_monitor.sh 180 30 &  # 3 hours, 30-sec intervals
   
   # Run process analysis
   ./process_analyzer.sh
   ```

3. **Reboot system** to activate boot diagnostics

4. **Review logs** after the leak manifests:
   ```bash
   # Check latest boot diagnostics
   sudo ls -la /var/log/boot-diagnostics/
   sudo cat /var/log/boot-diagnostics/boot-*_summary.log
   
   # Review memory trends  
   ls -la /var/log/memory-monitor/
   cat /var/log/memory-monitor/memory_monitor_*_summary.log
   ```

## Alert Conditions

All scripts generate alerts for:
- Memory usage > 80% (configurable)
- Swap usage > 0
- Zombie processes detected
- File descriptor usage > 80% of system limit
- Abnormal memory growth rates (> 10% in monitoring period)

## Log File Formats

**Memory Monitor CSV**: Timestamp,Total_KB,Used_KB,Free_KB,Available_KB,Buffers_KB,Cached_KB,Usage_Percent,Top_Process,Top_Process_Mem

**Process Analysis**: Human-readable sections with headers, tables, and summaries

**Boot Diagnostics**: Structured sections with timestamps for correlation

## Troubleshooting

**Permission Issues**:
- Memory monitor: Requires read access to /proc
- Process analyzer: Requires read access to /proc/PID/smaps  
- Boot diagnostics: Requires root for complete system access

**Missing Dependencies**:
- `ps`, `free`, `lsof` - Part of most Linux distributions
- `docker` - Only needed if analyzing containers
- `systemctl` - For service installation
- `journalctl` - For system event monitoring

## Advanced Usage

**Custom Monitoring Periods**:
```bash
# Long-term monitoring (24 hours, 5-minute intervals)  
./memory_monitor.sh 1440 300

# High-frequency monitoring (30 minutes, 5-second intervals)
./memory_monitor.sh 30 5
```

**Automated Analysis Chain**:
```bash
# Run all scripts in sequence
./boot_diagnostics.sh &
sleep 60
./memory_monitor.sh 120 30 &
./process_analyzer.sh /var/log/combined-analysis.log
```

**Integration with System Monitoring**:
The CSV output from memory monitoring can be imported into monitoring systems like Grafana, or processed with analysis tools like Python pandas for trend analysis.