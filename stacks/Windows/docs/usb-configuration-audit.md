# VM USB Configuration Audit Procedures

## 🎯 Audit Overview

This document provides comprehensive procedures for auditing USB passthrough configurations in Docker-based Windows VMs, specifically focusing on the Focusrite Scarlett 4i4 and Arturia KeyLab mkII audio production setup.

## 📋 Pre-Audit Preparation

### Environment Documentation
- **Container Name**: windows
- **Base Image**: dockurr/windows
- **Windows Version**: 11 Pro
- **USB Devices**: 
  - Focusrite Scarlett 4i4 4th Gen (1235:821a)
  - Arturia KeyLab mkII 88 (1c75:02cb)

### Required Tools
- Docker Compose
- lsusb utility
- QEMU monitor access
- Windows Device Manager
- PowerShell (Windows)

## 🔍 Phase 1: Host System USB Audit

### 1.1 USB Device Discovery
```bash
# List all USB devices
lsusb

# Specific device verification
lsusb | grep -i "focusrite\|arturia"
lsusb -d 1235:821a  # Focusrite
lsusb -d 1c75:02cb  # Arturia

# Detailed USB tree
lsusb -t

# Check USB device permissions
ls -la /dev/bus/usb/*/*
```

### 1.2 Persistent Device Links Audit
```bash
# Check symlink integrity
ls -la /dev/focusrite_4i4
ls -la /dev/arturia_keylab

# Verify udev rules (if custom rules exist)
ls /etc/udev/rules.d/*usb* 2>/dev/null || echo "No custom USB udev rules found"

# Check systemd device links
systemctl status systemd-udevd
```

### 1.3 Host USB Subsystem Health
```bash
# USB subsystem kernel messages
dmesg | grep -i usb | tail -20

# USB controller information
lspci | grep -i usb
lspci -v | grep -A 5 -i usb

# Check for USB resets or errors
journalctl -k | grep -i "usb\|reset" | tail -10
```

## 🐳 Phase 2: Container Configuration Audit

### 2.1 Docker Compose Analysis
```yaml
# Verify current compose.yml USB configuration
services:
  windows:
    environment:
      ARGUMENTS: "-device usb-host,vendorid=0x1235,productid=0x821a -device usb-host,vendorid=0x1c75,productid=0x02cb"
    devices:
      - /dev/focusrite_4i4
      - /dev/arturia_keylab
      - /dev/snd:/dev/snd  # ALSA audio devices
    privileged: true
    group_add:
      - audio
```

### 2.2 Container Runtime USB Verification
```bash
# Check container USB device mapping
docker exec windows ls -la /dev/ | grep -E "focusrite|arturia|snd"

# Verify QEMU process USB arguments
docker exec windows ps aux | grep qemu
docker exec windows cat /proc/$(pgrep qemu)/cmdline | tr '\0' '\n' | grep -E "device|usb"

# Container USB permissions
docker exec windows ls -la /dev/bus/usb/ 2>/dev/null || echo "USB bus not accessible in container"
```

### 2.3 QEMU Monitor USB Status
```bash
# Access QEMU monitor (if available)
docker exec -it windows socat - unix-connect:/tmp/qemu-monitor <<< "info usb"

# Alternative: Check QEMU USB device status via log
docker logs windows | grep -i "usb\|device" | tail -10
```

## 🖥️ Phase 3: Windows Guest USB Audit

### 3.1 Device Manager Comprehensive Scan
```powershell
# PowerShell device enumeration
Get-PnpDevice | Where-Object {$_.InstanceId -like "*USB*"} | 
  Select-Object FriendlyName, Status, InstanceId, Class | 
  Format-Table -AutoSize

# Specific audio device search
Get-PnpDevice | Where-Object {$_.FriendlyName -like "*Focusrite*" -or $_.FriendlyName -like "*Arturia*"}

# USB controller details
Get-PnpDevice | Where-Object {$_.Class -eq "USB"} | 
  Select-Object FriendlyName, Status, InstanceId
```

### 3.2 Windows USB Stack Analysis
```cmd
# List all USB devices with hardware IDs
pnputil /enum-devices /class USB

# Show USB device installation history
pnputil /enum-drivers | findstr /i "usb\|audio"

# USB power management settings
powercfg /devicequery wake_armed
powercfg /query SCHEME_CURRENT SUB_USBSETTINGS
```

### 3.3 Audio Subsystem Integration Check
```powershell
# Audio endpoint enumeration
Get-PnpDevice | Where-Object {$_.Class -eq "AudioEndpoint"} | Format-Table -AutoSize

# Windows Audio Service status
Get-Service | Where-Object {$_.Name -like "*audio*"}

# Audio device properties
Get-PnpDeviceProperty -InstanceId "USB\VID_1235&PID_821A*" 2>$null
```

## 📊 Phase 4: Performance & Stability Audit

