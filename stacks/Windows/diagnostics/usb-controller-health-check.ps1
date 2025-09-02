# USB Controller Health Verification PowerShell Script
# Comprehensive health check for USB controllers and hubs in Windows VM environment
# Focus on audio production setup with Focusrite and Arturia devices

[CmdletBinding()]
param(
    [switch]$FullReport,
    [switch]$BenchmarkMode,
    [string]$LogPath = "C:\Temp\usb-health-check.log",
    [int]$TestDuration = 60  # seconds for benchmark tests
)

# Initialize logging
function Write-LogMessage {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    })
    Add-Content -Path $LogPath -Value $logEntry -ErrorAction SilentlyContinue
}

Write-Host "=== USB Controller Health Verification Tool ===" -ForegroundColor Cyan
Write-LogMessage "Starting USB Controller Health Check"

# Create results object
$HealthResults = @{
    ControllerStatus = @()
    HubStatus = @()
    DeviceStatus = @()
    PerformanceMetrics = @()
    Recommendations = @()
    OverallHealth = "UNKNOWN"
}

# 1. USB CONTROLLER ENUMERATION AND HEALTH CHECK
Write-Host "`n1. USB Controller Analysis..." -ForegroundColor Green
Write-LogMessage "Analyzing USB controllers"

$USBControllers = Get-PnpDevice | Where-Object { 
    $_.Class -eq "USB" -and $_.FriendlyName -like "*Controller*" 
}

foreach ($controller in $USBControllers) {
    Write-Host "   Controller: $($controller.FriendlyName)" -ForegroundColor Cyan
    
    $controllerHealth = @{
        Name = $controller.FriendlyName
        Status = $controller.Status
        InstanceId = $controller.InstanceId
        Issues = @()
        Recommendations = @()
    }
    
    # Check controller status
    if ($controller.Status -eq "OK") {
        Write-Host "     Status: OK ✓" -ForegroundColor Green
    } else {
        Write-Host "     Status: $($controller.Status) ⚠" -ForegroundColor Red
        $controllerHealth.Issues += "Controller status: $($controller.Status)"
        $controllerHealth.Recommendations += "Investigate controller driver issues"
    }
    
    # Get detailed controller properties
    try {
        $controllerProps = Get-PnpDeviceProperty -InstanceId $controller.InstanceId -ErrorAction SilentlyContinue
        
        # Check for hardware errors
        $errorCount = ($controllerProps | Where-Object { $_.KeyName -eq "DEVPKEY_Device_ProblemCode" }).Data
        if ($errorCount -and $errorCount -ne 0) {
            Write-Host "     Problem Code: $errorCount" -ForegroundColor Red
            $controllerHealth.Issues += "Hardware problem code: $errorCount"
        }
        
        # Check driver date and version
        $driverDate = ($controllerProps | Where-Object { $_.KeyName -eq "DEVPKEY_Device_DriverDate" }).Data
        $driverVersion = ($controllerProps | Where-Object { $_.KeyName -eq "DEVPKEY_Device_DriverVersion" }).Data
        
        if ($driverDate) {
            Write-Host "     Driver Date: $driverDate" -ForegroundColor Gray
            
            # Check if driver is older than 2 years
            $driverAge = (Get-Date) - [DateTime]$driverDate
            if ($driverAge.Days -gt 730) {
                Write-Host "     WARNING: Driver is $([int]($driverAge.Days/365)) years old" -ForegroundColor Yellow
                $controllerHealth.Issues += "Outdated driver (over 2 years old)"
                $controllerHealth.Recommendations += "Update USB controller driver"
            }
        }
        
        if ($driverVersion) {
            Write-Host "     Driver Version: $driverVersion" -ForegroundColor Gray
        }
        
    } catch {
        Write-Host "     Could not retrieve controller properties" -ForegroundColor Yellow
    }
    
    $HealthResults.ControllerStatus += $controllerHealth
}

# 2. USB HUB ANALYSIS
Write-Host "`n2. USB Hub Analysis..." -ForegroundColor Green
Write-LogMessage "Analyzing USB hubs"

$USBHubs = Get-PnpDevice | Where-Object { 
    $_.Class -eq "USB" -and ($_.FriendlyName -like "*Hub*" -or $_.FriendlyName -like "*Root Hub*") 
}

