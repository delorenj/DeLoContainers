# =============================================================================
# Fix-FocusriteUSB.ps1
# Main troubleshooting script for Focusrite 4i4 USB issues
# Author: Hive Mind Coder Agent
# Version: 1.0.0
# =============================================================================

#Requires -Version 5.1
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Quick", "Full", "Diagnostic", "Reset", "Power", "VM")]
    [string]$Mode = "Full",
    
    [Parameter(Mandatory = $false)]
    [switch]$AutoFix = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$Verbose = $false,
    
    [Parameter(Mandatory = $false)]
    [string]$LogFile = "$env:TEMP\FocusriteUSBFix.log"
)

# Import the toolkit module
$ModulePath = Join-Path $PSScriptRoot "FocusriteUSBToolkit.psm1"
if (Test-Path $ModulePath) {
    Import-Module $ModulePath -Force
} else {
    Write-Error "FocusriteUSBToolkit.psm1 not found at: $ModulePath"
    exit 1
}

# Set log path
$Global:LogPath = $LogFile

function Show-Banner {
    Write-Host @"
╔═══════════════════════════════════════════════════════════════════════════════╗
║                          FOCUSRITE USB TROUBLESHOOTER                        ║
║                              Version 1.0.0                                   ║
║                                                                              ║
║  Automated toolkit for resolving Focusrite Scarlett 4i4 USB passthrough     ║
║  issues in Windows VMs                                                       ║
╚═══════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

    Write-Host ""
    Write-Host "Mode: $Mode" -ForegroundColor Yellow
    Write-Host "Auto-fix: $AutoFix" -ForegroundColor Yellow
    Write-Host "Log file: $LogFile" -ForegroundColor Yellow
    Write-Host ""
}

function Show-DeviceStatus {
    param($TestResults)
    
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "DEVICE STATUS REPORT" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    $statusColor = switch ($TestResults.OverallHealth) {
        "Good" { "Green" }
        "Fair" { "Yellow" }
        "Poor" { "Red" }
        default { "White" }
    }
    
    Write-Host "Overall Health: $($TestResults.OverallHealth)" -ForegroundColor $statusColor
    Write-Host "Devices Detected: $($TestResults.DevicesDetected)"
    Write-Host "Working Devices: $($TestResults.WorkingDevices)" -ForegroundColor Green
    Write-Host "Problematic Devices: $($TestResults.ProblematicDevices)" -ForegroundColor Red
    Write-Host "Hidden Devices: $($TestResults.HiddenDevices)" -ForegroundColor Yellow
    Write-Host ""
}

function Show-TroubleshootingResults {
    param($Results)
    
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "TROUBLESHOOTING RESULTS" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    Write-Host "Devices Found: $($Results.DevicesFound)"
    Write-Host "Devices Reset: $($Results.DevicesReset)"
    Write-Host "Hidden Devices Removed: $($Results.HiddenDevicesRemoved)"
    Write-Host "Drivers Updated: $($Results.DriversUpdated)"
    Write-Host "Power Optimized: $($Results.PowerOptimized)"
    Write-Host "VM Optimized: $($Results.VMOptimized)"
    
    $overallColor = if ($Results.OverallSuccess) { "Green" } else { "Red" }
    $overallStatus = if ($Results.OverallSuccess) { "SUCCESS" } else { "PARTIAL/FAILED" }
    Write-Host "Overall Result: $overallStatus" -ForegroundColor $overallColor
    Write-Host ""
}

function Invoke-QuickMode {
    Write-ToolkitLog "Running Quick Mode..." "SUCCESS"
    
    # Test connection
    $testResults = Test-FocusriteConnection
    Show-DeviceStatus $testResults
    
    if ($testResults.OverallHealth -eq "Good") {
        Write-ToolkitLog "Quick test passed. No issues detected." "SUCCESS"
        return $true
    }
    
    # Quick fixes
    Write-ToolkitLog "Issues detected. Running quick fixes..."
    
    # Reset USB devices
    $devices = Get-FocusriteDevices
    foreach ($device in $devices) {
        if ($device.Status -ne "OK") {
            Reset-USBDevice -InstanceId $device.InstanceId
        }
    }
    
    # Test again
    Start-Sleep -Seconds 5
    $finalTest = Test-FocusriteConnection
    Show-DeviceStatus $finalTest
    
    return ($finalTest.OverallHealth -ne "Poor")
}

