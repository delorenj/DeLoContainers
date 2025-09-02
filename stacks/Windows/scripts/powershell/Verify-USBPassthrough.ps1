# =============================================================================
# Verify-USBPassthrough.ps1
# USB passthrough verification and validation script for VMs
# Author: Hive Mind Coder Agent
# Version: 1.0.0
# =============================================================================

#Requires -Version 5.1
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory = $false)]
    [switch]$Detailed = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$Export = $false,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "$env:TEMP\USBPassthroughReport.html"
)

# Import the toolkit module
$ModulePath = Join-Path $PSScriptRoot "FocusriteUSBToolkit.psm1"
if (Test-Path $ModulePath) {
    Import-Module $ModulePath -Force
} else {
    Write-Error "FocusriteUSBToolkit.psm1 not found at: $ModulePath"
    exit 1
}

function Test-USBPassthroughStatus {
    [CmdletBinding()]
    param()
    
    Write-ToolkitLog "Testing USB passthrough status..."
    
    $results = [PSCustomObject]@{
        VMDetected = $false
        VMType = "Unknown"
        USBControllersPresent = 0
        FocusriteDetected = $false
        FocusriteWorking = $false
        PassthroughSuccess = $false
        IssuesFound = @()
        Recommendations = @()
    }
    
    try {
        # Check if running in VM
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
        $biosInfo = Get-CimInstance -ClassName Win32_BIOS
        
        # VM detection heuristics
        $vmIndicators = @(
            ($computerSystem.Manufacturer -like "*VMware*"),
            ($computerSystem.Manufacturer -like "*Microsoft Corporation*" -and $computerSystem.Model -like "*Virtual*"),
            ($computerSystem.Manufacturer -like "*QEMU*"),
            ($computerSystem.Manufacturer -like "*innotek*"),
            ($biosInfo.SMBIOSBIOSVersion -like "*VirtualBox*"),
            ($biosInfo.SMBIOSBIOSVersion -like "*VMware*"),
            ($biosInfo.SMBIOSBIOSVersion -like "*QEMU*"),
            ($computerSystem.Model -like "*VirtualBox*"),
            ($computerSystem.Model -like "*VMware*")
        )
        
        if ($vmIndicators -contains $true) {
            $results.VMDetected = $true
            
            # Determine VM type
            if ($computerSystem.Manufacturer -like "*VMware*" -or $biosInfo.SMBIOSBIOSVersion -like "*VMware*") {
                $results.VMType = "VMware"
            } elseif ($computerSystem.Model -like "*VirtualBox*" -or $biosInfo.SMBIOSBIOSVersion -like "*VirtualBox*") {
                $results.VMType = "VirtualBox"
            } elseif ($computerSystem.Manufacturer -like "*Microsoft Corporation*") {
                $results.VMType = "Hyper-V"
            } elseif ($computerSystem.Manufacturer -like "*QEMU*" -or $biosInfo.SMBIOSBIOSVersion -like "*QEMU*") {
                $results.VMType = "QEMU/KVM"
            }
        }
        
        # Check USB controllers
        $usbControllers = Get-CimInstance -ClassName Win32_USBController
        $results.USBControllersPresent = $usbControllers.Count
        
        # Check for Focusrite devices
        $focusriteDevices = Get-FocusriteDevices
        $results.FocusriteDetected = ($focusriteDevices.Count -gt 0)
        
        if ($results.FocusriteDetected) {
            $workingDevices = $focusriteDevices | Where-Object { $_.Status -eq "OK" }
            $results.FocusriteWorking = ($workingDevices.Count -gt 0)
        }
        
        # Determine overall passthrough success
        $results.PassthroughSuccess = ($results.FocusriteDetected -and $results.FocusriteWorking)
        
        # Analyze issues and recommendations
        if ($results.VMDetected -and -not $results.FocusriteDetected) {
            $results.IssuesFound += "Focusrite device not detected in VM"
            $results.Recommendations += "Check host USB passthrough configuration"
            $results.Recommendations += "Verify device is connected to host"
        }
        
        if ($results.FocusriteDetected -and -not $results.FocusriteWorking) {
            $results.IssuesFound += "Focusrite device detected but not working properly"
            $results.Recommendations += "Run Fix-FocusriteUSB.ps1 -Mode Full"
            $results.Recommendations += "Update Focusrite drivers"
        }
        
        if ($results.USBControllersPresent -eq 0) {
            $results.IssuesFound += "No USB controllers detected"
            $results.Recommendations += "Check VM USB controller configuration"
        }
        
        return $results
    }
    catch {
        Write-ToolkitLog "Error testing USB passthrough: $($_.Exception.Message)" "ERROR"
        return $results
    }
}