### 4.1 USB Passthrough Performance Metrics
```bash
# Host USB traffic monitoring
# Install usbmon if available
sudo modprobe usbmon 2>/dev/null
ls /sys/kernel/debug/usb/usbmon/ 2>/dev/null || echo "USB monitoring not available"

# Container resource usage
docker stats windows --no-stream

# Check for USB-related errors in container
docker logs windows | grep -i "error\|fail" | grep -i usb
```

### 4.2 Audio Latency & Stability Checks
```powershell
# Windows audio glitch monitoring
# Check Event Viewer for audio service errors
Get-EventLog -LogName System | Where-Object {$_.Source -like "*Audio*"} | Select-Object -First 5

# USB selective suspend status
Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\USB" -Name "Start" 2>$null
```

### 4.3 Long-term Stability Monitoring
```bash
# Create monitoring script for USB device stability
cat > /tmp/usb_monitor.sh << 'EOF'
#!/bin/bash
while true; do
    timestamp=$(date)
    echo "[$timestamp] USB Device Check:"
    lsusb -d 1235:821a && echo "  Focusrite: OK" || echo "  Focusrite: MISSING"
    lsusb -d 1c75:02cb && echo "  Arturia: OK" || echo "  Arturia: MISSING"
    sleep 60
done
EOF
chmod +x /tmp/usb_monitor.sh
```

## 🔧 Configuration Optimization Recommendations

### 4.1 USB Passthrough Optimizations
```yaml
# Enhanced Docker Compose configuration
services:
  windows:
    environment:
      # Improved USB passthrough with error recovery
      ARGUMENTS: >-
        -device usb-host,vendorid=0x1235,productid=0x821a,id=focusrite
        -device usb-host,vendorid=0x1c75,productid=0x02cb,id=arturia
        -global kvm-pit.lost_tick_policy=discard
        -rtc base=localtime,driftfix=slew
    devices:
      - /dev/focusrite_4i4:/dev/focusrite_4i4
      - /dev/arturia_keylab:/dev/arturia_keylab
      - /dev/kvm:/dev/kvm
      - /dev/vhost-net:/dev/vhost-net  # Better network performance
    ulimits:
      memlock: -1  # Unlimited memory locking for better real-time performance
```

### 4.2 Host System USB Configuration
```bash
# Disable USB autosuspend for audio devices
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="1235", ATTR{idProduct}=="821a", ATTR{power/autosuspend}="disabled"' | \
  sudo tee /etc/udev/rules.d/90-focusrite-no-autosuspend.rules

echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="1c75", ATTR{idProduct}=="02cb", ATTR{power/autosuspend}="disabled"' | \
  sudo tee /etc/udev/rules.d/90-arturia-no-autosuspend.rules

sudo udevadm control --reload-rules
```

## 📋 Audit Checklist Summary

### ✅ Host System Verification
- [ ] USB devices detected and accessible
- [ ] Persistent symlinks functioning
- [ ] No USB subsystem errors
- [ ] Proper device permissions

### ✅ Container Configuration
- [ ] Correct USB device mapping
- [ ] QEMU arguments properly formatted
- [ ] Privileged mode enabled
- [ ] Audio group membership

### ✅ Windows Guest Status
- [ ] Devices visible in Device Manager
- [ ] No unknown USB devices
- [ ] Proper driver installation
- [ ] Audio endpoints configured

### ✅ Performance & Stability
- [ ] No USB disconnection events
- [ ] Stable audio streaming
- [ ] Low latency performance
- [ ] No resource conflicts

## 🚨 Common Issues & Solutions

### Issue 1: Device Not Detected in Windows
**Symptoms**: Device missing from Windows Device Manager
**Solutions**:
1. Verify host device connectivity: `lsusb -d VENDOR:PRODUCT`
2. Check container device mapping
3. Restart container with corrected configuration
4. Manual Windows driver installation

### Issue 2: USB Selective Suspend Interference
**Symptoms**: Intermittent device disconnections
**Solutions**:
1. Disable USB selective suspend in Windows
2. Add udev rules to prevent host autosuspend
3. Configure Windows power management settings

### Issue 3: Audio Dropouts/Glitches
**Symptoms**: Audio interruptions during playback/recording
**Solutions**:
1. Increase container memory allocation
2. Use dedicated CPU cores for container
3. Enable real-time scheduling optimizations
4. Check for USB bandwidth saturation

## 📈 Success Metrics

### Optimal Configuration Indicators:
- **Device Discovery**: < 5 seconds from container start
- **Audio Latency**: < 10ms round-trip at 48kHz
- **Stability**: 24+ hours without USB disconnection
- **CPU Usage**: < 5% for USB/audio subsystem
- **Driver Status**: All devices with manufacturer drivers loaded

## 🔄 Regular Audit Schedule

### Daily Checks:
- USB device connectivity verification
- Windows Event Log review for audio errors

### Weekly Audits:
- Full configuration verification
- Performance metrics collection
- Driver update availability check

### Monthly Reviews:
- Complete audit procedure execution
- Configuration optimization assessment
- Documentation updates

This audit procedure ensures comprehensive verification of USB passthrough functionality and helps maintain optimal performance for professional audio production workflows.