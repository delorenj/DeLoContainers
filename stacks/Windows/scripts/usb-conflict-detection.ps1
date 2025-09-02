# USB Driver Conflict Detection PowerShell Script
# Part of Windows VM Device Manager Diagnostic Suite
# Detects USB driver conflicts, phantom devices, and configuration issues

[CmdletBinding()]
param(
    [switch]$Detailed,
    [switch]$Export,
    [string]$OutputPath = "C:\Temp\usb-diagnostics.csv"
)

Write-Host "=== USB Driver Conflict Detection Tool ===" -ForegroundColor Cyan
Write-Host "Analyzing USB device configuration and potential conflicts..." -ForegroundColor Yellow
Write-Host ""

# Create diagnostic results array
$DiagnosticResults = @()

# Function to add diagnostic entry
function Add-DiagnosticEntry {
    param(
        [string]$Category,
        [string]$Device,
        [string]$Status,
        [string]$Issue,
        [string]$Recommendation
    )
    
    $script:DiagnosticResults += [PSCustomObject]@{
        Category = $Category
        Device = $Device
        Status = $Status
        Issue = $Issue
        Recommendation = $Recommendation
        Timestamp = Get-Date
    }
}

# 1. DETECT PROBLEM DEVICES
Write-Host "1. Scanning for Problem Devices..." -ForegroundColor Green

$ProblemDevices = Get-PnpDevice | Where-Object { 
    $_.Status -eq "Error" -or $_.Status -eq "Degraded" -or $_.Status -eq "Unknown" 
}

if ($ProblemDevices) {
    Write-Host "   Found $($ProblemDevices.Count) devices with issues:" -ForegroundColor Red
    foreach ($device in $ProblemDevices) {
        Write-Host "   - $($device.FriendlyName): $($device.Status)" -ForegroundColor Red
        Add-DiagnosticEntry -Category "Problem Device" -Device $device.FriendlyName -Status $device.Status -Issue "Device in error state" -Recommendation "Check Device Manager for error codes and reinstall drivers"
    }
} else {
    Write-Host "   No problem devices found." -ForegroundColor Green
}

# 2. DETECT USB-SPECIFIC ISSUES
Write-Host "`n2. Analyzing USB Subsystem..." -ForegroundColor Green

$USBDevices = Get-PnpDevice | Where-Object { $_.InstanceId -like "*USB*" }
$USBControllers = Get-PnpDevice | Where-Object { $_.Class -eq "USB" }

Write-Host "   Total USB devices: $($USBDevices.Count)"
Write-Host "   USB controllers: $($USBControllers.Count)"

# Check for unknown USB devices
$UnknownUSB = $USBDevices | Where-Object { 
    $_.FriendlyName -like "*Unknown*" -or $_.Status -eq "Unknown" 
}

if ($UnknownUSB) {
    Write-Host "   Found $($UnknownUSB.Count) unknown USB devices:" -ForegroundColor Red
    foreach ($device in $UnknownUSB) {
        Write-Host "   - $($device.FriendlyName)" -ForegroundColor Red
        Add-DiagnosticEntry -Category "Unknown USB Device" -Device $device.FriendlyName -Status $device.Status -Issue "Device not properly identified" -Recommendation "Install appropriate drivers or check USB connection"
    }
}

# 3. AUDIO DEVICE SPECIFIC ANALYSIS
Write-Host "`n3. Audio Device Analysis..." -ForegroundColor Green

$AudioDevices = Get-PnpDevice | Where-Object { 
    $_.Class -eq "AudioEndpoint" -or $_.Class -eq "MEDIA" -or 
    $_.FriendlyName -like "*Focusrite*" -or $_.FriendlyName -like "*Arturia*" -or
    $_.FriendlyName -like "*Audio*" -or $_.FriendlyName -like "*Sound*"
}

Write-Host "   Found $($AudioDevices.Count) audio-related devices"

# Check for missing expected devices
$FocusriteDevice = $AudioDevices | Where-Object { $_.FriendlyName -like "*Focusrite*" }
$ArturiaDevice = $AudioDevices | Where-Object { $_.FriendlyName -like "*Arturia*" }

if (-not $FocusriteDevice) {
    Write-Host "   WARNING: Focusrite Scarlett 4i4 not detected" -ForegroundColor Yellow
    Add-DiagnosticEntry -Category "Missing Device" -Device "Focusrite Scarlett 4i4" -Status "Not Found" -Issue "Expected audio interface not present" -Recommendation "Check USB passthrough configuration and device connectivity"
} else {
    Write-Host "   ✓ Focusrite device found: $($FocusriteDevice.FriendlyName)" -ForegroundColor Green
}

