# Quick Start - Windows VM Diagnostics

## 🚀 All Files in One Place!

All diagnostic tools are now consolidated in this single directory, accessible in Windows at `\\host.lan\Data\diagnostics`

## 📁 What's Here

- **RunAllDiagnostics.bat** - Run all diagnostics with one click
- **QuickFix.bat** - Quick USB device fixes
- **FocusriteUSBFix.bat** - Focusrite-specific fixes
- **usb-conflict-detection.ps1** - Detect USB conflicts
- **usb-controller-health-check.ps1** - USB controller analysis
- **device-manager-cleanup.ps1** - Clean phantom devices
- **Install-FocusriteToolkit.ps1** - Install Focusrite drivers
- **README_DIAGNOSTICS.md** - Full documentation

## ⚡ Quick Usage

### Option 1: Run Everything
```batch
RunAllDiagnostics.bat
```

### Option 2: Individual Tools
```batch
REM Quick fixes
batch\QuickFix.bat

REM Focusrite specific
batch\FocusriteUSBFix.bat

REM PowerShell diagnostics (run as admin)
powershell -File usb-conflict-detection.ps1 -Detailed
powershell -File usb-controller-health-check.ps1 -FullReport
powershell -File device-manager-cleanup.ps1 -DryRun
```

## 📍 Access in Windows

1. Open File Explorer
2. Navigate to `\\host.lan\Data\diagnostics`
3. Right-click `RunAllDiagnostics.bat` → "Run as administrator"

## 🎯 Target Devices

- **Focusrite Scarlett 4i4 4th Gen** (USB ID: 1235:821a)
- **Arturia KeyLab mkII 88** (USB ID: 1c75:02cb)
