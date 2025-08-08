# qBittorrent Test Framework Documentation

## Overview

This comprehensive test framework provides systematic testing procedures for the qBittorrent fix implementation, covering all phases from pre-implementation verification to post-implementation validation and ongoing monitoring.

## Test Structure

### Directory Organization
```
tests/
├── pre-implementation/
│   └── verify-current-issues.sh       # Pre-implementation verification
├── phase-specific/
│   ├── test-permission-fix.sh          # Permission fix validation
│   ├── test-torrent-functionality.sh   # Torrent functionality tests
│   ├── test-web-access.sh              # Web access validation
│   └── test-dns-resolution.sh          # DNS resolution tests
├── post-implementation/
│   └── comprehensive-validation.sh     # Full system validation
├── monitoring/
│   ├── health-check.sh                 # Continuous health monitoring
│   ├── performance-monitor.sh          # Performance metrics collection
│   └── network-monitor.sh              # Network and VPN monitoring
├── results/                            # Test results and logs
└── test-runner.sh                      # Master test orchestrator
```

## Test Phases

### 1. Pre-Implementation Tests (`verify-current-issues.sh`)

**Purpose**: Establish baseline and verify current issues before implementing fixes.

**Tests Performed**:
- Container status verification
- Web UI accessibility check
- External access via Traefik
- VPN connection validation
- Network interface status
- File permissions assessment
- Directory access verification
- Port connectivity tests
- DNS resolution checks

**Usage**:
```bash
cd tests/pre-implementation
./verify-current-issues.sh
```

**Expected Outcomes**: Documents current issues and establishes baseline metrics.

### 2. Phase-Specific Tests

#### Permission Fix Validation (`test-permission-fix.sh`)

**Purpose**: Validate permission corrections after PUID/PGID changes.

**Key Tests**:
- Container UID/GID verification
- Config directory write permissions
- Downloads directory access
- Video directory permissions
- NFS mount validation
- Process user verification
- File ownership checks
- Service restart validation

#### Torrent Functionality (`test-torrent-functionality.sh`)

**Purpose**: Ensure torrent operations work correctly after cleanup.

**Key Tests**:
- qBittorrent daemon health
- WebUI API accessibility
- Port configuration validation
- Network interface binding
- DHT/PEX configuration
- Tracker connectivity
- Download directory structure
- Config file integrity
- Categories configuration
- Resource usage monitoring

#### Web Access Validation (`test-web-access.sh`)

**Purpose**: Verify web interface accessibility after auth reset.

**Key Tests**:
- Local WebUI access
- External access via Traefik
- Port configuration
- Authentication setup
- SSL/HTTPS configuration
- IP whitelist validation
- API access verification
- Response time measurement
- Resource loading
- Cross-origin configuration
- Session management
- Traefik integration

#### DNS Resolution (`test-dns-resolution.sh`)

**Purpose**: Validate DNS functionality after DNS updates.

**Key Tests**:
- Basic DNS resolution
- VPN DNS leak detection
- Public tracker resolution
- DNS response time measurement
- IPv6 DNS support
- DNS caching behavior
- Reverse DNS resolution
- DNS server configuration
- DNS over HTTPS testing
- DNS security features
- DNS failover testing
- VPN tunnel routing

### 3. Post-Implementation Validation (`comprehensive-validation.sh`)

**Purpose**: Complete system validation after all fixes are applied.

**Validation Phases**:
1. **Infrastructure Validation**: Container health, ports, network, VPN
2. **Permission Validation**: UID/GID matching, directory permissions
3. **Web Interface Validation**: Local/external access, API, response times
4. **Torrent Functionality**: Daemon status, ports, interface binding, trackers
5. **DNS and Network**: Basic resolution, leak prevention, tunnel routing
6. **Configuration Integrity**: Config files, critical settings

**Usage**:
```bash
cd tests/post-implementation
./comprehensive-validation.sh
```

## Monitoring Scripts

### Health Check (`health-check.sh`)

**Purpose**: Continuous health monitoring with alerting capabilities.

**Features**:
- Container status monitoring
- Web UI accessibility
- VPN connection validation
- DNS resolution checks
- Port listening verification
- File system permissions
- Memory and disk usage
- Alert webhook integration

**Usage**:
```bash
# Single health check
./health-check.sh

# Continuous monitoring
./health-check.sh --continuous --interval=300 --alert-webhook=https://hooks.slack.com/...
```

### Performance Monitor (`performance-monitor.sh`)

**Purpose**: Collect detailed performance metrics over time.