if (-not $ArturiaDevice) {
    Write-Host "   WARNING: Arturia KeyLab mkII not detected" -ForegroundColor Yellow
    Add-DiagnosticEntry -Category "Missing Device" -Device "Arturia KeyLab mkII" -Status "Not Found" -Issue "Expected MIDI controller not present" -Recommendation "Check USB passthrough configuration and device connectivity"
} else {
    Write-Host "   ✓ Arturia device found: $($ArturiaDevice.FriendlyName)" -ForegroundColor Green
}

# 4. DRIVER CONFLICT ANALYSIS
Write-Host "`n4. Driver Conflict Analysis..." -ForegroundColor Green

$ConflictingDrivers = @()

# Check for duplicate audio endpoints
$AudioEndpoints = Get-PnpDevice | Where-Object { $_.Class -eq "AudioEndpoint" }
$GroupedEndpoints = $AudioEndpoints | Group-Object FriendlyName | Where-Object { $_.Count -gt 1 }

if ($GroupedEndpoints) {
    Write-Host "   Found duplicate audio endpoints:" -ForegroundColor Yellow
    foreach ($group in $GroupedEndpoints) {
        Write-Host "   - Duplicate: $($group.Name) ($($group.Count) instances)" -ForegroundColor Yellow
        Add-DiagnosticEntry -Category "Driver Conflict" -Device $group.Name -Status "Duplicate" -Issue "Multiple instances of same audio endpoint" -Recommendation "Remove phantom devices and reinstall audio drivers"
    }
}

# Check for generic vs specific drivers
$GenericDrivers = Get-PnpDevice | Where-Object { 
    $_.InstanceId -like "*USB*" -and (
        $_.FriendlyName -like "*Generic*" -or 
        $_.FriendlyName -like "*Standard*" -or
        $_.FriendlyName -like "*Microsoft*"
    )
} | Where-Object { $_.Class -eq "MEDIA" -or $_.Class -eq "AudioEndpoint" }

if ($GenericDrivers) {
    Write-Host "   Found devices using generic drivers:" -ForegroundColor Yellow
    foreach ($device in $GenericDrivers) {
        Write-Host "   - $($device.FriendlyName)" -ForegroundColor Yellow
        Add-DiagnosticEntry -Category "Generic Driver" -Device $device.FriendlyName -Status "Generic" -Issue "Using generic instead of manufacturer driver" -Recommendation "Install manufacturer-specific drivers for optimal performance"
    }
}

# 5. USB POWER MANAGEMENT ISSUES
Write-Host "`n5. USB Power Management Analysis..." -ForegroundColor Green

try {
    $USBPowerSettings = Get-CimInstance -ClassName MSPower_DeviceWakeEnable -Namespace root/wmi -ErrorAction SilentlyContinue
    if ($USBPowerSettings) {
        $WakeEnabledUSB = $USBPowerSettings | Where-Object { $_.Enable -eq $true }
        Write-Host "   USB devices with wake capability: $($WakeEnabledUSB.Count)"
    }
    
    # Check USB selective suspend settings
    $USBSelectiveSuspend = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\USB" -Name "DisableSelectiveSuspend" -ErrorAction SilentlyContinue
    if ($USBSelectiveSuspend) {
        if ($USBSelectiveSuspend.DisableSelectiveSuspend -eq 1) {
            Write-Host "   ✓ USB Selective Suspend is disabled" -ForegroundColor Green
        } else {
            Write-Host "   WARNING: USB Selective Suspend is enabled (may cause audio dropouts)" -ForegroundColor Yellow
            Add-DiagnosticEntry -Category "Power Management" -Device "USB Subsystem" -Status "Selective Suspend Enabled" -Issue "USB power management may cause device disconnections" -Recommendation "Disable USB selective suspend for audio production"
        }
    }
} catch {
    Write-Host "   Could not analyze power management settings" -ForegroundColor Yellow
}

# 6. REGISTRY ANALYSIS FOR USB DEVICE HISTORY
Write-Host "`n6. USB Device History Analysis..." -ForegroundColor Green

try {
    $USBStorageHistory = Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR" -ErrorAction SilentlyContinue
    if ($USBStorageHistory) {
        Write-Host "   USB storage device history entries: $($USBStorageHistory.Count)"
    }
    
    # Check for our specific devices in USB history
    $USBHistory = Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\USB" -ErrorAction SilentlyContinue
    if ($USBHistory) {
        $FocusriteHistory = $USBHistory | Where-Object { $_.Name -like "*VID_1235*PID_821A*" }
        $ArturiaHistory = $USBHistory | Where-Object { $_.Name -like "*VID_1C75*PID_02CB*" }
        
        if ($FocusriteHistory) {
            Write-Host "   ✓ Focusrite device found in USB history" -ForegroundColor Green
        } else {
            Write-Host "   WARNING: No Focusrite device history found" -ForegroundColor Yellow
            Add-DiagnosticEntry -Category "Device History" -Device "Focusrite Scarlett 4i4" -Status "No History" -Issue "Device may never have been properly installed" -Recommendation "Check USB passthrough and reinstall drivers"
        }
        
        if ($ArturiaHistory) {
            Write-Host "   ✓ Arturia device found in USB history" -ForegroundColor Green
        } else {
            Write-Host "   WARNING: No Arturia device history found" -ForegroundColor Yellow
            Add-DiagnosticEntry -Category "Device History" -Device "Arturia KeyLab mkII" -Status "No History" -Issue "Device may never have been properly installed" -Recommendation "Check USB passthrough and reinstall drivers"
        }
    }
} catch {
    Write-Host "   Could not analyze USB device history" -ForegroundColor Yellow
}

