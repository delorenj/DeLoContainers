# Synology NAS Emergency Recovery Runbook

## 🚨 IMMEDIATE ACTION CHECKLIST

### First 5 Minutes
- [ ] **Assess Impact**: Production systems affected?
- [ ] **Check Physical State**: Power, LEDs, network cables
- [ ] **Test Basic Connectivity**: Ping, web interface, SSH
- [ ] **Determine Access Level**: Physical, network, remote only
- [ ] **Alert Stakeholders**: Notify affected teams

### Critical Decision Points
```
1. Can you physically access the device? → YES/NO
2. Is data currently accessible via any method? → YES/NO
3. Is this a production-critical system? → YES/NO
4. Do you have recent backups verified? → YES/NO
5. What is the maximum acceptable downtime? → [TIME]
```

---

## 🔧 RECOVERY PROCEDURES BY SCENARIO

### Scenario A: Admin Lockout (Most Common)
**Symptoms**: Can access web interface but cannot login
**Data Risk**: 🟢 None
**Downtime**: 5-10 minutes

#### Steps:
1. **Locate Reset Button**: Usually on back panel
2. **Execute Mode 1 Reset**:
   ```bash
   # While system is powered ON
   Press and hold RESET for 4 seconds
   Release when you hear BEEP
   Wait for blue LED to become solid
   ```
3. **Reconnect**:
   ```bash
   # Find new IP address
   Use Synology Assistant or check DHCP leases
   Access: http://[NEW_IP]:5000
   Login: admin (no password)
   ```
4. **Reconfigure**:
   - Set new admin password
   - Configure network settings
   - Re-enable services as needed

### Scenario B: Network Configuration Issues
**Symptoms**: Cannot reach web interface, device appears online
**Data Risk**: 🟢 None
**Downtime**: 10-15 minutes

#### Steps:
1. **Physical Reset**:
   ```bash
   Power cycle the device
   Execute Mode 1 Reset (4 seconds)
   ```
2. **Network Discovery**:
   ```bash
   # Use Synology Assistant
   Download from: global.download.synology.com
   Launch → Search → Connect to discovered device

   # Or manual discovery
   nmap -sn 192.168.1.0/24 | grep -i synology
   arp -a | grep -i synology
   ```
3. **Reconfigure Network**:
   - Access via Assistant or temporary IP
   - Set correct static IP or DHCP
   - Verify DNS and gateway settings

### Scenario C: DSM Corruption
**Symptoms**: Boot loops, partial services, HTTP 500 errors
**Data Risk**: 🟡 Low (data preserved)
**Downtime**: 30-60 minutes

#### Steps:
1. **Backup Critical Config** (if accessible):
   ```bash
   # Via SSH if available
   sudo tar -czf /tmp/config-backup.tar.gz /etc/synoconf.d/
   ```
2. **Execute Mode 2 Reset**:
   ```bash
   # While system is powered ON
   Press and hold RESET for 10 seconds
   Release after 3 consecutive BEEPS
   Wait for orange blinking LED
   ```
3. **Reinstall DSM**:
   ```bash
   # Access Web Assistant: http://[IP]:5000
   Download latest DSM .pat file
   Upload and install (30-45 minutes)
   ```
4. **Restore Configuration**:
   - Import backed-up settings
   - Recreate user accounts
   - Reconfigure services

### Scenario D: Hardware Failure Suspected
**Symptoms**: No boot, unusual LED patterns, disk errors
**Data Risk**: 🟠 High
**Downtime**: 1-4 hours

#### Steps:
1. **Enter Safe Mode**:
   ```bash
   Power OFF completely
   Hold RESET while powering ON
   Continue holding for 10+ seconds
   Release when STATUS LED blinks orange rapidly
   ```
2. **Diagnostic Access**:
   ```bash
   # Serial console (if available)
   Connect USB-to-Serial adapter
   115200 8N1 settings
   Boot and interrupt with Ctrl+C
   ```
3. **Data Recovery Priority**:
   ```bash
   # Mount volumes read-only
   sudo mount -o ro /dev/md2 /volume1

   # Check file system integrity
   sudo fsck -n /dev/md0  # read-only check

   # Extract critical data
   sudo cp -r /volume1/critical_data /tmp/rescue/
   ```

### Scenario E: Complete System Failure
**Symptoms**: No response, no LEDs, no network activity
**Data Risk**: 🔴 Critical
**Downtime**: 4-24 hours

#### Steps:
1. **Hardware Verification**:
   ```bash
   Check power supply (LED on adapter)
   Test with different power cable
   Verify power button responsiveness
   Check for obvious physical damage
   ```
2. **Emergency Data Access**:
   ```bash
   # Remove drives carefully
   # Install in USB-SATA adapter
   # Mount on recovery system
   # RAID configuration may require special tools
   ```
3. **Professional Recovery**:
   - Contact Synology support immediately
   - Prepare for potential RMA process
   - Consider professional data recovery services

---

## 🔍 DIAGNOSTIC COMMANDS

### Network Diagnostics
```bash
# Test basic connectivity
ping [NAS_IP]
nmap -p 22,80,443,5000,5001 [NAS_IP]

# Check web services
curl -I http://[NAS_IP]:5000
curl -k -I https://[NAS_IP]:5001

# SSH connectivity test
ssh -o ConnectTimeout=10 admin@[NAS_IP]
```