**Metrics Collected**:
- CPU usage (qBittorrent, Gluetun)
- Memory consumption
- Network I/O throughput
- Disk I/O statistics
- System load average
- Disk space utilization
- VPN tunnel throughput
- qBittorrent API metrics

**Usage**:
```bash
# 5-minute monitoring session
./performance-monitor.sh --duration=300

# Custom duration and output
./performance-monitor.sh --duration=3600 --output=performance_custom.json
```

### Network Monitor (`network-monitor.sh`)

**Purpose**: Monitor network connectivity and detect potential leaks.

**Monitoring Areas**:
- VPN IP address validation
- DNS resolution testing
- Network interface status
- Routing table verification
- Port connectivity
- Network throughput measurement
- DNS leak detection
- WebRTC leak testing
- IPv6 leak prevention

**Usage**:
```bash
# Basic network monitoring
./network-monitor.sh --duration=300

# With comprehensive leak testing
./network-monitor.sh --duration=600 --check-leaks
```

## Master Test Runner (`test-runner.sh`)

**Purpose**: Orchestrate all testing phases and generate comprehensive reports.

**Capabilities**:
- Run individual test phases
- Execute complete test suites
- Generate HTML reports
- Continuous monitoring mode
- Detailed logging and metrics

**Usage Examples**:
```bash
# Run all tests
./test-runner.sh

# Run specific phase
./test-runner.sh --phase=post

# Start continuous monitoring
./test-runner.sh --continuous

# Run without generating report
./test-runner.sh --phase=web --no-report
```

## Test Results and Reporting

### JSON Output Format

All tests generate structured JSON output containing:
- Test metadata (timestamp, suite name, configuration)
- Individual test results with status, messages, and details
- Summary statistics (total, passed, failed, warnings)
- Execution timing and performance data

### HTML Reports

The master test runner generates comprehensive HTML reports featuring:
- Executive summary with key metrics
- Detailed test results tables
- Visual status indicators
- Links to detailed logs
- Configuration information
- Raw JSON data access

### Log Files

Each test generates detailed log files stored in `tests/results/`:
- Timestamped execution logs
- Error details and debugging information
- Performance metrics and timing data
- Historical data for trend analysis

## Best Practices

### Test Execution Order

1. **Pre-Implementation**: Run before any changes to establish baseline
2. **Phase-Specific**: Execute after each implementation phase
3. **Post-Implementation**: Comprehensive validation after all fixes
4. **Monitoring**: Continuous monitoring for ongoing health verification

### Error Handling

- All scripts include proper error handling and exit codes
- Failed tests don't stop subsequent test execution
- Detailed error information captured in logs
- Alert integration for critical failures

### Maintenance

- Regular cleanup of old log files (configurable retention)
- JSON validation for all output files
- Automatic report generation with historical trends
- Integration with external monitoring systems

## Integration Points

### CI/CD Integration

Tests can be integrated into CI/CD pipelines:
```bash
# Pre-deployment validation
./test-runner.sh --phase=pre

# Post-deployment verification
./test-runner.sh --phase=post
```

### Monitoring Integration

Health checks integrate with external monitoring:
- Webhook alerts for critical failures
- Metrics export to monitoring systems
- Dashboard integration for real-time status
- Historical data analysis and trending

### Docker Compose Integration

Tests work seamlessly with the Docker Compose stack:
- Automatic service discovery
- Container health validation
- Network connectivity verification
- Volume mount testing

## Troubleshooting

### Common Issues

1. **Permission Errors**: Ensure test scripts are executable
2. **Network Timeouts**: Adjust timeout values for slow connections
3. **JSON Parsing Errors**: Verify jq is installed and accessible
4. **Docker Access**: Ensure proper Docker daemon access

### Debug Mode

Enable verbose logging by setting:
```bash
export DEBUG=1
./test-runner.sh --phase=all
```

### Log Analysis

Use the generated JSON files for detailed analysis:
```bash
# Find failed tests
jq '.tests[] | select(.status == "FAIL")' results/test_results.json

# Calculate success rate
jq '.summary.passed / .summary.total * 100' results/test_results.json
```

## Future Enhancements

### Planned Features

- Automated test scheduling with cron integration
- Email notification support
- Integration with external bug tracking systems
- Performance baseline comparison
- Automated remediation for common issues
- Multi-environment test orchestration

### Extensibility

The framework is designed for easy extension:
- Modular test scripts for easy addition
- Consistent JSON output format
- Pluggable alert mechanisms
- Configurable test parameters
- Custom report templates

This test framework provides comprehensive coverage for qBittorrent implementation validation, ensuring reliability, performance, and security throughout the deployment lifecycle.