foreach ($hub in $USBHubs) {
    Write-Host "   Hub: $($hub.FriendlyName)" -ForegroundColor Cyan
    
    $hubHealth = @{
        Name = $hub.FriendlyName
        Status = $hub.Status
        Type = if ($hub.FriendlyName -like "*Root*") { "Root Hub" } else { "External Hub" }
        Issues = @()
        ConnectedDevices = 0
    }
    
    # Check hub status
    if ($hub.Status -eq "OK") {
        Write-Host "     Status: OK ✓" -ForegroundColor Green
    } else {
        Write-Host "     Status: $($hub.Status) ⚠" -ForegroundColor Red
        $hubHealth.Issues += "Hub status: $($hub.Status)"
    }
    
    # Count connected devices (approximate)
    $connectedDevices = Get-PnpDevice | Where-Object { 
        $_.InstanceId -like "*USB*" -and $_.Status -eq "OK" 
    }
    $hubHealth.ConnectedDevices = $connectedDevices.Count
    Write-Host "     Estimated connected devices: $($connectedDevices.Count)" -ForegroundColor Gray
    
    $HealthResults.HubStatus += $hubHealth
}

# 3. CRITICAL DEVICE VERIFICATION
Write-Host "`n3. Critical Device Verification..." -ForegroundColor Green
Write-LogMessage "Verifying critical audio devices"

# Expected devices for audio production setup
$ExpectedDevices = @(
    @{ Name = "Focusrite*"; Type = "Audio Interface"; VendorId = "1235"; ProductId = "821A" },
    @{ Name = "Arturia*"; Type = "MIDI Controller"; VendorId = "1C75"; ProductId = "02CB" }
)

foreach ($expectedDevice in $ExpectedDevices) {
    $device = Get-PnpDevice | Where-Object { 
        $_.FriendlyName -like $expectedDevice.Name -and $_.Status -eq "OK" 
    }
    
    $deviceHealth = @{
        ExpectedName = $expectedDevice.Name
        Type = $expectedDevice.Type
        Found = $false
        ActualName = ""
        Status = ""
        Issues = @()
        Performance = @{}
    }
    
    if ($device) {
        $deviceHealth.Found = $true
        $deviceHealth.ActualName = $device.FriendlyName
        $deviceHealth.Status = $device.Status
        
        Write-Host "   ✓ $($expectedDevice.Type): $($device.FriendlyName)" -ForegroundColor Green
        
        # Additional device-specific checks
        if ($expectedDevice.Name -like "Focusrite*") {
            # Check audio endpoints
            $audioEndpoints = Get-PnpDevice | Where-Object { 
                $_.Class -eq "AudioEndpoint" -and $_.FriendlyName -like "*Focusrite*" 
            }
            Write-Host "     Audio endpoints: $($audioEndpoints.Count)" -ForegroundColor Gray
            
            if ($audioEndpoints.Count -eq 0) {
                $deviceHealth.Issues += "No audio endpoints found"
            }
        }
        
        # Check for driver issues
        try {
            $deviceProps = Get-PnpDeviceProperty -InstanceId $device.InstanceId -ErrorAction SilentlyContinue
            $problemCode = ($deviceProps | Where-Object { $_.KeyName -eq "DEVPKEY_Device_ProblemCode" }).Data
            
            if ($problemCode -and $problemCode -ne 0) {
                Write-Host "     WARNING: Problem code $problemCode" -ForegroundColor Yellow
                $deviceHealth.Issues += "Device problem code: $problemCode"
            }
        } catch {
            Write-Host "     Could not check device properties" -ForegroundColor Yellow
        }
        
    } else {
        $deviceHealth.Found = $false
        Write-Host "   ✗ $($expectedDevice.Type): NOT FOUND" -ForegroundColor Red
        $deviceHealth.Issues += "Device not detected in Windows"
    }
    
    $HealthResults.DeviceStatus += $deviceHealth
}

# 4. USB BANDWIDTH AND PERFORMANCE ANALYSIS
Write-Host "`n4. USB Performance Analysis..." -ForegroundColor Green
Write-LogMessage "Analyzing USB performance metrics"

$PerformanceMetrics = @{
    TotalUSBDevices = 0
    HighSpeedDevices = 0
    SuperSpeedDevices = 0
    BandwidthUtilization = "Unknown"
    Recommendations = @()
}

$AllUSBDevices = Get-PnpDevice | Where-Object { $_.InstanceId -like "*USB*" -and $_.Status -eq "OK" }
$PerformanceMetrics.TotalUSBDevices = $AllUSBDevices.Count

Write-Host "   Total USB devices: $($AllUSBDevices.Count)" -ForegroundColor Gray

# Analyze device speeds (basic heuristic based on device types)
$AudioDevices = $AllUSBDevices | Where-Object { 
    $_.FriendlyName -like "*Audio*" -or $_.FriendlyName -like "*Sound*" -or 
    $_.FriendlyName -like "*Focusrite*" -or $_.FriendlyName -like "*Arturia*" 
}

