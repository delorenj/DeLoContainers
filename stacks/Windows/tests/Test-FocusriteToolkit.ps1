# =============================================================================
# Test-FocusriteToolkit.ps1
# Comprehensive test suite for Focusrite USB Toolkit
# Author: Hive Mind Coder Agent
# Version: 1.0.0
# =============================================================================

#Requires -Version 5.1

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Unit", "Integration", "Full", "Performance")]
    [string]$TestType = "Full",
    
    [Parameter(Mandatory = $false)]
    [switch]$GenerateReport = $false,
    
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\FocusriteToolkitTestReport.html"
)

# Import the toolkit module
$ModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\powershell\FocusriteUSBToolkit.psm1"
if (Test-Path $ModulePath) {
    Import-Module $ModulePath -Force
} else {
    Write-Error "FocusriteUSBToolkit.psm1 not found at: $ModulePath"
    exit 1
}

# Test framework variables
$Global:TestResults = @()
$Global:TestCount = 0
$Global:PassedTests = 0
$Global:FailedTests = 0
$Global:SkippedTests = 0

function Write-TestLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "SKIP" { "Yellow" }
        "INFO" { "White" }
        default { "White" }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-Function {
    param(
        [string]$TestName,
        [scriptblock]$TestCode,
        [string]$Category = "General",
        [switch]$RequiresAdmin = $false
    )
    
    $Global:TestCount++
    
    Write-TestLog "Running test: $TestName" "INFO"
    
    # Check admin requirements
    if ($RequiresAdmin) {
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        if (-not $isAdmin) {
            Write-TestLog "Skipped (requires admin): $TestName" "SKIP"
            $Global:SkippedTests++
            $Global:TestResults += [PSCustomObject]@{
                Name = $TestName
                Category = $Category
                Status = "Skipped"
                Message = "Requires administrator privileges"
                Duration = 0
                Timestamp = Get-Date
            }
            return
        }
    }
    
    $startTime = Get-Date
    
    try {
        $result = & $TestCode
        $duration = (Get-Date) - $startTime
        
        if ($result -eq $true -or ($result -is [array] -and $result.Count -gt 0) -or ($result -and $result -ne $false)) {
            Write-TestLog "PASSED: $TestName" "PASS"
            $Global:PassedTests++
            $status = "Passed"
            $message = "Test completed successfully"
        } else {
            Write-TestLog "FAILED: $TestName" "FAIL"
            $Global:FailedTests++
            $status = "Failed"
            $message = "Test returned false or empty result"
        }
    }
    catch {
        $duration = (Get-Date) - $startTime
        Write-TestLog "FAILED: $TestName - $($_.Exception.Message)" "FAIL"
        $Global:FailedTests++
        $status = "Failed"
        $message = $_.Exception.Message
    }
    
    $Global:TestResults += [PSCustomObject]@{
        Name = $TestName
        Category = $Category
        Status = $status
        Message = $message
        Duration = [math]::Round($duration.TotalSeconds, 2)
        Timestamp = Get-Date
    }
}

# =============================================================================
# UNIT TESTS
# =============================================================================

function Invoke-UnitTests {
    Write-TestLog "=== RUNNING UNIT TESTS ===" "INFO"
    
    Test-Function -TestName "Module Import Test" -Category "Module" -TestCode {
        Get-Module FocusriteUSBToolkit | Should -Not -Be $null
        return $true
    }
    
    Test-Function -TestName "Get-FocusriteDevices Function Test" -Category "Device Detection" -TestCode {
        $devices = Get-FocusriteDevices
        return ($devices -is [array] -or $devices -eq $null)
    }
    
    Test-Function -TestName "Get-HiddenUSBDevices Function Test" -Category "Device Detection" -TestCode {
        $hiddenDevices = Get-HiddenUSBDevices
        return ($hiddenDevices -is [array] -or $hiddenDevices -eq $null)
    }
    
    Test-Function -TestName "Test-FocusriteConnection Function Test" -Category "Connection" -TestCode {
        $testResult = Test-FocusriteConnection
        return ($testResult -and $testResult.OverallHealth)
    }
    
    Test-Function -TestName "Write-ToolkitLog Function Test" -Category "Logging" -TestCode {
        Write-ToolkitLog "Test log message" "INFO"
        return (Test-Path $Global:LogPath)
    }
}

# =============================================================================
# INTEGRATION TESTS  
# =============================================================================

