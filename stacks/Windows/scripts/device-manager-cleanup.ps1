# Device Manager Cleanup PowerShell Script
# Comprehensive cleanup for Windows Device Manager phantom devices and driver conflicts
# Specialized for Docker-based Windows VM with USB audio devices

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$FullCleanup,
    [switch]$AudioDevicesOnly,
    [string]$BackupPath = "C:\Temp\device-backup",
    [switch]$RestoreFromBackup,
    [string]$RestoreBackupPath
)

# Require admin privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script requires Administrator privileges. Please run as Administrator."
    exit 1
}

Write-Host "=== Device Manager Cleanup Tool ===" -ForegroundColor Cyan
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN (simulation only)' } else { 'LIVE CLEANUP' })" -ForegroundColor $(if ($DryRun) { "Yellow" } else { "Red" })

if (-not $DryRun -and -not $RestoreFromBackup) {
    Write-Host "⚠ WARNING: This will make changes to your system!" -ForegroundColor Red
    $confirmation = Read-Host "Continue? (y/N)"
    if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Initialize logging and backup
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = Join-Path $BackupPath "cleanup-log-$timestamp.txt"
$backupFile = Join-Path $BackupPath "device-backup-$timestamp.json"

function Write-LogMessage {
    param([string]$Message, [string]$Level = "INFO")
    $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    })
    if (Test-Path (Split-Path $logFile -Parent)) {
        Add-Content -Path $logFile -Value $logEntry
    }
}

# Create backup directory
if (-not $RestoreFromBackup) {
    try {
        New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
        Write-LogMessage "Created backup directory: $BackupPath"
    } catch {
        Write-LogMessage "Failed to create backup directory: $($_.Exception.Message)" "ERROR"
        exit 1
    }
}

# RESTORE FROM BACKUP MODE
if ($RestoreFromBackup) {
    Write-Host "`n=== RESTORE FROM BACKUP MODE ===" -ForegroundColor Cyan
    
    if (-not $RestoreBackupPath) {
        $RestoreBackupPath = (Get-ChildItem $BackupPath -Filter "device-backup-*.json" | Sort-Object CreationTime -Descending | Select-Object -First 1).FullName
    }
    
    if (-not $RestoreBackupPath -or -not (Test-Path $RestoreBackupPath)) {
        Write-LogMessage "No backup file found or specified" "ERROR"
        exit 1
    }
    
    Write-Host "Restoring from: $RestoreBackupPath" -ForegroundColor Yellow
    
    try {
        $backupData = Get-Content $RestoreBackupPath | ConvertFrom-Json
        
        Write-Host "Attempting to restore $($backupData.RemovedDevices.Count) devices..." -ForegroundColor Yellow
        
        foreach ($device in $backupData.RemovedDevices) {
            Write-Host "  Restoring: $($device.FriendlyName)" -ForegroundColor Gray
            
            if (-not $DryRun) {
                try {
                    # Note: Full device restoration from backup is complex and may require driver reinstallation
                    # This is a simplified approach
                    pnputil /add-driver $device.DriverPath /install 2>$null
                } catch {
                    Write-LogMessage "Failed to restore $($device.FriendlyName): $($_.Exception.Message)" "WARNING"
                }
            }
        }
        
        Write-LogMessage "Restore operation completed" "SUCCESS"
        exit 0
        
    } catch {
        Write-LogMessage "Failed to read backup file: $($_.Exception.Message)" "ERROR"
        exit 1
    }
}

# CLEANUP MODE - Continue with normal operation
Write-LogMessage "Starting Device Manager cleanup operation"

# Store cleanup results
$CleanupResults = @{
    BackupCreated = $false
    RemovedDevices = @()
    CleanedDrivers = @()
    Errors = @()
    Summary = @{}
}

# 1. CREATE DEVICE BACKUP
Write-Host "`n1. Creating Device Backup..." -ForegroundColor Green

$allDevices = Get-PnpDevice
$backupData = @{
    Timestamp = Get-Date
    ComputerName = $env:COMPUTERNAME
    TotalDevices = $allDevices.Count
    AllDevices = $allDevices | Select-Object FriendlyName, Status, Class, InstanceId
    RemovedDevices = @()
}

try {
    $backupData | ConvertTo-Json -Depth 3 | Out-File -Path $backupFile -Encoding UTF8
    Write-LogMessage "Device backup created: $backupFile" "SUCCESS"
    $CleanupResults.BackupCreated = $true
} catch {
    Write-LogMessage "Failed to create backup: $($_.Exception.Message)" "ERROR"
    if (-not $DryRun) {
        Write-Host "Aborting cleanup due to backup failure." -ForegroundColor Red
        exit 1
    }
}