function Invoke-DiagnosticMode {
    Write-ToolkitLog "Running Diagnostic Mode..." "SUCCESS"
    
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "COMPREHENSIVE DIAGNOSTIC REPORT" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    # Device detection
    Write-Host "[1/6] Device Detection" -ForegroundColor Yellow
    $devices = Get-FocusriteDevices
    $devices | Format-Table -AutoSize
    
    # Hidden devices
    Write-Host "[2/6] Hidden Device Scan" -ForegroundColor Yellow
    $hiddenDevices = Get-HiddenUSBDevices
    if ($hiddenDevices.Count -gt 0) {
        $hiddenDevices | Format-Table -AutoSize
    } else {
        Write-Host "No hidden devices found" -ForegroundColor Green
    }
    
    # USB Controllers
    Write-Host "[3/6] USB Controller Status" -ForegroundColor Yellow
    Get-CimInstance -ClassName Win32_USBController | 
        Select-Object Name, Status, ConfigManagerErrorCode | 
        Format-Table -AutoSize
    
    # Audio devices
    Write-Host "[4/6] Audio Device Status" -ForegroundColor Yellow
    Get-CimInstance -ClassName Win32_SoundDevice | 
        Where-Object { $_.Name -like "*Focusrite*" -or $_.Name -like "*Scarlett*" } |
        Select-Object Name, Status, ConfigManagerErrorCode |
        Format-Table -AutoSize
    
    # Power settings
    Write-Host "[5/6] USB Power Settings" -ForegroundColor Yellow
    $powerScheme = powercfg /query SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226
    Write-Host $powerScheme
    
    # Registry check
    Write-Host "[6/6] Registry Check" -ForegroundColor Yellow
    foreach ($device in $devices) {
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($device.InstanceId)"
        if (Test-Path $regPath) {
            Write-Host "Registry path exists: $regPath" -ForegroundColor Green
        } else {
            Write-Host "Registry path missing: $regPath" -ForegroundColor Red
        }
    }
    
    # Final test
    $testResults = Test-FocusriteConnection
    Show-DeviceStatus $testResults
}

function Invoke-ResetMode {
    Write-ToolkitLog "Running Reset Mode..." "SUCCESS"
    
    Write-Host "WARNING: This will reset all USB devices and services!" -ForegroundColor Red
    if (-not $AutoFix) {
        $response = Read-Host "Continue? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Host "Operation cancelled by user" -ForegroundColor Yellow
            return $false
        }
    }
    
    # Remove hidden devices
    Remove-HiddenUSBDevices -Force
    
    # Reset USB stack
    Reset-USBStack
    
    # Reset all Focusrite devices
    $devices = Get-FocusriteDevices
    foreach ($device in $devices) {
        Reset-USBDevice -InstanceId $device.InstanceId
    }
    
    Write-Host "Reset complete. Please reconnect your Focusrite device." -ForegroundColor Green
    return $true
}

function Invoke-PowerMode {
    Write-ToolkitLog "Running Power Optimization Mode..." "SUCCESS"
    
    $result = Optimize-USBPowerSettings
    if ($result) {
        Write-Host "Power settings optimized successfully" -ForegroundColor Green
        Write-Host "Restart required to apply all changes" -ForegroundColor Yellow
    } else {
        Write-Host "Power optimization failed" -ForegroundColor Red
    }
    
    return $result
}

function Invoke-VMMode {
    Write-ToolkitLog "Running VM Optimization Mode..." "SUCCESS"
    
    $result = Optimize-VMUSBConfiguration
    if ($result) {
        Write-Host "VM USB configuration optimized successfully" -ForegroundColor Green
        Write-Host "Restart required to apply all changes" -ForegroundColor Yellow
    } else {
        Write-Host "VM optimization failed" -ForegroundColor Red
    }
    
    return $result
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

try {
    Show-Banner
    
    # Check admin privileges
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Error "This script must be run as Administrator"
        exit 1
    }
    
    $success = $false
    
    switch ($Mode) {
        "Quick" {
            $success = Invoke-QuickMode
        }
        "Full" {
            $results = Start-FocusriteTroubleshooting -AutoFix:$AutoFix -LogFile $LogFile
            Show-TroubleshootingResults $results
            $success = $results.OverallSuccess
        }
        "Diagnostic" {
            Invoke-DiagnosticMode
            $success = $true
        }
        "Reset" {
            $success = Invoke-ResetMode
        }
        "Power" {
            $success = Invoke-PowerMode
        }
        "VM" {
            $success = Invoke-VMMode
        }
    }
    
    # Show final recommendations
    if ($Mode -ne "Diagnostic") {
        Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "RECOMMENDATIONS" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        
        if ($success) {
            Write-Host "✓ Troubleshooting completed successfully" -ForegroundColor Green
            Write-Host "✓ Test your Focusrite device in FL Studio" -ForegroundColor Green
            Write-Host "✓ Check Windows Sound Settings for proper device selection" -ForegroundColor Green
        } else {
            Write-Host "⚠ Issues may still exist. Try the following:" -ForegroundColor Yellow
            Write-Host "  • Run: .\Fix-FocusriteUSB.ps1 -Mode Reset -AutoFix" -ForegroundColor White
            Write-Host "  • Download and install latest Focusrite drivers" -ForegroundColor White
            Write-Host "  • Check VM USB passthrough configuration" -ForegroundColor White
            Write-Host "  • Restart Windows and test again" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "Log file saved to: $LogFile" -ForegroundColor Cyan
    }
    
    exit 0
}
catch {
    Write-ToolkitLog "Script execution failed: $($_.Exception.Message)" "ERROR"
    Write-Host "Script failed with error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}