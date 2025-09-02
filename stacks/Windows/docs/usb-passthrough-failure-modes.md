# USB Passthrough Failure Modes Analysis

## 🎯 Overview

This document analyzes common USB passthrough failure modes in Docker-based Windows VMs, specifically focusing on audio production hardware (Focusrite Scarlett 4i4 and Arturia KeyLab mkII) and provides diagnostic and resolution strategies.

## 🏗️ USB Passthrough Architecture

### Layer Stack
```
┌─────────────────────────────────────┐
│ Windows VM (Guest OS)              │
│ ├── Device Manager                  │
│ ├── USB Drivers                     │
│ └── Application Layer               │
├─────────────────────────────────────┤
│ QEMU/KVM Virtualization Layer      │
│ ├── USB Host Controller Emulation  │
│ ├── USB Device Passthrough         │
│ └── Virtual USB Hub Management     │
├─────────────────────────────────────┤
│ Docker Container Runtime           │
│ ├── Device Mapping                  │
│ ├── Privilege Escalation           │
│ └── Resource Allocation            │
├─────────────────────────────────────┤
│ Host Linux System                  │
│ ├── USB Subsystem                   │
│ ├── udev Device Management         │
│ └── Physical USB Controllers       │
└─────────────────────────────────────┘
```

## 🚨 Failure Mode Categories

### 1. Host-Level Failures

#### 1.1 Physical Device Issues
**Symptoms:**
- Device not detected by `lsusb`
- Intermittent connections
- USB errors in `dmesg`

**Root Causes:**
```bash
# Check USB subsystem errors
dmesg | grep -i "usb\|reset" | tail -10

# Common error patterns:
# - "device descriptor read/64, error -110"
# - "USB disconnect, address X"
# - "device not accepting address X"
```

**Diagnostic Commands:**
```bash
# Device visibility check
lsusb -d 1235:821a  # Focusrite
lsusb -d 1c75:02cb  # Arturia

# Detailed USB tree
lsusb -t

# USB controller status
lspci | grep -i usb
dmesg | grep -i "usb controller" | tail -5
```

#### 1.2 USB Power Management Issues
**Symptoms:**
- Devices disconnect after idle period
- Inconsistent device detection
- Power-related USB errors

**Root Causes:**
- USB autosuspend enabled
- Insufficient power delivery
- Power management conflicts

**Detection:**
```bash
# Check autosuspend settings
cat /sys/bus/usb/devices/*/power/autosuspend 2>/dev/null

# Power management settings
cat /sys/bus/usb/devices/*/power/control 2>/dev/null
```

#### 1.3 USB Bandwidth Saturation
**Symptoms:**
- Multiple devices competing for bandwidth
- Audio dropouts under load
- USB transfer errors

**Analysis:**
```bash
# USB bandwidth analysis
lsusb -v | grep -E "MaxPower|bMaxPower"

# USB 2.0 controller load (480 Mbps total)
# USB 3.0 controller load (5 Gbps total)
```

### 2. Container-Level Failures

#### 2.1 Device Mapping Failures
**Configuration Issues:**
```yaml
# INCORRECT - Missing device mapping
services:
  windows:
    environment:
      ARGUMENTS: "-device usb-host,vendorid=0x1235,productid=0x821a"
    # Missing: devices section

# CORRECT - Proper device mapping
services:
  windows:
    environment:
      ARGUMENTS: "-device usb-host,vendorid=0x1235,productid=0x821a"
    devices:
      - /dev/focusrite_4i4:/dev/focusrite_4i4
    privileged: true
```

**Diagnostic Steps:**
```bash
# Check container device access
docker exec windows ls -la /dev/focusrite_4i4
docker exec windows ls -la /dev/arturia_keylab

# Verify QEMU arguments
docker exec windows ps aux | grep qemu
docker exec windows cat /proc/$(pgrep qemu)/cmdline | tr '\0' '\n'
```

#### 2.2 Privilege and Permission Issues
**Symptoms:**
- "Permission denied" errors
- QEMU unable to access USB devices
- Container fails to start

**Root Causes:**
- Missing `privileged: true`
- Incorrect device permissions
- Missing group membership

**Resolution:**
```yaml
services:
  windows:
    privileged: true  # Required for USB passthrough
    group_add:
      - audio        # Audio device access
    devices:
      - /dev/kvm:/dev/kvm           # KVM acceleration
      - /dev/focusrite_4i4          # Audio interface
      - /dev/arturia_keylab         # MIDI controller
```

#### 2.3 Resource Allocation Issues
**Symptoms:**
- Container OOM kills
- USB device instability
- Performance degradation

**Monitoring:**
```bash
# Container resource usage
docker stats windows --no-stream

# Memory usage analysis
docker exec windows cat /proc/meminfo

# CPU usage patterns
docker exec windows top -b -n1
```

### 3. QEMU/KVM Level Failures

#### 3.1 USB Controller Emulation Issues
**Symptoms:**
- USB devices not detected in Windows
- Generic "Unknown USB Device" entries
- USB controller driver issues