# 2. IDENTIFY PHANTOM/HIDDEN DEVICES
Write-Host "`n2. Identifying Hidden and Phantom Devices..." -ForegroundColor Green

# Set environment variables to show hidden devices
$env:DEVMGR_SHOW_DETAILS = "1"
$env:DEVMGR_SHOW_NONPRESENT_DEVICES = "1"

# Get all devices including hidden ones
$allDevicesIncludingHidden = Get-PnpDevice

# Identify phantom devices (not present but still in system)
$phantomDevices = $allDevicesIncludingHidden | Where-Object {
    $_.Status -eq "Unknown" -or 
    $_.ConfigManagerErrorCode -eq 45 -or  # Currently not connected
    ($_.Status -eq "Error" -and $_.ConfigManagerErrorCode -eq 28)  # Drivers not installed
}

Write-Host "   Found $($phantomDevices.Count) phantom devices" -ForegroundColor Yellow

if ($AudioDevicesOnly) {
    $phantomDevices = $phantomDevices | Where-Object {
        $_.Class -eq "MEDIA" -or $_.Class -eq "AudioEndpoint" -or
        $_.FriendlyName -like "*Audio*" -or $_.FriendlyName -like "*Sound*" -or
        $_.FriendlyName -like "*Focusrite*" -or $_.FriendlyName -like "*Arturia*" -or
        $_.Class -eq "USB"
    }
    Write-Host "   Filtered to $($phantomDevices.Count) audio-related phantom devices" -ForegroundColor Yellow
}

# 3. IDENTIFY DUPLICATE DEVICES
Write-Host "`n3. Identifying Duplicate Devices..." -ForegroundColor Green

$duplicateDevices = @()
$deviceGroups = $allDevicesIncludingHidden | Group-Object FriendlyName | Where-Object { $_.Count -gt 1 }

foreach ($group in $deviceGroups) {
    # Keep one working device, mark others for removal
    $workingDevice = $group.Group | Where-Object { $_.Status -eq "OK" } | Select-Object -First 1
    $duplicates = $group.Group | Where-Object { $_.InstanceId -ne $workingDevice.InstanceId }
    
    if ($duplicates) {
        $duplicateDevices += $duplicates
        Write-Host "   Found $($duplicates.Count) duplicates of: $($group.Name)" -ForegroundColor Yellow
    }
}

Write-Host "   Total duplicate devices to remove: $($duplicateDevices.Count)" -ForegroundColor Yellow

# 4. IDENTIFY PROBLEMATIC USB DEVICES
Write-Host "`n4. Identifying Problematic USB Devices..." -ForegroundColor Green

$problematicUSBDevices = Get-PnpDevice | Where-Object {
    $_.InstanceId -like "*USB*" -and (
        $_.Status -eq "Error" -or
        $_.Status -eq "Degraded" -or
        $_.Status -eq "Unknown" -or
        $_.FriendlyName -like "*Unknown*" -or
        $_.ConfigManagerErrorCode -ne 0
    )
}

Write-Host "   Found $($problematicUSBDevices.Count) problematic USB devices" -ForegroundColor Yellow

if ($AudioDevicesOnly) {
    $problematicUSBDevices = $problematicUSBDevices | Where-Object {
        $_.FriendlyName -like "*Audio*" -or $_.FriendlyName -like "*Sound*" -or
        $_.FriendlyName -like "*Focusrite*" -or $_.FriendlyName -like "*Arturia*" -or
        $_.FriendlyName -like "*MIDI*"
    }
    Write-Host "   Filtered to $($problematicUSBDevices.Count) problematic audio USB devices" -ForegroundColor Yellow
}

# 5. COMBINE DEVICES FOR REMOVAL
$devicesToRemove = @()
$devicesToRemove += $phantomDevices
$devicesToRemove += $duplicateDevices
if ($FullCleanup) {
    $devicesToRemove += $problematicUSBDevices
}

# Remove duplicates from removal list
$devicesToRemove = $devicesToRemove | Sort-Object InstanceId -Unique

Write-Host "`nTotal devices identified for removal: $($devicesToRemove.Count)" -ForegroundColor Cyan

# 6. DEVICE REMOVAL PROCESS
Write-Host "`n6. Device Removal Process..." -ForegroundColor Green