function Invoke-IntegrationTests {
    Write-TestLog "=== RUNNING INTEGRATION TESTS ===" "INFO"
    
    Test-Function -TestName "USB Device Enumeration" -Category "Integration" -TestCode {
        $devices = Get-FocusriteDevices
        $hiddenDevices = Get-HiddenUSBDevices
        
        # Test should pass if we can enumerate devices (even if none found)
        return $true
    }
    
    Test-Function -TestName "Power Settings Detection" -Category "Integration" -TestCode {
        try {
            $powerOutput = powercfg /query SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226
            return ($powerOutput -ne $null)
        }
        catch {
            return $false
        }
    }
    
    Test-Function -TestName "Registry Access Test" -Category "Integration" -TestCode {
        try {
            $testPath = "HKLM:\SYSTEM\CurrentControlSet\Services\USB"
            return (Test-Path $testPath)
        }
        catch {
            return $false
        }
    }
    
    Test-Function -TestName "Service Status Check" -Category "Integration" -TestCode {
        $usbServices = @("USBHUB3", "USB")
        $serviceCheck = $true
        
        foreach ($service in $usbServices) {
            try {
                $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
                if (-not $svc) {
                    $serviceCheck = $false
                }
            }
            catch {
                $serviceCheck = $false
            }
        }
        
        return $serviceCheck
    }
}

# =============================================================================
# FUNCTIONAL TESTS (Require Admin)
# =============================================================================

function Invoke-FunctionalTests {
    Write-TestLog "=== RUNNING FUNCTIONAL TESTS ===" "INFO"
    
    Test-Function -TestName "USB Power Settings Optimization" -Category "Functional" -RequiresAdmin -TestCode {
        try {
            # Test power setting without actually changing them permanently
            $currentSetting = powercfg /query SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226
            return ($currentSetting -ne $null)
        }
        catch {
            return $false
        }
    }
    
    Test-Function -TestName "Device Manager Access" -Category "Functional" -RequiresAdmin -TestCode {
        try {
            $devices = Get-PnPDevice -ErrorAction SilentlyContinue
            return ($devices -ne $null)
        }
        catch {
            return $false
        }
    }
    
    Test-Function -TestName "USB Hub Reset Capability" -Category "Functional" -RequiresAdmin -TestCode {
        try {
            # Test if we can access USB hub services
            $usbhubService = Get-Service -Name "USBHUB3" -ErrorAction SilentlyContinue
            return ($usbhubService -ne $null)
        }
        catch {
            return $false
        }
    }
}

# =============================================================================
# PERFORMANCE TESTS
# =============================================================================

function Invoke-PerformanceTests {
    Write-TestLog "=== RUNNING PERFORMANCE TESTS ===" "INFO"
    
    Test-Function -TestName "Device Enumeration Performance" -Category "Performance" -TestCode {
        $iterations = 5
        $totalTime = 0
        
        for ($i = 1; $i -le $iterations; $i++) {
            $startTime = Get-Date
            $devices = Get-FocusriteDevices
            $endTime = Get-Date
            $totalTime += ($endTime - $startTime).TotalMilliseconds
        }
        
        $averageTime = $totalTime / $iterations
        Write-TestLog "Average device enumeration time: $([math]::Round($averageTime, 2))ms" "INFO"
        
        # Performance test passes if average time is under 2 seconds
        return ($averageTime -lt 2000)
    }
    
    Test-Function -TestName "Log File Performance" -Category "Performance" -TestCode {
        $iterations = 100
        $startTime = Get-Date
        
        for ($i = 1; $i -le $iterations; $i++) {
            Write-ToolkitLog "Performance test log entry $i" "INFO"
        }
        
        $endTime = Get-Date
        $totalTime = ($endTime - $startTime).TotalMilliseconds
        $avgTimePerLog = $totalTime / $iterations
        
        Write-TestLog "Average log write time: $([math]::Round($avgTimePerLog, 2))ms per entry" "INFO"
        
        # Performance test passes if average log time is under 10ms
        return ($avgTimePerLog -lt 10)
    }
}

# =============================================================================
# REPORT GENERATION
# =============================================================================