$StorageDevices = $AllUSBDevices | Where-Object { 
    $_.Class -eq "DiskDrive" -or $_.FriendlyName -like "*Storage*" 
}

Write-Host "   Audio devices: $($AudioDevices.Count)" -ForegroundColor Gray
Write-Host "   Storage devices: $($StorageDevices.Count)" -ForegroundColor Gray

# Performance recommendations
if ($AudioDevices.Count -gt 2) {
    $PerformanceMetrics.Recommendations += "Multiple audio devices detected - ensure sufficient USB bandwidth"
}

if ($AllUSBDevices.Count -gt 20) {
    $PerformanceMetrics.Recommendations += "High number of USB devices - consider using powered USB hubs"
}

$HealthResults.PerformanceMetrics = $PerformanceMetrics

# 5. USB POWER MANAGEMENT VERIFICATION
Write-Host "`n5. USB Power Management Check..." -ForegroundColor Green
Write-LogMessage "Checking USB power management settings"

try {
    # Check USB selective suspend
    $selectiveSuspend = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\USB" -Name "DisableSelectiveSuspend" -ErrorAction SilentlyContinue
    
    if ($selectiveSuspend) {
        if ($selectiveSuspend.DisableSelectiveSuspend -eq 1) {
            Write-Host "   ✓ USB Selective Suspend: DISABLED" -ForegroundColor Green
        } else {
            Write-Host "   ⚠ USB Selective Suspend: ENABLED" -ForegroundColor Yellow
            $HealthResults.Recommendations += "Disable USB Selective Suspend for audio production stability"
        }
    } else {
        Write-Host "   ? USB Selective Suspend setting not found" -ForegroundColor Yellow
    }
    
    # Check power policy settings
    $usbPowerSettings = powercfg /query SCHEME_CURRENT SUB_USBSETTINGS 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✓ USB power policy settings accessible" -ForegroundColor Green
    } else {
        Write-Host "   ? Could not query USB power settings" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "   Error checking power management: $($_.Exception.Message)" -ForegroundColor Red
}

# 6. BENCHMARK MODE (if requested)
if ($BenchmarkMode) {
    Write-Host "`n6. USB Performance Benchmarking..." -ForegroundColor Green
    Write-LogMessage "Starting USB performance benchmarks"
    
    Write-Host "   Running $TestDuration second stability test..." -ForegroundColor Yellow
    
    $startTime = Get-Date
    $errors = 0
    $deviceChecks = 0
    
    while ((Get-Date) -lt $startTime.AddSeconds($TestDuration)) {
        # Quick device enumeration to check for disconnections
        try {
            $currentDevices = Get-PnpDevice | Where-Object { 
                ($_.FriendlyName -like "*Focusrite*" -or $_.FriendlyName -like "*Arturia*") -and 
                $_.Status -eq "OK" 
            }
            $deviceChecks++
            
            if ($currentDevices.Count -lt 2) {
                $errors++
            }
            
            Start-Sleep -Milliseconds 1000
        } catch {
            $errors++
        }
    }
    
    $reliability = if ($deviceChecks -gt 0) { (($deviceChecks - $errors) / $deviceChecks) * 100 } else { 0 }
    
    Write-Host "   Stability Test Results:" -ForegroundColor Cyan
    Write-Host "     Test Duration: $TestDuration seconds" -ForegroundColor Gray
    Write-Host "     Device Checks: $deviceChecks" -ForegroundColor Gray
    Write-Host "     Errors: $errors" -ForegroundColor Gray
    Write-Host "     Reliability: $([Math]::Round($reliability, 2))%" -ForegroundColor $(if ($reliability -gt 95) { "Green" } elseif ($reliability -gt 85) { "Yellow" } else { "Red" })
    
    $HealthResults.PerformanceMetrics.Reliability = $reliability
    $HealthResults.PerformanceMetrics.TestDuration = $TestDuration
    $HealthResults.PerformanceMetrics.Errors = $errors
}

# 7. OVERALL HEALTH ASSESSMENT
Write-Host "`n=== OVERALL HEALTH ASSESSMENT ===" -ForegroundColor Cyan

$criticalIssues = 0
$warnings = 0
$recommendations = @()

# Count issues
$HealthResults.ControllerStatus | ForEach-Object { $criticalIssues += $_.Issues.Count }
$HealthResults.HubStatus | ForEach-Object { $criticalIssues += $_.Issues.Count }
$HealthResults.DeviceStatus | ForEach-Object { 
    if (-not $_.Found) { $criticalIssues++ }
    $criticalIssues += $_.Issues.Count 
}