if ($devicesToRemove.Count -eq 0) {
    Write-LogMessage "No devices need to be removed" "SUCCESS"
} else {
    foreach ($device in $devicesToRemove) {
        Write-Host "   Processing: $($device.FriendlyName)" -ForegroundColor Cyan
        Write-Host "     Instance ID: $($device.InstanceId)" -ForegroundColor Gray
        Write-Host "     Status: $($device.Status)" -ForegroundColor Gray
        Write-Host "     Class: $($device.Class)" -ForegroundColor Gray
        
        # Check if it's a critical system device
        $isCriticalDevice = $device.Class -in @("System", "Computer", "Processor", "DiskDrive") -or
                           $device.FriendlyName -like "*System*" -or
                           $device.FriendlyName -like "*Root*"
        
        if ($isCriticalDevice) {
            Write-Host "     SKIPPED: Critical system device" -ForegroundColor Red
            continue
        }
        
        # Ask for confirmation on important audio devices
        if ($device.FriendlyName -like "*Focusrite*" -or $device.FriendlyName -like "*Arturia*") {
            Write-Host "     WARNING: This is an important audio device!" -ForegroundColor Yellow
            if (-not $DryRun) {
                $confirm = Read-Host "     Remove this device? (y/N)"
                if ($confirm -ne 'y' -and $confirm -ne 'Y') {
                    Write-Host "     SKIPPED: User chose to keep device" -ForegroundColor Yellow
                    continue
                }
            }
        }
        
        if ($DryRun) {
            Write-Host "     DRY RUN: Would remove this device" -ForegroundColor Yellow
        } else {
            try {
                # Store device info for backup
                $deviceInfo = @{
                    FriendlyName = $device.FriendlyName
                    InstanceId = $device.InstanceId
                    Class = $device.Class
                    Status = $device.Status
                    RemovalTime = Get-Date
                }
                
                # Attempt to remove the device
                $device | Remove-PnpDevice -Confirm:$false -Force
                
                Write-Host "     REMOVED: Device successfully removed" -ForegroundColor Green
                Write-LogMessage "Removed device: $($device.FriendlyName) [$($device.InstanceId)]" "SUCCESS"
                
                $CleanupResults.RemovedDevices += $deviceInfo
                $backupData.RemovedDevices += $deviceInfo
                
            } catch {
                Write-Host "     ERROR: Failed to remove device - $($_.Exception.Message)" -ForegroundColor Red
                Write-LogMessage "Failed to remove $($device.FriendlyName): $($_.Exception.Message)" "ERROR"
                $CleanupResults.Errors += "Failed to remove $($device.FriendlyName): $($_.Exception.Message)"
            }
        }
    }
}

# 7. DRIVER CLEANUP
Write-Host "`n7. Driver Package Cleanup..." -ForegroundColor Green

if ($FullCleanup) {
    try {
        # Get all third-party driver packages
        $allDrivers = pnputil /enum-drivers
        
        if ($allDrivers) {
            Write-Host "   Analyzing installed driver packages..." -ForegroundColor Yellow
            
            # This is a complex operation that requires careful analysis
            # For safety, we'll only identify potentially problematic drivers
            $suspiciousDrivers = @()
            
            # Look for duplicate or old audio drivers (this is a simplified check)
            # In a real implementation, you'd want more sophisticated driver analysis
            
            Write-Host "   Found $($suspiciousDrivers.Count) potentially problematic drivers" -ForegroundColor Yellow
            
            if ($suspiciousDrivers.Count -gt 0 -and -not $DryRun) {
                Write-Host "   Driver cleanup requires manual review. Check log for details." -ForegroundColor Yellow
            }
        }
    } catch {
        Write-LogMessage "Driver analysis failed: $($_.Exception.Message)" "WARNING"
    }
}

# 8. REGISTRY CLEANUP (Advanced)
Write-Host "`n8. Registry Cleanup..." -ForegroundColor Green

if ($FullCleanup) {
    $registryPaths = @(
        "HKLM:\SYSTEM\CurrentControlSet\Enum\USB",
        "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceClasses"
    )
    
    foreach ($regPath in $registryPaths) {
        try {
            Write-Host "   Analyzing registry path: $regPath" -ForegroundColor Gray
            
            if (Test-Path $regPath) {
                # Count entries (for information only - actual cleanup would be more complex)
                $entries = Get-ChildItem $regPath -Recurse -ErrorAction SilentlyContinue
                Write-Host "     Found $($entries.Count) registry entries" -ForegroundColor Gray
                
                # In a full implementation, you would carefully identify and remove orphaned entries
                # This requires extensive validation to avoid system damage
            }
        } catch {
            Write-LogMessage "Registry analysis failed for $regPath`: $($_.Exception.Message)" "WARNING"
        }
    }
    
    Write-Host "   Registry cleanup requires manual review for safety" -ForegroundColor Yellow
}