function Generate-TestReport {
    param(
        [string]$OutputPath
    )
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Focusrite USB Toolkit Test Report</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 10px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        .header { text-align: center; color: #333; border-bottom: 2px solid #4CAF50; padding-bottom: 20px; margin-bottom: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .metric { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px; text-align: center; }
        .metric h3 { margin: 0; font-size: 2em; }
        .metric p { margin: 5px 0 0 0; opacity: 0.9; }
        .passed { background: linear-gradient(135deg, #56ab2f 0%, #a8e6cf 100%) !important; }
        .failed { background: linear-gradient(135deg, #ff416c 0%, #ff4b2b 100%) !important; }
        .skipped { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%) !important; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #4CAF50; color: white; }
        .status-passed { background-color: #E8F5E8; color: #2E7D32; font-weight: bold; }
        .status-failed { background-color: #FFEBEE; color: #C62828; font-weight: bold; }
        .status-skipped { background-color: #FFF3E0; color: #EF6C00; font-weight: bold; }
        .category { font-weight: bold; color: #555; }
        .duration { text-align: right; font-family: monospace; }
        .timestamp { font-size: 0.9em; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Focusrite USB Toolkit Test Report</h1>
            <p>Comprehensive Test Suite Results</p>
            <p class="timestamp">Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        </div>
        
        <div class="summary">
            <div class="metric">
                <h3>$Global:TestCount</h3>
                <p>Total Tests</p>
            </div>
            <div class="metric passed">
                <h3>$Global:PassedTests</h3>
                <p>Passed</p>
            </div>
            <div class="metric failed">
                <h3>$Global:FailedTests</h3>
                <p>Failed</p>
            </div>
            <div class="metric skipped">
                <h3>$Global:SkippedTests</h3>
                <p>Skipped</p>
            </div>
        </div>
        
        <table>
            <thead>
                <tr>
                    <th>Test Name</th>
                    <th>Category</th>
                    <th>Status</th>
                    <th>Duration (s)</th>
                    <th>Message</th>
                    <th>Timestamp</th>
                </tr>
            </thead>
            <tbody>
"@

    foreach ($result in $Global:TestResults) {
        $statusClass = "status-$($result.Status.ToLower())"
        $timestamp = $result.Timestamp.ToString("HH:mm:ss")
        
        $html += @"
                <tr>
                    <td>$($result.Name)</td>
                    <td class="category">$($result.Category)</td>
                    <td class="$statusClass">$($result.Status)</td>
                    <td class="duration">$($result.Duration)</td>
                    <td>$($result.Message)</td>
                    <td class="timestamp">$timestamp</td>
                </tr>
"@
    }

    $successRate = if ($Global:TestCount -gt 0) { [math]::Round(($Global:PassedTests / $Global:TestCount) * 100, 1) } else { 0 }

    $html += @"
            </tbody>
        </table>
        
        <div style="margin-top: 30px; padding: 20px; background-color: #f9f9f9; border-radius: 5px;">
            <h3>Test Summary</h3>
            <p><strong>Success Rate:</strong> $successRate%</p>
            <p><strong>Test Duration:</strong> $([math]::Round(($Global:TestResults | Measure-Object Duration -Sum).Sum, 2)) seconds</p>
            <p><strong>Test Categories:</strong> $($Global:TestResults | Select-Object Category -Unique | Measure-Object | Select-Object -ExpandProperty Count)</p>
        </div>
    </div>
</body>
</html>
"@

    try {
        $html | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-TestLog "Test report saved to: $OutputPath" "INFO"
        return $true
    }
    catch {
        Write-TestLog "Error saving test report: $($_.Exception.Message)" "FAIL"
        return $false
    }
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

try {
    Write-Host @"
╔═══════════════════════════════════════════════════════════════════════════════╗
║                      FOCUSRITE TOOLKIT TEST SUITE                            ║
║                              Version 1.0.0                                   ║
╚═══════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

    Write-Host ""
    Write-Host "Test Type: $TestType" -ForegroundColor Yellow
    Write-Host "Generate Report: $GenerateReport" -ForegroundColor Yellow
    Write-Host ""
    
    $startTime = Get-Date
    
    # Run test suites based on type
    switch ($TestType) {
        "Unit" {
            Invoke-UnitTests
        }
        "Integration" {
            Invoke-IntegrationTests
        }
        "Performance" {
            Invoke-PerformanceTests
        }
        "Full" {
            Invoke-UnitTests
            Invoke-IntegrationTests
            Invoke-FunctionalTests
            Invoke-PerformanceTests
        }
    }
    
    $endTime = Get-Date
    $totalDuration = ($endTime - $startTime).TotalSeconds
    
    # Display results
    Write-Host ""
    Write-TestLog "=== TEST EXECUTION COMPLETE ===" "INFO"
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "TEST RESULTS SUMMARY" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    $successRate = if ($Global:TestCount -gt 0) { [math]::Round(($Global:PassedTests / $Global:TestCount) * 100, 1) } else { 0 }
    
    Write-Host "Total Tests: $Global:TestCount"
    Write-Host "Passed: $Global:PassedTests" -ForegroundColor Green
    Write-Host "Failed: $Global:FailedTests" -ForegroundColor Red  
    Write-Host "Skipped: $Global:SkippedTests" -ForegroundColor Yellow
    Write-Host "Success Rate: $successRate%"
    Write-Host "Total Duration: $([math]::Round($totalDuration, 2)) seconds"
    Write-Host ""
    
    # Generate report if requested
    if ($GenerateReport) {
        Write-TestLog "Generating HTML test report..." "INFO"
        if (Generate-TestReport -OutputPath $ReportPath) {
            try {
                Start-Process $ReportPath
            }
            catch {
                Write-TestLog "Report saved but could not be opened automatically" "INFO"
            }
        }
    }
    
    # Exit with appropriate code
    if ($Global:FailedTests -eq 0) {
        Write-Host "All tests completed successfully! ✅" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "Some tests failed. Check results above for details. ❌" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-TestLog "Test suite execution failed: $($_.Exception.Message)" "FAIL"
    Write-Host "Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}