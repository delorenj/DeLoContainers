# Device Manager Diagnostic Checklist

## Environment Analysis Summary

**VM Configuration**: Docker-based Windows 11 VM
**USB Passthrough Devices**:
- Focusrite Scarlett 4i4 4th Gen (USB ID: 1235:821a)
- Arturia KeyLab mkII 88 (USB ID: 1c75:02cb)

## 🔍 Pre-Diagnostic System Check

### Host System Verification
- [ ] Verify KVM acceleration is enabled (`kvm-ok`)
- [ ] Check USB device visibility: `lsusb | grep -E "(1235:821a|1c75:02cb)"`
- [ ] Confirm persistent symlinks exist:
  - [ ] `/dev/focusrite_4i4` → actual USB device
  - [ ] `/dev/arturia_keylab` → actual USB device
- [ ] Verify container has privileged access
- [ ] Check QEMU arguments for USB passthrough

### Windows VM Status Check
- [ ] Access web interface at `localhost:18006`
- [ ] Connect via RDP at `localhost:13389`
- [ ] Verify Windows is fully booted and responsive
- [ ] Check if Windows has internet connectivity

## 🎛️ Device Manager Diagnostic Procedures

### Phase 1: Standard Device View
1. **Open Device Manager**
   - [ ] Right-click Start → Device Manager
   - [ ] Or run: `devmgmt.msc`

2. **Initial Device Scan**
   - [ ] Expand "Sound, video and game controllers"
   - [ ] Look for Focusrite Scarlett 4i4
   - [ ] Look for Arturia KeyLab mkII
   - [ ] Check "Universal Serial Bus controllers"
   - [ ] Note any devices with warning/error icons (yellow triangle, red X)

### Phase 2: Hidden Device Detection
1. **Enable Hidden Device View**
   - [ ] View menu → Show hidden devices
   - [ ] Check for grayed-out devices
   
2. **Environment Variable Method**
   ```cmd
   set DEVMGR_SHOW_DETAILS=1
   set DEVMGR_SHOW_NONPRESENT_DEVICES=1
   devmgmt.msc
   ```

3. **PowerShell Hidden Device Query**
   ```powershell
   Get-PnpDevice | Where-Object {$_.Status -eq "Unknown" -or $_.Status -eq "Error"}
   Get-PnpDevice | Where-Object {$_.InstanceId -like "*USB*"}
   ```

### Phase 3: USB Controller Analysis
- [ ] Expand "Universal Serial Bus controllers"
- [ ] Check for USB Root Hubs
- [ ] Verify USB 3.0/2.0 controller presence
- [ ] Look for "Unknown USB Device" entries
- [ ] Check Properties for each USB controller:
  - [ ] General tab - Device status
  - [ ] Details tab - Hardware IDs
  - [ ] Driver tab - Driver version and date

### Phase 4: Audio Device Specific Checks
- [ ] Check "Audio inputs and outputs"
- [ ] Look for "Focusrite USB Audio"
- [ ] Verify microphone and speaker entries
- [ ] Check Windows Sound Settings:
  - [ ] Right-click speaker icon → Sounds
  - [ ] Playback tab - Default device
  - [ ] Recording tab - Default device

## 🚨 Problem Identification Matrix

### Device Status Categories

#### 1. Device Not Present
- **Symptoms**: No trace in Device Manager
- **Likely Causes**:
  - USB passthrough not working
  - Host device disconnected
  - QEMU arguments incorrect
  - USB controller issues

#### 2. Unknown USB Device
- **Symptoms**: Shows as "Unknown USB Device" with error codes
- **Common Error Codes**:
  - Code 43: Hardware malfunction
  - Code 28: Driver not installed
  - Code 10: Device cannot start
  - Code 38: Driver couldn't be loaded

#### 3. Hidden/Phantom Devices
- **Symptoms**: Device appears only when "Show hidden devices" enabled
- **Characteristics**:
  - Grayed out appearance
  - May show disconnected state
  - Can interfere with new device installation

#### 4. Driver Issues
- **Symptoms**: Device present but not functioning
- **Indicators**:
  - Yellow warning triangle
  - "This device cannot start (Code 10)"
  - Driver tab shows outdated or generic driver

## 📋 Diagnostic Commands & Tools

### Windows CMD Commands
```cmd
# List all USB devices with details
pnputil /enum-devices /connected
pnputil /enum-devices /disconnected

# Show device installation logs
setupapi.dev.log location: %windir%\inf\setupapi.dev.log

# Check USB power management
powercfg /devicequery wake_armed
```

### PowerShell Diagnostics
```powershell
# Comprehensive device information
Get-PnpDevice | Select-Object FriendlyName, Status, InstanceId | Format-Table -AutoSize

# USB specific devices
Get-PnpDevice | Where-Object {$_.InstanceId -like "*USB*"} | Select-Object FriendlyName, Status, InstanceId

# Audio devices
Get-PnpDevice | Where-Object {$_.Class -eq "AudioEndpoint"} | Format-Table -AutoSize

# Driver information
Get-PnpDevice | Where-Object {$_.FriendlyName -like "*Focusrite*"} | Get-PnpDeviceProperty
```

### Registry Investigation
```cmd
# USB device history (requires admin)
reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\USB" /s

# Audio device registry
reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4d36e96c-e325-11ce-bfc1-08002be10318}" /s
```

## 🔧 Common Resolution Steps

### USB Passthrough Issues
1. **Verify Host Configuration**
   - Check container USB device mapping
   - Verify QEMU USB passthrough arguments
   - Confirm host device accessibility

2. **Windows USB Troubleshooting**
   - Run Windows USB troubleshooter
   - Disable/enable USB controllers
   - Update USB controller drivers

### Driver Resolution
1. **Manual Driver Installation**
   - Download drivers from manufacturer website
   - Use "Update driver" in Device Manager
   - Point to downloaded driver files

2. **Generic Driver Replacement**
   - Uninstall current driver
   - Scan for hardware changes
   - Install manufacturer-specific driver

### Hidden Device Cleanup
1. **Remove Phantom Devices**
   ```cmd
   # Use DevManView (Nirsoft tool) for bulk removal
   # Or manually uninstall each hidden device
   ```

2. **Registry Cleanup** (Advanced)
   - Clean USB device history
   - Remove orphaned driver entries

## 📊 Expected Results

### Healthy USB Audio Setup Should Show:
- [ ] Focusrite Scarlett 4i4 under "Sound, video and game controllers"
- [ ] Focusrite USB Audio endpoints in "Audio inputs and outputs"
- [ ] No unknown USB devices
- [ ] No error codes in device properties
- [ ] Focusrite listed as default audio device in Windows Sound settings

### Healthy MIDI Controller Setup Should Show:
- [ ] Arturia KeyLab mkII under "Sound, video and game controllers" or "Human Interface Devices"
- [ ] MIDI input/output devices recognized
- [ ] No driver conflicts

## 🚀 Next Steps After Diagnosis

1. Document findings using provided templates
2. Run USB configuration audit procedures
3. Execute driver conflict detection methodology
4. Implement recommended fixes
5. Verify with USB controller health verification process