**QEMU Configuration Problems:**
```yaml
# PROBLEMATIC - Incorrect USB controller
environment:
  ARGUMENTS: "-usb -device usb-tablet"

# IMPROVED - Proper USB 3.0 controller
environment:
  ARGUMENTS: "-device qemu-xhci,id=usb,bus=pcie.0,addr=0x1b -device usb-host,bus=usb.0,vendorid=0x1235,productid=0x821a"
```

#### 3.2 USB Device ID Conflicts
**Symptoms:**
- Device detected but not functioning
- Windows shows error code 43
- Inconsistent device behavior

**Analysis:**
```bash
# Check for USB ID conflicts
docker exec windows lsusb
# Compare with host system
lsusb

# Verify vendor/product IDs
lsusb -d 1235:821a -v  # Detailed device info
```

#### 3.3 Virtual USB Hub Limitations
**Symptoms:**
- Limited number of USB devices
- Hub enumeration failures
- Device connection timeouts

**Configuration:**
```yaml
# Enhanced USB hub configuration
environment:
  ARGUMENTS: >-
    -device qemu-xhci,id=xhci 
    -device usb-host,bus=xhci.0,vendorid=0x1235,productid=0x821a,id=focusrite
    -device usb-host,bus=xhci.0,vendorid=0x1c75,productid=0x02cb,id=arturia
```

### 4. Windows Guest-Level Failures

#### 4.1 Driver Installation Failures
**Symptoms:**
- Unknown USB devices in Device Manager
- Audio devices not functional
- Error codes in device properties

**Common Error Codes:**
- **Code 28**: Drivers not installed
- **Code 43**: Device malfunction
- **Code 10**: Device cannot start
- **Code 45**: Currently not connected

**Resolution Strategy:**
```powershell
# Windows device analysis
Get-PnpDevice | Where-Object {$_.Status -ne "OK"}

# Driver installation status
pnputil /enum-devices /connected

# Force driver update
Update-PnpDevice -InstanceId "USB\VID_1235&PID_821A\SERIAL"
```

#### 4.2 USB Selective Suspend Issues
**Symptoms:**
- Intermittent device disconnections
- Audio dropouts during production
- Devices "disappearing" after idle time

**Detection and Resolution:**
```powershell
# Check selective suspend status
Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\USB" -Name "DisableSelectiveSuspend"

# Disable selective suspend
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\USB" -Name "DisableSelectiveSuspend" -Value 1 -PropertyType DWORD
```

#### 4.3 Audio Subsystem Conflicts
**Symptoms:**
- Multiple audio endpoints for same device
- Default audio device changes unexpectedly
- Audio applications unable to access hardware

**Analysis:**
```powershell
# Audio endpoint enumeration
Get-PnpDevice | Where-Object {$_.Class -eq "AudioEndpoint"}

# Audio service status
Get-Service | Where-Object {$_.Name -like "*audio*"}
```

### 5. Application-Level Failures

#### 5.1 FL Studio Integration Issues
**Symptoms:**
- FL Studio cannot detect Focusrite ASIO driver
- Audio latency issues
- MIDI controller not responsive

**Configuration Checks:**
1. Focusrite Control software installation
2. ASIO driver proper installation
3. FL Studio audio settings configuration
4. MIDI device recognition in FL Studio

#### 5.2 VST Plugin Access Issues
**Symptoms:**
- VST plugins not loading
- Plugin authorization failures
- Performance degradation with plugins

**Resolution:**
- Verify VST directory mapping: `\\host.lan\Data\vst`
- Check plugin file permissions
- Validate plugin compatibility with Windows VM

## 🔧 Diagnostic Workflows

### Systematic Failure Diagnosis

#### Workflow 1: Bottom-Up Analysis
```bash
# Step 1: Host system verification
echo "=== Host System Check ==="
lsusb -d 1235:821a && echo "Focusrite: OK" || echo "Focusrite: MISSING"
lsusb -d 1c75:02cb && echo "Arturia: OK" || echo "Arturia: MISSING"

# Step 2: Container configuration check
echo "=== Container Check ==="
docker exec windows ls -la /dev/focusrite_4i4 2>/dev/null && echo "Device mapped: OK" || echo "Device mapping: FAILED"

# Step 3: QEMU process verification
echo "=== QEMU Check ==="
docker exec windows pgrep qemu > /dev/null && echo "QEMU running: OK" || echo "QEMU: NOT RUNNING"

# Step 4: Windows guest verification
echo "=== Windows Guest Check ==="
docker exec windows powershell "Get-PnpDevice | Where-Object {\$_.FriendlyName -like '*Focusrite*'}" | grep -q "OK" && echo "Windows detection: OK" || echo "Windows detection: FAILED"
```

#### Workflow 2: Top-Down Analysis
```powershell
# Start from Windows application layer
# Step 1: Application detection
# Check FL Studio, test MIDI in applications

# Step 2: Windows device status
Get-PnpDevice | Where-Object {$_.FriendlyName -like "*Focusrite*" -or $_.FriendlyName -like "*Arturia*"}

# Step 3: Driver analysis
pnputil /enum-devices | findstr /i "focusrite\|arturia"

# Step 4: USB subsystem check
Get-PnpDevice | Where-Object {$_.Class -eq "USB"}
```

