# =============================================================================
# FocusriteUSBToolkit.psm1
# PowerShell module for resolving Focusrite 4i4 USB passthrough issues
# Author: Hive Mind Coder Agent
# Version: 1.0.0
# =============================================================================

#Requires -Version 5.1
#Requires -RunAsAdministrator

# Module variables
$Global:LogPath = "$env:TEMP\FocusriteUSBToolkit.log"
$Global:FocusriteVendorID = "1235"
$Global:FocusriteProductID = "821a"
$Global:DeviceInstancePattern = "*VID_1235&PID_821A*"

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

function Write-ToolkitLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to console with colors
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARN" { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        default { Write-Host $logEntry -ForegroundColor White }
    }
    
    # Write to log file
    Add-Content -Path $Global:LogPath -Value $logEntry -Force
}

# =============================================================================
# USB DEVICE ENUMERATION & DETECTION
# =============================================================================

function Get-FocusriteDevices {
    [CmdletBinding()]
    param()
    
    Write-ToolkitLog "Scanning for Focusrite devices..."
    
    try {
        # Get all USB devices
        $usbDevices = Get-CimInstance -ClassName Win32_USBHub | Where-Object { 
            $_.DeviceID -like "*VID_1235*" -and $_.DeviceID -like "*PID_821A*" 
        }
        
        # Get PnP devices (more comprehensive)
        $pnpDevices = Get-PnPDevice | Where-Object { 
            $_.InstanceId -like $Global:DeviceInstancePattern 
        }
        
        # Combine results
        $devices = @()
        
        foreach ($device in $pnpDevices) {
            $deviceInfo = [PSCustomObject]@{
                Name = $device.Name
                InstanceId = $device.InstanceId
                Status = $device.Status
                ProblemCode = $device.ProblemCode
                DeviceClass = $device.Class
                Present = $device.Present
                Type = "PnP"
            }
            $devices += $deviceInfo
        }
        
        foreach ($device in $usbDevices) {
            $deviceInfo = [PSCustomObject]@{
                Name = $device.Name
                InstanceId = $device.DeviceID
                Status = $device.Status
                ProblemCode = $device.ConfigManagerErrorCode
                DeviceClass = "USB"
                Present = $true
                Type = "USB"
            }
            $devices += $deviceInfo
        }
        
        Write-ToolkitLog "Found $($devices.Count) Focusrite devices" "SUCCESS"
        return $devices
    }
    catch {
        Write-ToolkitLog "Error scanning for devices: $($_.Exception.Message)" "ERROR"
        return @()
    }
}

function Get-HiddenUSBDevices {
    [CmdletBinding()]
    param()
    
    Write-ToolkitLog "Scanning for hidden USB devices..."
    
    try {
        # Set environment variable to show hidden devices
        $env:DEVMGR_SHOW_NONPRESENT_DEVICES = 1
        
        # Get all PnP devices including non-present ones
        $allDevices = Get-PnPDevice -InstanceId $Global:DeviceInstancePattern -ErrorAction SilentlyContinue
        $hiddenDevices = $allDevices | Where-Object { $_.Present -eq $false }
        
        Write-ToolkitLog "Found $($hiddenDevices.Count) hidden Focusrite devices" "SUCCESS"
        return $hiddenDevices
    }
    catch {
        Write-ToolkitLog "Error scanning for hidden devices: $($_.Exception.Message)" "ERROR"
        return @()
    }
}

# =============================================================================
# USB DEVICE RESET & CLEANUP
# =============================================================================

