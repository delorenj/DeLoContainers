# Synology NAS Physical & Network Recovery Procedures

## Quick Recovery Decision Matrix

| Scenario | Data Access | Network Access | Physical Access | Recommended Method | Recovery Time |
|----------|-------------|----------------|-----------------|-------------------|---------------|
| Admin lockout | ✅ | ✅ | ✅ | Mode 1 Reset | 5-10 min |
| Network misconfiguration | ✅ | ❌ | ✅ | Mode 1 Reset + Assistant | 10-15 min |
| DSM corruption | ✅ | ✅/❌ | ✅ | Mode 2 Reset | 30-60 min |
| Complete system failure | ❌ | ❌ | ✅ | Safe Mode + Serial | 1-2 hours |
| Remote emergency | ❌ | ✅ | ❌ | SSH Emergency Access | 15-30 min |

---

## 1. RESET BUTTON PROCEDURES

### Mode 1 Reset (4 Second Reset)
**Purpose**: Network settings and admin credentials reset
**Data Impact**: ⚠️ PRESERVES ALL DATA
**Network Impact**: 🔄 RESETS TO DHCP

#### Procedure:
1. **Power State**: System must be powered ON
2. **Reset Process**:
   ```
   Press and hold RESET button for 4 seconds
   Release when you hear a BEEP
   ```
3. **LED Indicators**:
   - **Blue LED**: Solid → Blinking (reset in progress)
   - **Status LED**: Orange blinking during reset
   - **Network LED**: Off → Blinking (obtaining IP)

#### Post-Reset Configuration:
```bash
# Default credentials after Mode 1 reset
Username: admin
Password: (blank/empty)
Network: DHCP enabled
Port: 5000 (HTTP), 5001 (HTTPS)
2FA: Disabled
```

#### Timing by Model:
| Model Series | Reset Duration | Beep Pattern |
|--------------|----------------|--------------|
| DS920+, DS1520+ | 4 seconds | Single beep |
| DS218+, DS418+ | 4 seconds | Single beep |
| RS Series | 4 seconds | Double beep |
| XS/XS+ Series | 5 seconds | Triple beep |

### Mode 2 Reset (10 Second Reset)
**Purpose**: Complete DSM reinstallation
**Data Impact**: ⚠️ PRESERVES DATA VOLUMES
**System Impact**: 🔄 REINSTALLS DSM OS

#### Procedure:
1. **Power State**: System must be powered ON
2. **Reset Process**:
   ```
   Press and hold RESET button for 10 seconds
   Release when you hear 3 consecutive BEEPS
   ```
3. **LED Sequence**:
   - **0-4s**: Blue LED solid
   - **4-10s**: Blue LED blinking fast
   - **10s+**: Orange LED blinking (reinstall mode)

#### Reinstallation Process:
```bash
# Access via Synology Assistant or Web Assistant
1. Download latest DSM from Synology
2. Upload .pat file via Web Assistant
3. Follow setup wizard (30-45 minutes)
4. Data volumes will be detected and mounted
```

---

## 2. TELNET/SSH EMERGENCY ACCESS

### Enabling Emergency Telnet

#### Via Synology Assistant:
1. **Download Tools**:
   ```bash
   # Download Synology Assistant
   wget https://global.download.synology.com/download/Utility/Assistant/7.0.4-50051/Windows/synology-assistant-7.0.4-50051.exe
   ```

2. **Emergency Enable Procedure**:
   ```
   1. Open Synology Assistant
   2. Right-click on NAS device
   3. Select "Reset Password"
   4. Check "Enable SSH service"
   5. Apply changes
   ```

### SSH Emergency Access

#### Default Maintenance Credentials:
```bash
# Emergency SSH access (if enabled)
ssh admin@[NAS_IP] -p 22
Password: (use reset admin password)

# Root access (advanced recovery)
ssh root@[NAS_IP] -p 22
Password: (same as admin in emergency mode)
```

#### SSH Key Recovery:
```bash
# Regenerate SSH host keys
sudo rm /etc/ssh/ssh_host_*
sudo ssh-keygen -A
sudo systemctl restart ssh

# Reset user SSH keys
rm ~/.ssh/authorized_keys
# Re-add trusted keys manually
```

### Serial Console Connection

#### Hardware Requirements:
- **USB-to-Serial adapter** (FTDI chipset recommended)
- **Console cable** (included with some models)
- **Terminal software** (PuTTY, minicom, screen)

#### Connection Parameters:
```
Baud Rate: 115200
Data Bits: 8
Parity: None
Stop Bits: 1
Flow Control: None
```

#### Serial Access Procedure:
```bash
# Linux/macOS
screen /dev/ttyUSB0 115200

# Windows (PuTTY)
# COM port detection via Device Manager
# Set: Speed=115200, Data=8, Stop=1, Parity=None

# Boot sequence access
# Press Ctrl+C during boot to interrupt
# Access emergency shell
```

---

## 3. SAFE MODE PROCEDURES

### Triggering Safe Mode Boot

#### Method 1: Hardware Trigger
```
1. Power OFF the NAS completely
2. Hold RESET button while powering ON
3. Continue holding for 10+ seconds
4. Release when STATUS LED blinks orange rapidly
5. Wait for safe mode boot (blue LED pattern)
```

