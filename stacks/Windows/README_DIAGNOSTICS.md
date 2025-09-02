# Windows VM USB Diagnostic Suite

## 🎯 Overview

This comprehensive diagnostic suite provides systematic analysis and troubleshooting tools for USB device passthrough in Docker-based Windows VMs, specifically optimized for audio production workflows with Focusrite Scarlett 4i4 and Arturia KeyLab mkII devices.

## 📁 Suite Components

### 📋 Documentation (`/docs`)

| Document | Purpose | Audience |
|----------|---------|----------|
| **device-manager-diagnostic-checklist.md** | Step-by-step Windows Device Manager diagnostics | Windows users |
| **usb-configuration-audit.md** | VM USB passthrough configuration verification | System administrators |
| **hidden-device-investigation.md** | Understanding Windows phantom devices | Technical analysts |
| **usb-passthrough-failure-modes.md** | Common failure patterns and solutions | DevOps engineers |
| **vm-guest-additions-usb-integration.md** | Guest additions impact analysis | VM specialists |

### 🔧 PowerShell Scripts (`/scripts`)

| Script | Function | Platform | Usage |
|--------|----------|----------|-------|
| **usb-conflict-detection.ps1** | Detect USB driver conflicts and phantom devices | Windows | `powershell -File usb-conflict-detection.ps1 -Detailed` |
| **usb-controller-health-check.ps1** | Comprehensive USB controller health analysis | Windows | `powershell -File usb-controller-health-check.ps1 -FullReport` |
| **device-manager-cleanup.ps1** | Clean phantom devices and driver conflicts | Windows | `powershell -File device-manager-cleanup.ps1 -DryRun` |

### 🐧 Bash Scripts (`/scripts`)

| Script | Function | Platform | Usage |
|--------|----------|----------|-------|
| **host-usb-diagnostic.sh** | Host system USB subsystem analysis | Linux | `./host-usb-diagnostic.sh` |
| **generate-diagnostic-report.sh** | Comprehensive HTML diagnostic report | Linux | `./generate-diagnostic-report.sh` |

## 🚀 Quick Start Guide

### 1. Generate Comprehensive Report
```bash
cd /home/delorenj/docker/trunk-main/stacks/Windows
./scripts/generate-diagnostic-report.sh
```
This creates an HTML report with complete system analysis.

### 2. Host System Check
```bash
./scripts/host-usb-diagnostic.sh
```
Analyzes USB subsystem on the Linux host.

### 3. Windows Guest Analysis
```powershell
# Run in Windows VM
powershell -ExecutionPolicy Bypass -File C:\path\to\usb-conflict-detection.ps1 -Detailed -Export
```

### 4. Device Manager Health Check
```powershell
# Run in Windows VM with admin privileges
powershell -ExecutionPolicy Bypass -File C:\path\to\usb-controller-health-check.ps1 -FullReport -BenchmarkMode
```

## 📊 Diagnostic Workflow

### Phase 1: System Overview
1. **Host System Check** - Verify USB devices on Linux host
2. **Container Status** - Confirm Docker container is running
3. **Basic Connectivity** - Test fundamental USB passthrough

### Phase 2: Deep Analysis
1. **Windows Device Detection** - Check Device Manager status
2. **Driver Conflict Scan** - Identify conflicting or phantom devices
3. **USB Controller Health** - Verify USB subsystem integrity
4. **Performance Analysis** - Measure latency and stability

### Phase 3: Issue Resolution
1. **Phantom Device Cleanup** - Remove problematic device entries
2. **Driver Reinstallation** - Update to latest manufacturer drivers
3. **Configuration Optimization** - Tune VM and USB settings
4. **Verification Testing** - Confirm fixes are effective

## 🎵 Audio Device Specific Checks

### Focusrite Scarlett 4i4 4th Gen
**Target USB ID**: `1235:821a`

**Host Verification:**
```bash
lsusb -d 1235:821a
ls -la /dev/focusrite_4i4
```

**Windows Verification:**
```powershell
Get-PnpDevice | Where-Object {$_.FriendlyName -like "*Focusrite*"}
```

**Expected Results:**
- Host: Device visible in lsusb, persistent symlink exists
- Windows: "Focusrite USB Audio" with status "OK"
- Device Manager: Multiple audio endpoints visible

### Arturia KeyLab mkII 88
**Target USB ID**: `1c75:02cb`

**Host Verification:**
```bash
lsusb -d 1c75:02cb
ls -la /dev/arturia_keylab
```

**Windows Verification:**
```powershell
Get-PnpDevice | Where-Object {$_.FriendlyName -like "*Arturia*"}
```

**Expected Results:**
- Host: Device visible in lsusb, persistent symlink exists
- Windows: "Arturia KeyLab mkII" with status "OK"
- Device Manager: MIDI input/output endpoints visible