function Reset-USBDevice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstanceId
    )
    
    Write-ToolkitLog "Resetting USB device: $InstanceId"
    
    try {
        # Disable the device
        Write-ToolkitLog "Disabling device..."
        Disable-PnpDevice -InstanceId $InstanceId -Confirm:$false -ErrorAction Stop
        Start-Sleep -Seconds 2
        
        # Enable the device
        Write-ToolkitLog "Enabling device..."
        Enable-PnpDevice -InstanceId $InstanceId -Confirm:$false -ErrorAction Stop
        Start-Sleep -Seconds 3
        
        Write-ToolkitLog "Device reset completed" "SUCCESS"
        return $true
    }
    catch {
        Write-ToolkitLog "Error resetting device: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Remove-HiddenUSBDevices {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    Write-ToolkitLog "Removing hidden USB devices..."
    
    try {
        $hiddenDevices = Get-HiddenUSBDevices
        $removeCount = 0
        
        foreach ($device in $hiddenDevices) {
            Write-ToolkitLog "Removing hidden device: $($device.Name)"
            
            if ($Force) {
                Remove-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction Continue
                $removeCount++
            } else {
                $response = Read-Host "Remove device '$($device.Name)'? (y/N)"
                if ($response -eq 'y' -or $response -eq 'Y') {
                    Remove-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction Continue
                    $removeCount++
                }
            }
        }
        
        Write-ToolkitLog "Removed $removeCount hidden devices" "SUCCESS"
        return $removeCount
    }
    catch {
        Write-ToolkitLog "Error removing hidden devices: $($_.Exception.Message)" "ERROR"
        return 0
    }
}

function Reset-USBStack {
    [CmdletBinding()]
    param()
    
    Write-ToolkitLog "Resetting USB stack..."
    
    try {
        # Stop USB-related services
        $services = @("USBHUB3", "USB", "USBSTOR", "USBCCGP", "USBHUB")
        
        foreach ($service in $services) {
            try {
                Write-ToolkitLog "Stopping service: $service"
                Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            }
            catch {
                Write-ToolkitLog "Could not stop service $service" "WARN"
            }
        }
        
        Start-Sleep -Seconds 3
        
        # Start USB-related services
        foreach ($service in $services) {
            try {
                Write-ToolkitLog "Starting service: $service"
                Start-Service -Name $service -ErrorAction SilentlyContinue
            }
            catch {
                Write-ToolkitLog "Could not start service $service" "WARN"
            }
        }
        
        Start-Sleep -Seconds 5
        Write-ToolkitLog "USB stack reset completed" "SUCCESS"
        return $true
    }
    catch {
        Write-ToolkitLog "Error resetting USB stack: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# =============================================================================
# DRIVER MANAGEMENT
# =============================================================================

function Update-FocusriteDrivers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DriverPath
    )
    
    Write-ToolkitLog "Updating Focusrite drivers..."
    
    try {
        $devices = Get-FocusriteDevices
        $updateCount = 0
        
        foreach ($device in $devices) {
            Write-ToolkitLog "Updating driver for: $($device.Name)"
            
            if ($DriverPath) {
                # Use specific driver path
                pnputil /add-driver $DriverPath /install
            } else {
                # Use Windows Update to find drivers
                Update-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction Continue
            }
            $updateCount++
        }
        
        Write-ToolkitLog "Updated drivers for $updateCount devices" "SUCCESS"
        return $updateCount
    }
    catch {
        Write-ToolkitLog "Error updating drivers: $($_.Exception.Message)" "ERROR"
        return 0
    }
}

