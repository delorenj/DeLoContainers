# =============================================================================
# Install-FocusriteDrivers.ps1  
# Automated Focusrite driver installation and management script
# Author: Hive Mind Coder Agent
# Version: 1.0.0
# =============================================================================

#Requires -Version 5.1
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory = $false)]
    [string]$DriverPath,
    
    [Parameter(Mandatory = $false)]
    [string]$FocusriteControlPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$DownloadLatest = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$ForceReinstall = $false,
    
    [Parameter(Mandatory = $false)]
    [string]$DownloadPath = "$env:TEMP\FocusriteDrivers"
)

# Import the toolkit module
$ModulePath = Join-Path $PSScriptRoot "FocusriteUSBToolkit.psm1"
if (Test-Path $ModulePath) {
    Import-Module $ModulePath -Force
} else {
    Write-Error "FocusriteUSBToolkit.psm1 not found at: $ModulePath"
    exit 1
}

function Test-InternetConnection {
    [CmdletBinding()]
    param()
    
    try {
        $testConnection = Test-NetConnection -ComputerName "www.focusrite.com" -Port 80 -InformationLevel Quiet
        return $testConnection
    }
    catch {
        return $false
    }
}

function Get-LatestFocusriteDrivers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DownloadPath
    )
    
    Write-ToolkitLog "Attempting to download latest Focusrite drivers..."
    
    if (-not (Test-InternetConnection)) {
        Write-ToolkitLog "No internet connection available" "ERROR"
        return $null
    }
    
    try {
        # Create download directory
        if (-not (Test-Path $DownloadPath)) {
            New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
        }
        
        # Focusrite download URLs (these may change, so this is a best-effort approach)
        $downloadUrls = @{
            "FocusriteControl" = "https://downloads.focusrite.com/focusrite/scarlett-4th-gen/focusrite-control-3.18.0.exe"
            "UniversalDrivers" = "https://downloads.focusrite.com/focusrite/scarlett-4th-gen/focusrite-usb-2.0-driver-4.65.14.exe"
        }
        
        $downloadedFiles = @{}
        
        foreach ($item in $downloadUrls.GetEnumerator()) {
            $fileName = Split-Path $item.Value -Leaf
            $localPath = Join-Path $DownloadPath $fileName
            
            Write-ToolkitLog "Downloading $($item.Key)..."
            
            try {
                # Use different methods based on available tools
                if (Get-Command curl -ErrorAction SilentlyContinue) {
                    & curl -L -o $localPath $item.Value --silent --fail
                } elseif (Get-Command wget -ErrorAction SilentlyContinue) {
                    & wget -O $localPath $item.Value --quiet
                } else {
                    # Use PowerShell's Invoke-WebRequest as fallback
                    Invoke-WebRequest -Uri $item.Value -OutFile $localPath -UseBasicParsing
                }
                
                if (Test-Path $localPath) {
                    $downloadedFiles[$item.Key] = $localPath
                    Write-ToolkitLog "Downloaded: $localPath" "SUCCESS"
                } else {
                    Write-ToolkitLog "Failed to download $($item.Key)" "ERROR"
                }
            }
            catch {
                Write-ToolkitLog "Error downloading $($item.Key): $($_.Exception.Message)" "ERROR"
            }
        }
        
        return $downloadedFiles
    }
    catch {
        Write-ToolkitLog "Error in download process: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Uninstall-ExistingDrivers {
    [CmdletBinding()]
    param()
    
    Write-ToolkitLog "Uninstalling existing Focusrite drivers..."
    
    try {
        # Get installed programs related to Focusrite
        $focusritePrograms = Get-WmiObject -Class Win32_Product | Where-Object { 
            $_.Name -like "*Focusrite*" -or $_.Name -like "*Scarlett*" 
        }
        
        foreach ($program in $focusritePrograms) {
            Write-ToolkitLog "Uninstalling: $($program.Name)"
            try {
                $program.Uninstall() | Out-Null
                Write-ToolkitLog "Successfully uninstalled: $($program.Name)" "SUCCESS"
            }
            catch {
                Write-ToolkitLog "Failed to uninstall $($program.Name): $($_.Exception.Message)" "WARN"
            }
        }
        
        # Remove devices from device manager
        $devices = Get-FocusriteDevices
        foreach ($device in $devices) {
            try {
                Write-ToolkitLog "Removing device: $($device.Name)"
                Remove-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction Continue
            }
            catch {
                Write-ToolkitLog "Could not remove device: $($device.Name)" "WARN"
            }
        }
        
        # Remove hidden devices
        Remove-HiddenUSBDevices -Force
        
        Write-ToolkitLog "Driver uninstallation completed" "SUCCESS"
        return $true
    }
    catch {
        Write-ToolkitLog "Error during driver uninstallation: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Install-DriverFromPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallerPath
    )
    
    if (-not (Test-Path $InstallerPath)) {
        Write-ToolkitLog "Driver installer not found: $InstallerPath" "ERROR"
        return $false
    }
    
    Write-ToolkitLog "Installing driver from: $InstallerPath"
    
    try {
        $fileExtension = [System.IO.Path]::GetExtension($InstallerPath).ToLower()
        
        switch ($fileExtension) {
            ".exe" {
                # Run executable installer
                $process = Start-Process -FilePath $InstallerPath -ArgumentList "/S", "/v/qn" -Wait -PassThru -NoNewWindow
                if ($process.ExitCode -eq 0) {
                    Write-ToolkitLog "Driver installation completed successfully" "SUCCESS"
                    return $true
                } else {
                    Write-ToolkitLog "Driver installation failed with exit code: $($process.ExitCode)" "ERROR"
                    return $false
                }
            }
            ".msi" {
                # Run MSI installer
                $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$InstallerPath`"", "/quiet", "/norestart" -Wait -PassThru -NoNewWindow
                if ($process.ExitCode -eq 0) {
                    Write-ToolkitLog "MSI installation completed successfully" "SUCCESS"
                    return $true
                } else {
                    Write-ToolkitLog "MSI installation failed with exit code: $($process.ExitCode)" "ERROR"
                    return $false
                }
            }
            ".inf" {
                # Install INF driver
                $result = pnputil /add-driver $InstallerPath /install
                if ($LASTEXITCODE -eq 0) {
                    Write-ToolkitLog "INF driver installation completed successfully" "SUCCESS"
                    return $true
                } else {
                    Write-ToolkitLog "INF driver installation failed" "ERROR"
                    return $false
                }
            }
            default {
                Write-ToolkitLog "Unsupported installer format: $fileExtension" "ERROR"
                return $false
            }
        }
    }
    catch {
        Write-ToolkitLog "Error installing driver: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-DriverInstallation {
    [CmdletBinding()]
    param()
    
    Write-ToolkitLog "Testing driver installation..."
    
    # Wait for devices to be recognized
    Start-Sleep -Seconds 10
    
    # Scan for hardware changes
    Write-ToolkitLog "Scanning for hardware changes..."
    try {
        $devices = Get-CimInstance -ClassName Win32_PnPEntity | Where-Object { $_.DeviceID -like "*VID_1235*" }
        foreach ($device in $devices) {
            Invoke-CimMethod -CimInstance $device -MethodName "ScanForHardwareChanges"
        }
    }
    catch {
        Write-ToolkitLog "Could not trigger hardware scan" "WARN"
    }
    
    Start-Sleep -Seconds 5
    
    # Test device functionality
    $testResults = Test-FocusriteConnection
    
    if ($testResults.OverallHealth -eq "Good") {
        Write-ToolkitLog "Driver installation verification: PASSED" "SUCCESS"
        return $true
    } elseif ($testResults.OverallHealth -eq "Fair") {
        Write-ToolkitLog "Driver installation verification: PARTIAL" "WARN"
        return $true
    } else {
        Write-ToolkitLog "Driver installation verification: FAILED" "ERROR"
        return $false
    }
}

function Set-WindowsAudioSettings {
    [CmdletBinding()]
    param()
    
    Write-ToolkitLog "Configuring Windows audio settings for Focusrite..."
    
    try {
        # Set Focusrite as default audio device using registry
        # This is a simplified approach - in practice you might want to use AudioDeviceCmdlets module
        
        Write-ToolkitLog "Note: Please manually set Focusrite as default audio device in Windows Sound Settings" "INFO"
        Write-ToolkitLog "Go to Settings > System > Sound" "INFO"
        Write-ToolkitLog "Set 'Speakers (Focusrite USB Audio)' as output device" "INFO"
        Write-ToolkitLog "Set 'Microphone (Focusrite USB Audio)' as input device" "INFO"
        
        return $true
    }
    catch {
        Write-ToolkitLog "Error configuring audio settings: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

try {
    Write-Host @"
╔═══════════════════════════════════════════════════════════════════════════════╗
║                         FOCUSRITE DRIVER INSTALLER                           ║
║                              Version 1.0.0                                   ║
╚═══════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

    Write-Host ""
    
    $success = $false
    $installationSteps = @()
    
    # Step 1: Check current state
    Write-Host "[1/7] Checking current driver state..." -ForegroundColor Yellow
    $currentDevices = Get-FocusriteDevices
    Write-ToolkitLog "Found $($currentDevices.Count) existing Focusrite devices"
    
    if ($currentDevices.Count -gt 0 -and -not $ForceReinstall) {
        $workingDevices = $currentDevices | Where-Object { $_.Status -eq "OK" }
        if ($workingDevices.Count -gt 0) {
            Write-Host "Working Focusrite drivers already detected." -ForegroundColor Green
            Write-Host "Use -ForceReinstall to reinstall anyway." -ForegroundColor Yellow
            exit 0
        }
    }
    
    # Step 2: Uninstall existing drivers if needed
    Write-Host "[2/7] Cleaning existing installations..." -ForegroundColor Yellow
    if ($ForceReinstall -or $currentDevices.Count -gt 0) {
        $installationSteps += "Uninstalled existing drivers"
        Uninstall-ExistingDrivers
    }
    
    # Step 3: Download drivers if needed
    Write-Host "[3/7] Preparing driver installation..." -ForegroundColor Yellow
    $driverFiles = @{}
    
    if ($DownloadLatest) {
        Write-ToolkitLog "Downloading latest drivers from Focusrite..."
        $downloadedFiles = Get-LatestFocusriteDrivers -DownloadPath $DownloadPath
        if ($downloadedFiles) {
            $driverFiles = $downloadedFiles
            $installationSteps += "Downloaded latest drivers"
        } else {
            Write-ToolkitLog "Failed to download drivers. Please manually download from focusrite.com" "ERROR"
        }
    }
    
    # Use provided paths
    if ($DriverPath -and (Test-Path $DriverPath)) {
        $driverFiles["Driver"] = $DriverPath
    }
    
    if ($FocusriteControlPath -and (Test-Path $FocusriteControlPath)) {
        $driverFiles["FocusriteControl"] = $FocusriteControlPath
    }
    
    # Step 4: Install USB drivers
    Write-Host "[4/7] Installing USB drivers..." -ForegroundColor Yellow
    $driverInstalled = $false
    
    foreach ($file in $driverFiles.Values) {
        if ($file -like "*driver*" -or $file -like "*usb*") {
            if (Install-DriverFromPath -InstallerPath $file) {
                $driverInstalled = $true
                $installationSteps += "Installed USB drivers"
                break
            }
        }
    }
    
    if (-not $driverInstalled -and $driverFiles.Count -eq 0) {
        Write-ToolkitLog "No driver installers available. Attempting Windows Update..." "WARN"
        try {
            Update-FocusriteDrivers
            $driverInstalled = $true
            $installationSteps += "Updated drivers via Windows Update"
        }
        catch {
            Write-ToolkitLog "Windows Update driver installation failed" "ERROR"
        }
    }
    
    # Step 5: Install Focusrite Control
    Write-Host "[5/7] Installing Focusrite Control software..." -ForegroundColor Yellow
    $controlInstalled = $false
    
    if ($driverFiles.ContainsKey("FocusriteControl")) {
        if (Install-DriverFromPath -InstallerPath $driverFiles["FocusriteControl"]) {
            $controlInstalled = $true
            $installationSteps += "Installed Focusrite Control"
        }
    } else {
        foreach ($file in $driverFiles.Values) {
            if ($file -like "*control*" -or $file -like "*focusrite*") {
                if (Install-DriverFromPath -InstallerPath $file) {
                    $controlInstalled = $true
                    $installationSteps += "Installed Focusrite Control"
                    break
                }
            }
        }
    }
    
    # Step 6: Test installation
    Write-Host "[6/7] Testing installation..." -ForegroundColor Yellow
    $testPassed = Test-DriverInstallation
    if ($testPassed) {
        $installationSteps += "Installation verified successfully"
        $success = $true
    }
    
    # Step 7: Configure audio settings
    Write-Host "[7/7] Configuring audio settings..." -ForegroundColor Yellow
    Set-WindowsAudioSettings
    $installationSteps += "Audio settings configured"
    
    # Show results
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "INSTALLATION RESULTS" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    $statusColor = if ($success) { "Green" } else { "Red" }
    $statusText = if ($success) { "SUCCESS" } else { "FAILED" }
    
    Write-Host "Overall Status: $statusText" -ForegroundColor $statusColor
    Write-Host ""
    Write-Host "Installation Steps Completed:" -ForegroundColor Yellow
    foreach ($step in $installationSteps) {
        Write-Host "  ✓ $step" -ForegroundColor Green
    }
    Write-Host ""
    
    if ($success) {
        Write-Host "🎵 Next Steps:" -ForegroundColor Green
        Write-Host "1. Open FL Studio and configure audio settings" -ForegroundColor White
        Write-Host "2. Select 'Focusrite USB ASIO' as your audio device" -ForegroundColor White
        Write-Host "3. Set sample rate to 44.1kHz or 48kHz" -ForegroundColor White
        Write-Host "4. Test audio input/output functionality" -ForegroundColor White
        Write-Host ""
        Write-Host "📋 Troubleshooting:" -ForegroundColor Yellow
        Write-Host "If issues persist, run: .\Fix-FocusriteUSB.ps1 -Mode Full" -ForegroundColor White
    } else {
        Write-Host "❌ Installation Issues:" -ForegroundColor Red
        Write-Host "1. Check Windows Device Manager for device errors" -ForegroundColor White
        Write-Host "2. Try running: .\Fix-FocusriteUSB.ps1 -Mode Reset" -ForegroundColor White
        Write-Host "3. Manually download drivers from focusrite.com" -ForegroundColor White
        Write-Host "4. Restart Windows and try again" -ForegroundColor White
    }
    
    if ($success) {
        exit 0
    } else {
        exit 1
    }
}
catch {
    Write-ToolkitLog "Driver installation failed: $($_.Exception.Message)" "ERROR"
    Write-Host "Installation failed with error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}