## 🚨 Common Issue Resolution

### Issue: Device Not Detected in Windows
**Symptoms:** Device shows as "Unknown USB Device" or not visible

**Quick Fix:**
1. Verify host detection: `lsusb -d VENDOR:PRODUCT`
2. Restart container: `docker compose restart windows`
3. Manual driver installation in Windows

### Issue: Audio Dropouts/Glitches
**Symptoms:** Intermittent audio interruptions during production

**Quick Fix:**
1. Disable USB selective suspend in Windows
2. Check USB bandwidth utilization
3. Verify real-time priority settings

### Issue: Phantom Devices
**Symptoms:** Multiple entries for same device in Device Manager

**Quick Fix:**
1. Run device cleanup script with admin privileges
2. Remove hidden devices manually
3. Trigger hardware re-scan

## 📈 Performance Optimization

### Host System Optimizations
```bash
# Disable USB autosuspend for audio devices
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="1235", ATTR{idProduct}=="821a", ATTR{power/autosuspend}="disabled"' | sudo tee /etc/udev/rules.d/90-focusrite-no-autosuspend.rules

echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="1c75", ATTR{idProduct}=="02cb", ATTR{power/autosuspend}="disabled"' | sudo tee /etc/udev/rules.d/90-arturia-no-autosuspend.rules

sudo udevadm control --reload-rules
```

### Container Configuration
```yaml
services:
  windows:
    environment:
      ARGUMENTS: >-
        -device qemu-xhci,id=xhci,p2=8,p3=8
        -device usb-host,bus=xhci.0,vendorid=0x1235,productid=0x821a,id=focusrite
        -device usb-host,bus=xhci.0,vendorid=0x1c75,productid=0x02cb,id=arturia
        -global kvm-pit.lost_tick_policy=discard
        -rtc base=localtime,driftfix=slew
    ulimits:
      memlock: -1  # Unlimited memory locking for real-time performance
```

### Windows Guest Optimizations
```powershell
# Disable USB selective suspend
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setactive SCHEME_CURRENT

# Set audio service priority
sc config AudioSrv type= own
```

## 📋 Diagnostic Checklist

### ✅ Pre-Production Verification
- [ ] Host USB devices detected (`lsusb`)
- [ ] Persistent symlinks exist
- [ ] Container running and responsive
- [ ] Windows guest accessible
- [ ] Target devices visible in Windows Device Manager
- [ ] Manufacturer drivers installed
- [ ] No phantom/unknown devices
- [ ] Audio endpoints configured
- [ ] FL Studio recognizes devices
- [ ] MIDI controller responsive
- [ ] Audio latency < 10ms
- [ ] No USB error events in logs

### 🔄 Regular Maintenance
- [ ] Weekly: Run comprehensive diagnostic report
- [ ] Monthly: Clean phantom devices
- [ ] Quarterly: Update audio drivers
- [ ] Yearly: Review and optimize configuration

## 🆘 Emergency Troubleshooting

### Complete System Reset Procedure
1. **Stop container**: `docker compose down`
2. **Verify host devices**: `lsusb`
3. **Restart USB subsystem**: `sudo modprobe -r xhci_hcd && sudo modprobe xhci_hcd`
4. **Start container**: `docker compose up -d`
5. **Access Windows and check devices**
6. **Run cleanup scripts if needed**
7. **Reinstall drivers if necessary**

### Data Collection for Support
```bash
# Collect comprehensive diagnostic data
mkdir -p /tmp/support-data
./scripts/generate-diagnostic-report.sh
cp /tmp/windows-vm-diagnostics/* /tmp/support-data/
docker logs windows > /tmp/support-data/container.log
dmesg | grep -i usb > /tmp/support-data/kernel-usb.log
tar -czf support-data.tar.gz -C /tmp support-data/
```

## 📞 Support Resources

### Internal Documentation
- **Device Manager Guide**: See `docs/device-manager-diagnostic-checklist.md`
- **Configuration Audit**: See `docs/usb-configuration-audit.md`
- **Advanced Troubleshooting**: See `docs/usb-passthrough-failure-modes.md`

### External Resources
- **Focusrite Support**: https://support.focusrite.com/
- **Arturia Support**: https://www.arturia.com/support
- **QEMU USB Documentation**: https://qemu.readthedocs.io/en/latest/system/devices/usb.html
- **Docker USB Passthrough**: https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities

### Success Metrics
- **Device Detection**: < 10 seconds from container start
- **Audio Latency**: < 10ms buffer achievable
- **System Stability**: 24+ hours without disconnection
- **MIDI Responsiveness**: < 1ms input lag
- **CPU Overhead**: < 5% for USB/audio subsystem

This diagnostic suite ensures reliable, professional-grade USB audio device integration in virtualized Windows environments.