### System Status via SSH
```bash
# System health overview
sudo synoinfo --display all | grep -E "(uptime|temperature|status)"

# Storage status
sudo cat /proc/mdstat
sudo df -h

# Service status
sudo systemctl status synod
sudo systemctl status nginx

# Recent errors
sudo tail -50 /var/log/messages | grep -i error
sudo dmesg | grep -i "error\|fail\|warn"
```

### Hardware Diagnostics
```bash
# CPU and memory
sudo cat /proc/cpuinfo
sudo free -m
sudo cat /proc/loadavg

# Disk health
sudo smartctl -a /dev/sda
sudo smartctl -a /dev/sdb

# Temperature monitoring
sudo cat /sys/class/hwmon/hwmon*/temp*_input
```

---

## 📞 ESCALATION PROCEDURES

### Level 1: Self-Service Recovery
**Duration**: 0-30 minutes
**Actions**:
- Mode 1/Mode 2 resets
- Basic network reconfiguration
- Service restarts

### Level 2: IT Team Assistance
**Duration**: 30-120 minutes
**Trigger**: Self-service methods failed
**Actions**:
- SSH diagnostics
- Safe mode operations
- Configuration reconstruction

### Level 3: Vendor Support
**Duration**: 2-8 hours
**Trigger**: Hardware issues suspected
**Contact**: Synology Technical Support
**Preparation**:
- Serial number ready
- Symptom documentation
- Recent change log

### Level 4: Professional Recovery
**Duration**: 1-5 days
**Trigger**: Data loss or hardware failure
**Actions**:
- Clean room recovery
- Professional data extraction
- Hardware replacement

---

## 📋 COMMUNICATION TEMPLATES

### Initial Incident Report
```
INCIDENT ID: [AUTO-GENERATED]
TIME: [TIMESTAMP]
SYSTEM: [NAS MODEL AND LOCATION]
IMPACT: [AFFECTED SERVICES/USERS]
SEVERITY: [P1/P2/P3/P4]
INITIAL ASSESSMENT: [BRIEF DESCRIPTION]
ASSIGNED TO: [RESPONDER NAME]
NEXT UPDATE: [TIME + 30 MINUTES]
```

### Hourly Status Update
```
INCIDENT UPDATE #[N] - [TIMESTAMP]
STATUS: [IN PROGRESS/INVESTIGATING/RESOLVED]
ACTIONS TAKEN: [WHAT HAS BEEN DONE]
CURRENT FOCUS: [WHAT IS HAPPENING NOW]
BLOCKERS: [ANY OBSTACLES]
ETA: [ESTIMATED RESOLUTION TIME]
NEXT UPDATE: [TIME + 1 HOUR]
```

### Resolution Report
```
INCIDENT RESOLVED - [TIMESTAMP]
RESOLUTION: [WHAT FIXED THE ISSUE]
ROOT CAUSE: [WHY IT HAPPENED]
TOTAL DOWNTIME: [DURATION]
SERVICES RESTORED: [WHAT IS WORKING]
FOLLOW-UP ACTIONS: [PREVENTIVE MEASURES]
POST-MORTEM: [SCHEDULED DATE/TIME]
```

---

## 🛡️ PREVENTIVE MEASURES

### Daily Monitoring
```bash
# Automated health checks
#!/bin/bash
# Check system status
curl -s http://[NAS_IP]:5000/webapi/entry.cgi?api=SYNO.Core.System&version=1&method=info
# Check storage health
ssh admin@[NAS_IP] "sudo cat /proc/mdstat"
# Check service status
ssh admin@[NAS_IP] "sudo systemctl is-active synod nginx"
```

### Weekly Maintenance
- Configuration backup export
- System update check and installation
- Storage health verification
- Performance metrics review

### Monthly Procedures
- Full disaster recovery test
- Documentation review and updates
- Team training on new procedures
- Vendor support contact verification

### Quarterly Reviews
- Incident analysis and trends
- Recovery time objective (RTO) assessment
- Recovery point objective (RPO) validation
- Business continuity plan updates

---

## 🔗 QUICK REFERENCE LINKS

### Synology Resources
- [Download Center](https://www.synology.com/en-us/support/download)
- [Knowledge Base](https://kb.synology.com/)
- [Community Forum](https://community.synology.com/)
- [Technical Support](https://account.synology.com/support)

### Emergency Tools
- [Synology Assistant](https://global.download.synology.com/download/Utility/Assistant/)
- [Latest DSM](https://www.synology.com/en-us/support/download)
- [Recovery Guide](https://kb.synology.com/en-us/DSM/tutorial/How_to_reset_a_Synology_NAS)

### Internal Resources
- Network diagram: `/docs/network/topology.pdf`
- Asset inventory: `/docs/assets/nas-inventory.xlsx`
- Contact list: `/docs/contacts/emergency-contacts.txt`
- Backup schedule: `/docs/backup/schedule-matrix.xlsx`

---

**🔴 EMERGENCY HOTLINE**: [YOUR-INTERNAL-NUMBER]
**📧 INCIDENT EMAIL**: incidents@yourcompany.com
**💬 SLACK CHANNEL**: #infrastructure-alerts

**Last Updated**: 2025-09-28
**Next Review**: 2025-12-28
**Document Owner**: DevOps Infrastructure Team