function Get-USBDeviceInventory {
    [CmdletBinding()]
    param()
    
    Write-ToolkitLog "Gathering USB device inventory..."
    
    $inventory = @{
        USBHubs = @()
        USBDevices = @()
        AudioDevices = @()
        HIDDevices = @()
        UnknownDevices = @()
    }
    
    try {
        # Get USB Hubs
        $usbHubs = Get-CimInstance -ClassName Win32_USBHub
        foreach ($hub in $usbHubs) {
            $inventory.USBHubs += [PSCustomObject]@{
                Name = $hub.Name
                DeviceID = $hub.DeviceID
                Status = $hub.Status
                Description = $hub.Description
            }
        }
        
        # Get all PnP devices
        $allDevices = Get-PnPDevice
        
        # Categorize devices
        foreach ($device in $allDevices) {
            $deviceInfo = [PSCustomObject]@{
                Name = $device.FriendlyName
                InstanceId = $device.InstanceId
                Status = $device.Status
                Class = $device.Class
                Present = $device.Present
            }
            
            switch ($device.Class) {
                "AudioEndpoint" { $inventory.AudioDevices += $deviceInfo }
                "Media" { $inventory.AudioDevices += $deviceInfo }
                "HIDClass" { $inventory.HIDDevices += $deviceInfo }
                "USB" { $inventory.USBDevices += $deviceInfo }
                default { 
                    if ($device.InstanceId -like "*USB*") {
                        $inventory.USBDevices += $deviceInfo
                    }
                }
            }
            
            # Check for unknown/problematic devices
            if ($device.Status -ne "OK" -and $device.Present) {
                $inventory.UnknownDevices += $deviceInfo
            }
        }
        
        return $inventory
    }
    catch {
        Write-ToolkitLog "Error gathering device inventory: $($_.Exception.Message)" "ERROR"
        return $inventory
    }
}

function Test-VMUSBConfiguration {
    [CmdletBinding()]
    param()
    
    Write-ToolkitLog "Testing VM USB configuration..."
    
    $config = [PSCustomObject]@{
        USBVersion = "Unknown"
        EHCISupport = $false
        XHCISupport = $false
        USB3Support = $false
        SelectiveSuspendEnabled = $true
        PowerManagementOptimal = $false
        Issues = @()
        Recommendations = @()
    }
    
    try {
        # Check USB controller types
        $usbControllers = Get-CimInstance -ClassName Win32_USBController
        foreach ($controller in $usbControllers) {
            if ($controller.Name -like "*EHCI*") {
                $config.EHCISupport = $true
            }
            if ($controller.Name -like "*xHCI*" -or $controller.Name -like "*USB 3*") {
                $config.XHCISupport = $true
                $config.USB3Support = $true
            }
        }
        
        # Check power settings
        try {
            $powerOutput = powercfg /query SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226
            $config.SelectiveSuspendEnabled = -not ($powerOutput -like "*Current AC Power Setting Index: 0x00000000*")
        }
        catch {
            Write-ToolkitLog "Could not check power settings" "WARN"
        }
        
        # Analyze configuration
        if (-not $config.USB3Support) {
            $config.Issues += "USB 3.0 support not detected"
            $config.Recommendations += "Enable USB 3.0/xHCI controller in VM settings"
        }
        
        if ($config.SelectiveSuspendEnabled) {
            $config.Issues += "USB selective suspend is enabled"
            $config.Recommendations += "Disable USB selective suspend for better audio device stability"
        }
        
        $config.PowerManagementOptimal = -not $config.SelectiveSuspendEnabled
        
        return $config
    }
    catch {
        Write-ToolkitLog "Error testing VM USB configuration: $($_.Exception.Message)" "ERROR"
        return $config
    }
}