function Install-FocusriteControl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$InstallerPath
    )
    
    Write-ToolkitLog "Installing Focusrite Control software..."
    
    if (-not $InstallerPath) {
        Write-ToolkitLog "No installer path provided. Please download from focusrite.com" "WARN"
        return $false
    }
    
    if (-not (Test-Path $InstallerPath)) {
        Write-ToolkitLog "Installer not found at: $InstallerPath" "ERROR"
        return $false
    }
    
    try {
        Write-ToolkitLog "Running installer: $InstallerPath"
        Start-Process -FilePath $InstallerPath -ArgumentList "/S" -Wait -NoNewWindow
        Write-ToolkitLog "Focusrite Control installation completed" "SUCCESS"
        return $true
    }
    catch {
        Write-ToolkitLog "Error installing Focusrite Control: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# =============================================================================
# USB POWER MANAGEMENT
# =============================================================================

function Disable-USBSelectiveSuspend {
    [CmdletBinding()]
    param()
    
    Write-ToolkitLog "Disabling USB selective suspend..."
    
    try {
        # Disable USB selective suspend in power plan
        powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
        powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
        powercfg /setactive SCHEME_CURRENT
        
        Write-ToolkitLog "USB selective suspend disabled" "SUCCESS"
        
        # Also disable in registry for individual devices
        $devices = Get-FocusriteDevices
        foreach ($device in $devices) {
            try {
                $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($device.InstanceId)\Device Parameters"
                if (Test-Path $regPath) {
                    Set-ItemProperty -Path $regPath -Name "EnhancedPowerManagementEnabled" -Value 0 -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $regPath -Name "AllowIdleIrpInD3" -Value 0 -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $regPath -Name "EnableSelectiveSuspend" -Value 0 -ErrorAction SilentlyContinue
                }
            }
            catch {
                Write-ToolkitLog "Could not modify registry for device: $($device.Name)" "WARN"
            }
        }
        
        return $true
    }
    catch {
        Write-ToolkitLog "Error disabling USB selective suspend: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Optimize-USBPowerSettings {
    [CmdletBinding()]
    param()
    
    Write-ToolkitLog "Optimizing USB power settings..."
    
    try {
        # Set high performance power plan
        $highPerfGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
        powercfg /setactive $highPerfGuid
        
        # Optimize USB power settings
        Disable-USBSelectiveSuspend
        
        # Set USB hub power timeout to never
        powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 0853a681-27c8-4100-a2fd-82013e970683 0
        powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 0853a681-27c8-4100-a2fd-82013e970683 0
        
        # Apply settings
        powercfg /setactive SCHEME_CURRENT
        
        Write-ToolkitLog "USB power settings optimized" "SUCCESS"
        return $true
    }
    catch {
        Write-ToolkitLog "Error optimizing USB power settings: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# =============================================================================
# VM OPTIMIZATION
# =============================================================================

function Optimize-VMUSBConfiguration {
    [CmdletBinding()]
    param()
    
    Write-ToolkitLog "Optimizing VM USB configuration..."
    
    try {
        # Disable USB legacy support if needed
        Write-ToolkitLog "Checking USB legacy support..."
        
        # Registry tweaks for better USB performance in VM
        $regTweaks = @{
            "HKLM:\SYSTEM\CurrentControlSet\Services\USBHUB3\Parameters" = @{
                "DisableOnSoftRemove" = 0
                "WaitWakeSupported" = 0
            }
            "HKLM:\SYSTEM\CurrentControlSet\Services\USB\Parameters" = @{
                "DisableSelectiveSuspend" = 1
            }
        }
        
        foreach ($regPath in $regTweaks.Keys) {
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }
            
            foreach ($property in $regTweaks[$regPath].Keys) {
                Set-ItemProperty -Path $regPath -Name $property -Value $regTweaks[$regPath][$property] -Type DWORD
                Write-ToolkitLog "Set registry value: $regPath\$property"
            }
        }
        
        Write-ToolkitLog "VM USB configuration optimized" "SUCCESS"
        return $true
    }
    catch {
        Write-ToolkitLog "Error optimizing VM USB configuration: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# =============================================================================
# COMPREHENSIVE TROUBLESHOOTING
# =============================================================================

function Start-FocusriteTroubleshooting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$AutoFix,
        
        [Parameter(Mandatory = $false)]
        [string]$LogFile
    )
    
    if ($LogFile) {
        $Global:LogPath = $LogFile
    }
    
    Write-ToolkitLog "Starting Focusrite USB troubleshooting..." "SUCCESS"
    Write-ToolkitLog "Log file: $Global:LogPath"
    
    $results = [PSCustomObject]@{
        DevicesFound = 0
        DevicesReset = 0
        HiddenDevicesRemoved = 0
        DriversUpdated = 0
        PowerOptimized = $false
        VMOptimized = $false
        OverallSuccess = $false
    }
    
    try {
        # Step 1: Scan for devices
        Write-ToolkitLog "=== STEP 1: DEVICE DETECTION ===" "SUCCESS"
        $devices = Get-FocusriteDevices
        $results.DevicesFound = $devices.Count
        
        if ($devices.Count -eq 0) {
            Write-ToolkitLog "No Focusrite devices found. Checking for hidden devices..." "WARN"
            $hiddenDevices = Get-HiddenUSBDevices
            
            if ($hiddenDevices.Count -gt 0) {
                Write-ToolkitLog "Found $($hiddenDevices.Count) hidden devices"
                if ($AutoFix) {
                    $results.HiddenDevicesRemoved = Remove-HiddenUSBDevices -Force
                }
            }
        }
        
        # Step 2: Reset USB devices
        Write-ToolkitLog "=== STEP 2: DEVICE RESET ===" "SUCCESS"
        foreach ($device in $devices) {
            if (Reset-USBDevice -InstanceId $device.InstanceId) {
                $results.DevicesReset++
            }
        }
        
        # Step 3: USB stack reset
        Write-ToolkitLog "=== STEP 3: USB STACK RESET ===" "SUCCESS"
        Reset-USBStack
        
        # Step 4: Driver updates
        Write-ToolkitLog "=== STEP 4: DRIVER UPDATES ===" "SUCCESS"
        if ($AutoFix) {
            $results.DriversUpdated = Update-FocusriteDrivers
        }
        
        # Step 5: Power optimization
        Write-ToolkitLog "=== STEP 5: POWER OPTIMIZATION ===" "SUCCESS"
        if ($AutoFix) {
            $results.PowerOptimized = Optimize-USBPowerSettings
        }
        
        # Step 6: VM optimization
        Write-ToolkitLog "=== STEP 6: VM OPTIMIZATION ===" "SUCCESS"
        if ($AutoFix) {
            $results.VMOptimized = Optimize-VMUSBConfiguration
        }
        
        # Final device check
        Write-ToolkitLog "=== FINAL VERIFICATION ===" "SUCCESS"
        Start-Sleep -Seconds 5
        $finalDevices = Get-FocusriteDevices
        $workingDevices = $finalDevices | Where-Object { $_.Status -eq "OK" }
        
        Write-ToolkitLog "Final device count: $($finalDevices.Count)"
        Write-ToolkitLog "Working devices: $($workingDevices.Count)"
        
        $results.OverallSuccess = ($workingDevices.Count -gt 0)
        
        if ($results.OverallSuccess) {
            Write-ToolkitLog "Troubleshooting completed successfully!" "SUCCESS"
        } else {
            Write-ToolkitLog "Troubleshooting completed with issues. Manual intervention may be required." "WARN"
        }
        
        return $results
    }
    catch {
        Write-ToolkitLog "Error during troubleshooting: $($_.Exception.Message)" "ERROR"
        return $results
    }
}

function Test-FocusriteConnection {
    [CmdletBinding()]
    param()
    
    Write-ToolkitLog "Testing Focusrite connection..."
    
    $devices = Get-FocusriteDevices
    $testResults = [PSCustomObject]@{
        DevicesDetected = $devices.Count
        WorkingDevices = 0
        ProblematicDevices = 0
        HiddenDevices = 0
        OverallHealth = "Unknown"
    }
    
    # Check working devices
    $workingDevices = $devices | Where-Object { $_.Status -eq "OK" }
    $testResults.WorkingDevices = $workingDevices.Count
    
    # Check problematic devices
    $problematicDevices = $devices | Where-Object { $_.Status -ne "OK" }
    $testResults.ProblematicDevices = $problematicDevices.Count
    
    # Check hidden devices
    $hiddenDevices = Get-HiddenUSBDevices
    $testResults.HiddenDevices = $hiddenDevices.Count
    
    # Determine overall health
    if ($testResults.WorkingDevices -gt 0 -and $testResults.ProblematicDevices -eq 0) {
        $testResults.OverallHealth = "Good"
        Write-ToolkitLog "Connection test: PASSED" "SUCCESS"
    } elseif ($testResults.WorkingDevices -gt 0) {
        $testResults.OverallHealth = "Fair"
        Write-ToolkitLog "Connection test: PARTIAL" "WARN"
    } else {
        $testResults.OverallHealth = "Poor"
        Write-ToolkitLog "Connection test: FAILED" "ERROR"
    }
    
    return $testResults
}

# =============================================================================
# EXPORT MODULE FUNCTIONS
# =============================================================================

Export-ModuleMember -Function @(
    'Get-FocusriteDevices',
    'Get-HiddenUSBDevices',
    'Reset-USBDevice',
    'Remove-HiddenUSBDevices',
    'Reset-USBStack',
    'Update-FocusriteDrivers',
    'Install-FocusriteControl',
    'Disable-USBSelectiveSuspend',
    'Optimize-USBPowerSettings',
    'Optimize-VMUSBConfiguration',
    'Start-FocusriteTroubleshooting',
    'Test-FocusriteConnection',
    'Write-ToolkitLog'
)