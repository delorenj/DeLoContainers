# Simple USB Device Check
param(
    [switch]$Export
)

Write-Host "=== Simple USB Device Check ===" -ForegroundColor Green
Write-Host ""

# 1. Check for target devices
Write-Host "1. Checking for target devices..." -ForegroundColor Yellow
$focusrite = Get-PnpDevice | Where-Object { $_.InstanceId -like "*VID_1235&PID_821A*" }
$arturia = Get-PnpDevice | Where-Object { $_.InstanceId -like "*VID_1C75&PID_02CB*" }

if ($focusrite) {
    Write-Host "   ✓ Focusrite Scarlett 4i4: $($focusrite.Status)" -ForegroundColor Green
} else {
    Write-Host "   ✗ Focusrite Scarlett 4i4: NOT FOUND" -ForegroundColor Red
}

if ($arturia) {
    Write-Host "   ✓ Arturia KeyLab mkII: $($arturia.Status)" -ForegroundColor Green
} else {
    Write-Host "   ✗ Arturia KeyLab mkII: NOT FOUND" -ForegroundColor Red
}

# 2. Check for problem devices
Write-Host ""
Write-Host "2. Checking for problem devices..." -ForegroundColor Yellow
$problemDevices = Get-PnpDevice | Where-Object { $_.Status -ne "OK" -and $_.Class -eq "USB" }
if ($problemDevices) {
    Write-Host "   Found $($problemDevices.Count) USB devices with issues:" -ForegroundColor Red
    $problemDevices | ForEach-Object {
        Write-Host "     - $($_.FriendlyName): $($_.Status)" -ForegroundColor Red
    }
} else {
    Write-Host "   ✓ No USB problem devices found" -ForegroundColor Green
}

# 3. Check USB controllers
Write-Host ""
Write-Host "3. Checking USB controllers..." -ForegroundColor Yellow
$usbControllers = Get-PnpDevice | Where-Object { $_.Class -eq "USB" -and $_.FriendlyName -like "*Host Controller*" }
$usbControllers | ForEach-Object {
    if ($_.Status -eq "OK") {
        Write-Host "   ✓ $($_.FriendlyName): OK" -ForegroundColor Green
    } else {
        Write-Host "   ✗ $($_.FriendlyName): $($_.Status)" -ForegroundColor Red
    }
}

# 4. Check USB selective suspend
Write-Host ""
Write-Host "4. Checking USB power management..." -ForegroundColor Yellow
try {
    $suspendSetting = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\USB" -Name "DisableSelectiveSuspend" -ErrorAction SilentlyContinue
    if ($suspendSetting -and $suspendSetting.DisableSelectiveSuspend -eq 1) {
        Write-Host "   ✓ USB Selective Suspend: DISABLED (Good for audio)" -ForegroundColor Green
    } else {
        Write-Host "   ⚠ USB Selective Suspend: ENABLED (May cause audio issues)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ? USB Selective Suspend: Could not determine" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Check Complete ===" -ForegroundColor Green

if ($Export) {
    $report = @{
        Timestamp = Get-Date
        FocusriteFound = $focusrite -ne $null
        ArturiaFound = $arturia -ne $null
        ProblemDeviceCount = $problemDevices.Count
        USBControllerStatus = $usbControllers | Select-Object FriendlyName, Status
    }
    $report | ConvertTo-Json | Out-File "C:\temp\usb-check-report.json"
    Write-Host "Report exported to: C:\temp\usb-check-report.json" -ForegroundColor Cyan
}