function Generate-HTMLReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $PassthroughStatus,
        
        [Parameter(Mandatory = $true)]
        $DeviceInventory,
        
        [Parameter(Mandatory = $true)]
        $USBConfiguration,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>USB Passthrough Verification Report</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 10px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        .header { text-align: center; color: #333; border-bottom: 2px solid #4CAF50; padding-bottom: 20px; margin-bottom: 30px; }
        .section { margin-bottom: 30px; padding: 15px; border-left: 4px solid #4CAF50; background-color: #f9f9f9; }
        .section h2 { color: #333; margin-top: 0; }
        .success { color: #4CAF50; font-weight: bold; }
        .warning { color: #FF9800; font-weight: bold; }
        .error { color: #F44336; font-weight: bold; }
        .info { color: #2196F3; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #4CAF50; color: white; }
        .status-ok { background-color: #E8F5E8; }
        .status-error { background-color: #FFEBEE; }
        .status-warning { background-color: #FFF3E0; }
        ul { padding-left: 20px; }
        .timestamp { text-align: right; color: #666; font-size: 0.9em; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>USB Passthrough Verification Report</h1>
            <p>Focusrite Scarlett 4i4 USB Passthrough Analysis</p>
        </div>
        
        <div class="section">
            <h2>📊 Overall Status</h2>
            <table>
                <tr><td><strong>VM Detected:</strong></td><td class="$(if($PassthroughStatus.VMDetected){'success'}else{'info'})">$($PassthroughStatus.VMDetected)</td></tr>
                <tr><td><strong>VM Type:</strong></td><td class="info">$($PassthroughStatus.VMType)</td></tr>
                <tr><td><strong>USB Controllers:</strong></td><td class="$(if($PassthroughStatus.USBControllersPresent -gt 0){'success'}else{'error'})">$($PassthroughStatus.USBControllersPresent)</td></tr>
                <tr><td><strong>Focusrite Detected:</strong></td><td class="$(if($PassthroughStatus.FocusriteDetected){'success'}else{'error'})">$($PassthroughStatus.FocusriteDetected)</td></tr>
                <tr><td><strong>Focusrite Working:</strong></td><td class="$(if($PassthroughStatus.FocusriteWorking){'success'}else{'error'})">$($PassthroughStatus.FocusriteWorking)</td></tr>
                <tr><td><strong>Passthrough Success:</strong></td><td class="$(if($PassthroughStatus.PassthroughSuccess){'success'}else{'error'})">$($PassthroughStatus.PassthroughSuccess)</td></tr>
            </table>
        </div>
        
        <div class="section">
            <h2>🔧 VM USB Configuration</h2>
            <table>
                <tr><td><strong>EHCI Support:</strong></td><td class="$(if($USBConfiguration.EHCISupport){'success'}else{'warning'})">$($USBConfiguration.EHCISupport)</td></tr>
                <tr><td><strong>xHCI Support:</strong></td><td class="$(if($USBConfiguration.XHCISupport){'success'}else{'warning'})">$($USBConfiguration.XHCISupport)</td></tr>
                <tr><td><strong>USB 3.0 Support:</strong></td><td class="$(if($USBConfiguration.USB3Support){'success'}else{'warning'})">$($USBConfiguration.USB3Support)</td></tr>
                <tr><td><strong>Selective Suspend:</strong></td><td class="$(if($USBConfiguration.SelectiveSuspendEnabled){'error'}else{'success'})">$($USBConfiguration.SelectiveSuspendEnabled)</td></tr>
                <tr><td><strong>Power Management:</strong></td><td class="$(if($USBConfiguration.PowerManagementOptimal){'success'}else{'warning'})">$(if($USBConfiguration.PowerManagementOptimal){'Optimal'}else{'Needs Optimization'})</td></tr>
            </table>
        </div>
        
        <div class="section">
            <h2>🎵 Audio Devices</h2>
            <table>
                <thead>
                    <tr><th>Device Name</th><th>Status</th><th>Class</th><th>Present</th></tr>
                </thead>
                <tbody>
"@

    foreach ($device in $DeviceInventory.AudioDevices) {
        $statusClass = if ($device.Status -eq "OK") { "status-ok" } elseif ($device.Present -eq $false) { "status-warning" } else { "status-error" }
        $html += "<tr class='$statusClass'><td>$($device.Name)</td><td>$($device.Status)</td><td>$($device.Class)</td><td>$($device.Present)</td></tr>"
    }

    $html += @"
                </tbody>
            </table>
        </div>
        
        <div class="section">
            <h2>🔌 USB Devices</h2>
            <table>
                <thead>
                    <tr><th>Device Name</th><th>Status</th><th>Class</th><th>Present</th></tr>
                </thead>
                <tbody>
"@

    foreach ($device in $DeviceInventory.USBDevices) {
        $statusClass = if ($device.Status -eq "OK") { "status-ok" } elseif ($device.Present -eq $false) { "status-warning" } else { "status-error" }
        $html += "<tr class='$statusClass'><td>$($device.Name)</td><td>$($device.Status)</td><td>$($device.Class)</td><td>$($device.Present)</td></tr>"
    }

    $html += @"
                </tbody>
            </table>
        </div>
"@

    if ($PassthroughStatus.IssuesFound.Count -gt 0) {
        $html += @"
        <div class="section">
            <h2>⚠️ Issues Found</h2>
            <ul>
"@
        foreach ($issue in $PassthroughStatus.IssuesFound) {
            $html += "<li class='error'>$issue</li>"
        }
        $html += "</ul></div>"
    }

    if ($PassthroughStatus.Recommendations.Count -gt 0) {
        $html += @"
        <div class="section">
            <h2>💡 Recommendations</h2>
            <ul>
"@
        foreach ($recommendation in $PassthroughStatus.Recommendations) {
            $html += "<li class='info'>$recommendation</li>"
        }
        $html += "</ul></div>"
    }

    $html += @"
        <div class="timestamp">
            Report generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        </div>
    </div>
</body>
</html>
"@

    try {
        $html | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-ToolkitLog "HTML report saved to: $OutputPath" "SUCCESS"
        return $true
    }
    catch {
        Write-ToolkitLog "Error saving HTML report: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

try {
    Write-Host @"
╔═══════════════════════════════════════════════════════════════════════════════╗
║                        USB PASSTHROUGH VERIFIER                              ║
║                              Version 1.0.0                                   ║
╚═══════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

    Write-Host ""
    
    # Test USB passthrough status
    Write-Host "[1/4] Testing USB passthrough status..." -ForegroundColor Yellow
    $passthroughStatus = Test-USBPassthroughStatus
    
    # Gather device inventory
    Write-Host "[2/4] Gathering device inventory..." -ForegroundColor Yellow
    $deviceInventory = Get-USBDeviceInventory
    
    # Test VM USB configuration
    Write-Host "[3/4] Testing VM USB configuration..." -ForegroundColor Yellow
    $usbConfiguration = Test-VMUSBConfiguration
    
    # Display results
    Write-Host "[4/4] Generating report..." -ForegroundColor Yellow
    Write-Host ""
    
    # Console output
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "USB PASSTHROUGH VERIFICATION RESULTS" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    $overallColor = if ($passthroughStatus.PassthroughSuccess) { "Green" } else { "Red" }
    $overallStatus = if ($passthroughStatus.PassthroughSuccess) { "SUCCESS" } else { "FAILED" }
    
    Write-Host "Overall Status: $overallStatus" -ForegroundColor $overallColor
    Write-Host "VM Type: $($passthroughStatus.VMType)"
    Write-Host "USB Controllers: $($passthroughStatus.USBControllersPresent)"
    Write-Host "Focusrite Detected: $($passthroughStatus.FocusriteDetected)"
    Write-Host "Focusrite Working: $($passthroughStatus.FocusriteWorking)"
    Write-Host ""
    
    if ($Detailed) {
        Write-Host "USB Device Summary:" -ForegroundColor Yellow
        Write-Host "  Audio Devices: $($deviceInventory.AudioDevices.Count)"
        Write-Host "  USB Devices: $($deviceInventory.USBDevices.Count)"
        Write-Host "  USB Hubs: $($deviceInventory.USBHubs.Count)"
        Write-Host "  HID Devices: $($deviceInventory.HIDDevices.Count)"
        Write-Host "  Unknown/Problem Devices: $($deviceInventory.UnknownDevices.Count)"
        Write-Host ""
        
        Write-Host "VM Configuration:" -ForegroundColor Yellow
        Write-Host "  USB 3.0 Support: $($usbConfiguration.USB3Support)"
        Write-Host "  Selective Suspend: $($usbConfiguration.SelectiveSuspendEnabled)"
        Write-Host "  Power Management: $(if($usbConfiguration.PowerManagementOptimal){'Optimal'}else{'Needs Optimization'})"
        Write-Host ""
    }
    
    if ($passthroughStatus.IssuesFound.Count -gt 0) {
        Write-Host "Issues Found:" -ForegroundColor Red
        foreach ($issue in $passthroughStatus.IssuesFound) {
            Write-Host "  • $issue" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    if ($passthroughStatus.Recommendations.Count -gt 0) {
        Write-Host "Recommendations:" -ForegroundColor Yellow
        foreach ($recommendation in $passthroughStatus.Recommendations) {
            Write-Host "  • $recommendation" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    # Export HTML report if requested
    if ($Export) {
        if (Generate-HTMLReport -PassthroughStatus $passthroughStatus -DeviceInventory $deviceInventory -USBConfiguration $usbConfiguration -OutputPath $OutputFile) {
            Write-Host "Detailed HTML report exported to: $OutputFile" -ForegroundColor Green
            
            # Try to open the report
            try {
                Start-Process $OutputFile
            }
            catch {
                Write-Host "Report saved but could not be opened automatically" -ForegroundColor Yellow
            }
        }
    }
    
    # Exit with appropriate code
    if ($passthroughStatus.PassthroughSuccess) {
        exit 0
    } else {
        exit 1
    }
}
catch {
    Write-ToolkitLog "Script execution failed: $($_.Exception.Message)" "ERROR"
    Write-Host "Verification failed with error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}