# Determine overall health
if ($criticalIssues -eq 0) {
    $HealthResults.OverallHealth = "EXCELLENT"
    Write-Host "Overall USB Health: EXCELLENT ✓" -ForegroundColor Green
} elseif ($criticalIssues -lt 3) {
    $HealthResults.OverallHealth = "GOOD"
    Write-Host "Overall USB Health: GOOD ⚠" -ForegroundColor Yellow
} elseif ($criticalIssues -lt 5) {
    $HealthResults.OverallHealth = "FAIR"
    Write-Host "Overall USB Health: FAIR ⚠" -ForegroundColor Yellow
} else {
    $HealthResults.OverallHealth = "POOR"
    Write-Host "Overall USB Health: POOR ✗" -ForegroundColor Red
}

Write-Host "Critical Issues: $criticalIssues" -ForegroundColor $(if ($criticalIssues -eq 0) { "Green" } else { "Red" })

# Compile recommendations
$allRecommendations = @()
$HealthResults.ControllerStatus | ForEach-Object { $allRecommendations += $_.Recommendations }
$HealthResults.DeviceStatus | ForEach-Object { $allRecommendations += $_.Issues }
$allRecommendations += $HealthResults.PerformanceMetrics.Recommendations
$allRecommendations += $HealthResults.Recommendations

$uniqueRecommendations = $allRecommendations | Select-Object -Unique | Where-Object { $_ -ne "" }

if ($uniqueRecommendations.Count -gt 0) {
    Write-Host "`nTop Recommendations:" -ForegroundColor White
    $uniqueRecommendations | Select-Object -First 5 | ForEach-Object {
        Write-Host "  • $_" -ForegroundColor Gray
    }
}

# 8. FULL REPORT (if requested)
if ($FullReport) {
    Write-Host "`n=== DETAILED HEALTH REPORT ===" -ForegroundColor Cyan
    
    $reportPath = $LogPath -replace '\.log$', '-full-report.json'
    try {
        $HealthResults | ConvertTo-Json -Depth 3 | Out-File -FilePath $reportPath -Encoding UTF8
        Write-Host "Full report saved to: $reportPath" -ForegroundColor Green
        
        # Also create human-readable report
        $readablePath = $reportPath -replace '\.json$', '.txt'
        @"
USB Controller Health Check Report
Generated: $(Get-Date)
Computer: $env:COMPUTERNAME
Overall Health: $($HealthResults.OverallHealth)

=== CONTROLLERS ===
$($HealthResults.ControllerStatus | ForEach-Object {
    "Name: $($_.Name)"
    "Status: $($_.Status)"
    if ($_.Issues.Count -gt 0) { "Issues: $($_.Issues -join '; ')" }
    if ($_.Recommendations.Count -gt 0) { "Recommendations: $($_.Recommendations -join '; ')" }
    ""
} | Out-String)

=== HUBS ===
$($HealthResults.HubStatus | ForEach-Object {
    "Name: $($_.Name)"
    "Status: $($_.Status)"
    "Type: $($_.Type)"
    "Connected Devices: $($_.ConnectedDevices)"
    if ($_.Issues.Count -gt 0) { "Issues: $($_.Issues -join '; ')" }
    ""
} | Out-String)

=== CRITICAL DEVICES ===
$($HealthResults.DeviceStatus | ForEach-Object {
    "Expected: $($_.ExpectedName) ($($_.Type))"
    "Found: $(if ($_.Found) { 'YES - ' + $_.ActualName } else { 'NO' })"
    if ($_.Issues.Count -gt 0) { "Issues: $($_.Issues -join '; ')" }
    ""
} | Out-String)

=== PERFORMANCE METRICS ===
Total USB Devices: $($HealthResults.PerformanceMetrics.TotalUSBDevices)
$(if ($HealthResults.PerformanceMetrics.Reliability) { "Reliability: $($HealthResults.PerformanceMetrics.Reliability)%" })
$(if ($HealthResults.PerformanceMetrics.Recommendations) { "Recommendations: $($HealthResults.PerformanceMetrics.Recommendations -join '; ')" })

=== RECOMMENDATIONS ===
$($uniqueRecommendations -join "`n")
"@ | Out-File -FilePath $readablePath -Encoding UTF8
        
        Write-Host "Human-readable report saved to: $readablePath" -ForegroundColor Green
    } catch {
        Write-Host "Failed to save full report: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-LogMessage "USB Controller Health Check completed with $criticalIssues critical issues" $(if ($criticalIssues -gt 0) { "WARNING" } else { "SUCCESS" })
Write-Host "`nHealth check completed. Run with -FullReport for detailed output." -ForegroundColor Cyan
Write-Host "Run with -BenchmarkMode for performance stability testing." -ForegroundColor Gray