#### Method 2: Software Trigger (SSH access required)
```bash
# Create safe mode trigger file
sudo touch /tmp/synosafemode
sudo reboot
```

### Safe Mode Capabilities

#### Available Recovery Tools:
```bash
# File system check and repair
sudo fsck /dev/md0
sudo fsck /dev/md1

# Volume mounting in read-only mode
sudo mount -o ro /dev/md2 /volume1

# Database recovery
sudo /var/packages/*/scripts/start-stop-status repair

# Log analysis
sudo tail -f /var/log/messages
sudo dmesg | grep -i error
```

#### User Database Manipulation:
```bash
# Reset admin password directly
sudo sqlite3 /etc/shadow.db
> UPDATE users SET password='' WHERE name='admin';
> .quit

# Disable 2FA for all users
sudo rm -rf /usr/syno/etc/otp/*

# Reset permissions
sudo chown -R admin:users /volume1/homes/admin
```

---

## 4. NETWORK RECOVERY

### Synology Assistant Discovery

#### Network Scanning:
```bash
# Manual IP range scan
nmap -sn 192.168.1.0/24 | grep -B2 Synology

# UPnP discovery
upnpc -m eth0 -l | grep Synology

# Broadcast discovery
ping -b 192.168.1.255
arp -a | grep -i synology
```

#### Assistant Configuration:
```
1. Launch Synology Assistant
2. Click "Search" to discover devices
3. Right-click discovered NAS
4. Select "Connect" or "Web Assistant"
5. Configure network settings if needed
```

### Web Assistant Recovery Portal

#### Access Methods:
```
Primary: http://[NAS_IP]:5000
Secondary: http://[NAS_IP]:5001 (HTTPS)
Discovery: http://find.synology.com
```

#### Web Assistant Features:
- **DSM Installation**: Upload .pat files
- **Network Configuration**: Static/DHCP settings
- **Volume Detection**: Existing data recognition
- **Migration Mode**: Data preservation options

### DHCP vs Static IP Considerations

#### DHCP Recovery (Default after reset):
```bash
# Advantages:
- Automatic IP assignment
- No network configuration required
- Works with most network setups

# Disadvantages:
- IP address may change
- Requires DHCP server
- May conflict with reservations
```

#### Static IP Recovery:
```bash
# Emergency static configuration via Assistant:
IP Address: 192.168.1.100
Subnet Mask: 255.255.255.0
Gateway: 192.168.1.1
DNS: 8.8.8.8, 8.8.4.4

# Verify connectivity:
ping 192.168.1.100
telnet 192.168.1.100 5000
```

### Port Access Methods

#### Standard Ports:
```
HTTP: 5000
HTTPS: 5001
SSH: 22
Telnet: 23 (emergency only)
FTP: 21
SFTP: 22
```

#### Port Validation:
```bash
# Test port accessibility
nmap -p 5000,5001,22 [NAS_IP]
telnet [NAS_IP] 5000
curl -I http://[NAS_IP]:5000
```

---

## RECOVERY DECISION FLOWCHART

```
START: NAS Recovery Needed
│
├─ Can access data volumes?
│  ├─ YES → Can access web interface?
│  │       ├─ YES → Admin credentials issue?
│  │       │       ├─ YES → [MODE 1 RESET]
│  │       │       └─ NO → Check network/firewall
│  │       └─ NO → Network accessible?
│  │               ├─ YES → [SSH/TELNET ACCESS]
│  │               └─ NO → Physical access?
│  │                       ├─ YES → [MODE 1 RESET]
│  │                       └─ NO → [REMOTE ASSISTANCE]
│  └─ NO → Physical access available?
│          ├─ YES → System boots?
│          │       ├─ YES → [MODE 2 RESET]
│          │       └─ NO → [SAFE MODE]
│          └─ NO → Data criticality?
│                  ├─ HIGH → [PROFESSIONAL RECOVERY]
│                  └─ LOW → [REMOTE GUIDANCE]
```

## EMERGENCY CONTACT PROCEDURES

### Internal Escalation:
```bash
# Priority 1: Data integrity issues
Contact: Senior Infrastructure Team
Timeline: Immediate response required

# Priority 2: Service unavailability
Contact: Network Operations Center
Timeline: 4-hour response window

# Priority 3: Performance degradation
Contact: System Administration Team
Timeline: Next business day
```

### Vendor Support:
```bash
# Synology Technical Support
Phone: 1-425-877-6878 (24/7 for business accounts)
Email: technical@synology.com
Portal: account.synology.com

# Emergency RMA Process
Business Account: 24-48 hour replacement
Standard Account: 5-7 business days
```

## PREVENTIVE MEASURES

### Regular Maintenance:
```bash
# Weekly automated tasks
- Configuration backup export
- System health monitoring
- Network connectivity verification
- Security update installation

# Monthly procedures
- Full system backup validation
- Recovery procedure testing
- Documentation updates
- Staff training refreshers
```

### Monitoring Integration:
```bash
# Infrastructure monitoring alerts
- System temperature thresholds
- Disk health status changes
- Network connectivity issues
- Service availability drops

# Automated recovery triggers
- Service restart procedures
- Failover activation
- Backup system promotion
- Notification escalation
```

---

**Last Updated**: 2025-09-28
**Document Version**: 1.0
**Review Cycle**: Quarterly
**Owner**: DevOps Infrastructure Team