# 7. DETAILED DEVICE PROPERTIES (if requested)
if ($Detailed) {
    Write-Host "`n7. Detailed Device Properties..." -ForegroundColor Green
    
    $ImportantDevices = Get-PnpDevice | Where-Object { 
        $_.FriendlyName -like "*Focusrite*" -or 
        $_.FriendlyName -like "*Arturia*" -or
        ($_.InstanceId -like "*USB*" -and $_.Status -ne "OK")
    }
    
    foreach ($device in $ImportantDevices) {
        Write-Host "`n   Device: $($device.FriendlyName)" -ForegroundColor Cyan
        Write-Host "     Status: $($device.Status)"
        Write-Host "     Class: $($device.Class)"
        Write-Host "     Instance ID: $($device.InstanceId)"
        
        try {
            $DeviceProperties = Get-PnpDeviceProperty -InstanceId $device.InstanceId -ErrorAction SilentlyContinue
            $HardwareIDs = ($DeviceProperties | Where-Object { $_.KeyName -eq "DEVPKEY_Device_HardwareIds" }).Data
            if ($HardwareIDs) {
                Write-Host "     Hardware IDs: $($HardwareIDs -join ', ')"
            }
        } catch {
            Write-Host "     Could not retrieve device properties"
        }
    }
}

# 8. SUMMARY AND RECOMMENDATIONS
Write-Host "`n=== DIAGNOSTIC SUMMARY ===" -ForegroundColor Cyan

$TotalIssues = $DiagnosticResults.Count
Write-Host "Total issues detected: $TotalIssues" -ForegroundColor $(if ($TotalIssues -eq 0) { "Green" } elseif ($TotalIssues -lt 5) { "Yellow" } else { "Red" })

if ($TotalIssues -gt 0) {
    Write-Host "`nIssue Breakdown:" -ForegroundColor White
    $DiagnosticResults | Group-Object Category | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Count) issues" -ForegroundColor Yellow
    }
    
    Write-Host "`nTop Recommendations:" -ForegroundColor White
    $DiagnosticResults | Select-Object -First 5 | ForEach-Object {
        Write-Host "  • $($_.Device): $($_.Recommendation)" -ForegroundColor Gray
    }
} else {
    Write-Host "No significant issues detected. USB configuration appears healthy." -ForegroundColor Green
}

# 9. EXPORT RESULTS (if requested)
if ($Export -or $DiagnosticResults.Count -gt 0) {
    $ExportPath = $OutputPath
    try {
        # Create directory if it doesn't exist
        $ExportDir = Split-Path $ExportPath -Parent
        if (-not (Test-Path $ExportDir)) {
            New-Item -ItemType Directory -Path $ExportDir -Force | Out-Null
        }
        
        $DiagnosticResults | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
        Write-Host "`nDiagnostic results exported to: $ExportPath" -ForegroundColor Green
        
        # Also create a summary text file
        $SummaryPath = $ExportPath -replace '\.csv$', '-summary.txt'
        @"
USB Driver Conflict Detection Report
Generated: $(Get-Date)
Computer: $env:COMPUTERNAME

=== SUMMARY ===
Total Issues: $TotalIssues
Categories: $($DiagnosticResults | Group-Object Category | ForEach-Object { "$($_.Name) ($($_.Count))" }) -join ", ")

=== DETAILED RESULTS ===
$($DiagnosticResults | ForEach-Object { 
    "[$($_.Category)] $($_.Device)"
    "  Status: $($_.Status)"
    "  Issue: $($_.Issue)" 
    "  Recommendation: $($_.Recommendation)"
    "  Time: $($_.Timestamp)"
    ""
} | Out-String)
"@ | Out-File -FilePath $SummaryPath -Encoding UTF8
        
        Write-Host "Summary report exported to: $SummaryPath" -ForegroundColor Green
    } catch {
        Write-Host "Failed to export results: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nDiagnostic scan completed." -ForegroundColor Cyan
Write-Host "Run with -Detailed flag for more verbose output." -ForegroundColor Gray
Write-Host "Run with -Export flag to save results to CSV file." -ForegroundColor Gray