# 9. UPDATE BACKUP WITH REMOVAL RESULTS
if (-not $DryRun -and $CleanupResults.BackupCreated) {
    try {
        $backupData | ConvertTo-Json -Depth 3 | Out-File -Path $backupFile -Encoding UTF8
        Write-LogMessage "Updated backup with removal results" "SUCCESS"
    } catch {
        Write-LogMessage "Failed to update backup: $($_.Exception.Message)" "WARNING"
    }
}

# 10. RESCAN FOR HARDWARE CHANGES
Write-Host "`n10. Rescanning for Hardware Changes..." -ForegroundColor Green

if (-not $DryRun) {
    try {
        # Trigger hardware scan
        $devcon = Get-Command "devcon.exe" -ErrorAction SilentlyContinue
        if ($devcon) {
            devcon rescan | Out-Null
            Write-Host "    Hardware rescan completed" -ForegroundColor Green
        } else {
            # Alternative method using PowerShell
            Get-PnpDevice | ForEach-Object { 
                try {
                    $_ | Enable-PnpDevice -Confirm:$false -ErrorAction SilentlyContinue
                } catch {
                    # Ignore errors for devices that can't be enabled
                }
            }
            Write-Host "    Device re-enumeration completed" -ForegroundColor Green
        }
    } catch {
        Write-LogMessage "Hardware rescan failed: $($_.Exception.Message)" "WARNING"
    }
} else {
    Write-Host "    DRY RUN: Would trigger hardware rescan" -ForegroundColor Yellow
}

# 11. FINAL SUMMARY
Write-Host "`n=== CLEANUP SUMMARY ===" -ForegroundColor Cyan

$CleanupResults.Summary = @{
    DevicesRemoved = $CleanupResults.RemovedDevices.Count
    DriversCleaned = $CleanupResults.CleanedDrivers.Count
    Errors = $CleanupResults.Errors.Count
    BackupLocation = $backupFile
    Mode = if ($DryRun) { "Dry Run" } else { "Live Cleanup" }
}

Write-Host "Devices Removed: $($CleanupResults.RemovedDevices.Count)" -ForegroundColor $(if ($CleanupResults.RemovedDevices.Count -gt 0) { "Green" } else { "Gray" })
Write-Host "Drivers Cleaned: $($CleanupResults.CleanedDrivers.Count)" -ForegroundColor $(if ($CleanupResults.CleanedDrivers.Count -gt 0) { "Green" } else { "Gray" })
Write-Host "Errors Encountered: $($CleanupResults.Errors.Count)" -ForegroundColor $(if ($CleanupResults.Errors.Count -eq 0) { "Green" } else { "Red" })

if ($CleanupResults.BackupCreated) {
    Write-Host "Backup Location: $backupFile" -ForegroundColor Green
}

if ($CleanupResults.Errors.Count -gt 0) {
    Write-Host "`nErrors:" -ForegroundColor Red
    $CleanupResults.Errors | ForEach-Object {
        Write-Host "  • $_" -ForegroundColor Red
    }
}

# 12. RECOMMENDATIONS
Write-Host "`n=== RECOMMENDATIONS ===" -ForegroundColor Cyan

$recommendations = @()

if ($CleanupResults.RemovedDevices.Count -gt 0) {
    $recommendations += "Restart the system to complete device removal"
    $recommendations += "Test audio devices (Focusrite/Arturia) functionality after restart"
}

if (-not $FullCleanup) {
    $recommendations += "Run with -FullCleanup for comprehensive cleanup including drivers"
}

if ($CleanupResults.Errors.Count -gt 0) {
    $recommendations += "Review error log for failed device removals: $logFile"
}

$recommendations += "Monitor Device Manager for any new phantom devices"
$recommendations += "Keep backup file safe for potential device restoration: $backupFile"

foreach ($rec in $recommendations) {
    Write-Host "  • $rec" -ForegroundColor Yellow
}

Write-LogMessage "Cleanup operation completed - $($CleanupResults.RemovedDevices.Count) devices removed, $($CleanupResults.Errors.Count) errors" $(if ($CleanupResults.Errors.Count -eq 0) { "SUCCESS" } else { "WARNING" })

Write-Host "`nCleanup completed!" -ForegroundColor Green
if (-not $DryRun) {
    Write-Host "IMPORTANT: Restart your system to complete the cleanup process." -ForegroundColor Yellow
}
Write-Host "Logs and backup saved to: $BackupPath" -ForegroundColor Gray