### Automated Failure Detection

#### Host-Side Monitoring Script
```bash
#!/bin/bash
# usb-monitor.sh - Continuous USB device monitoring

LOG_FILE="/var/log/usb-passthrough-monitor.log"

log_message() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

check_devices() {
    local focusrite_present=$(lsusb -d 1235:821a | wc -l)
    local arturia_present=$(lsusb -d 1c75:02cb | wc -l)
    
    if [ "$focusrite_present" -eq 0 ]; then
        log_message "WARNING: Focusrite Scarlett 4i4 not detected on host"
        return 1
    fi
    
    if [ "$arturia_present" -eq 0 ]; then
        log_message "WARNING: Arturia KeyLab mkII not detected on host"
        return 1
    fi
    
    return 0
}

check_container() {
    if ! docker exec windows ls -la /dev/focusrite_4i4 &>/dev/null; then
        log_message "ERROR: Focusrite device not mapped in container"
        return 1
    fi
    
    if ! docker exec windows ls -la /dev/arturia_keylab &>/dev/null; then
        log_message "ERROR: Arturia device not mapped in container"
        return 1
    fi
    
    return 0
}

while true; do
    if check_devices && check_container; then
        log_message "INFO: All USB devices present and accessible"
    else
        log_message "ERROR: USB device issues detected"
        # Trigger alerting/remediation here
    fi
    sleep 30
done
```

## 🛠️ Resolution Strategies

### Quick Fix Checklist

#### Immediate Actions (< 5 minutes)
1. **Physical Connection Check**
   ```bash
   # Unplug and reconnect USB devices
   # Check different USB ports
   # Verify cable integrity
   ```

2. **Container Restart**
   ```bash
   cd /home/delorenj/docker/trunk-main/stacks/Windows
   docker compose down
   docker compose up -d
   ```

3. **Host USB Subsystem Reset**
   ```bash
   # Reset USB controllers (requires root)
   sudo modprobe -r xhci_hcd
   sudo modprobe xhci_hcd
   ```

#### Intermediate Solutions (5-30 minutes)

1. **Configuration Verification**
   ```yaml
   # Ensure proper Docker compose configuration
   services:
     windows:
       image: dockurr/windows
       environment:
         ARGUMENTS: "-device usb-host,vendorid=0x1235,productid=0x821a -device usb-host,vendorid=0x1c75,productid=0x02cb"
       devices:
         - /dev/focusrite_4i4:/dev/focusrite_4i4
         - /dev/arturia_keylab:/dev/arturia_keylab
       privileged: true
   ```

2. **Windows Driver Reinstallation**
   ```powershell
   # Remove problematic devices
   Get-PnpDevice | Where-Object {$_.Status -ne "OK"} | Remove-PnpDevice -Confirm:$false
   
   # Trigger hardware scan
   pnputil /scan-devices
   ```

#### Advanced Solutions (30+ minutes)

1. **QEMU USB Configuration Optimization**
   ```yaml
   environment:
     ARGUMENTS: >-
       -device qemu-xhci,id=xhci,p2=8,p3=8
       -device usb-host,bus=xhci.0,vendorid=0x1235,productid=0x821a,id=focusrite
       -device usb-host,bus=xhci.0,vendorid=0x1c75,productid=0x02cb,id=arturia
       -global kvm-pit.lost_tick_policy=discard
       -rtc base=localtime,driftfix=slew
   ```

2. **Host System USB Optimization**
   ```bash
   # Disable USB autosuspend for audio devices
   echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="1235", ATTR{idProduct}=="821a", ATTR{power/autosuspend}="disabled"' | sudo tee /etc/udev/rules.d/90-focusrite-no-autosuspend.rules
   
   echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="1c75", ATTR{idProduct}=="02cb", ATTR{power/autosuspend}="disabled"' | sudo tee /etc/udev/rules.d/90-arturia-no-autosuspend.rules
   
   sudo udevadm control --reload-rules
   sudo udevadm trigger
   ```

3. **Windows System Optimization**
   ```powershell
   # Disable USB selective suspend
   powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
   powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
   powercfg /setactive SCHEME_CURRENT
   
   # Optimize audio service priority
   sc config AudioSrv type= own
   ```

## 📊 Success Metrics

### Health Indicators
- **Device Detection**: < 10 seconds from container start
- **Audio Latency**: < 10ms buffer size achievable
- **Stability**: 24+ hours without disconnection
- **MIDI Responsiveness**: < 1ms MIDI input lag

### Monitoring KPIs
- **Uptime**: Percentage of time devices are functional
- **MTBF**: Mean time between USB failures
- **Recovery Time**: Time to restore functionality after failure
- **Error Rate**: USB errors per hour of operation

This comprehensive failure mode analysis provides the foundation for reliable USB passthrough in audio production environments.