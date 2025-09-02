@echo off
echo ========================================
echo Minimal USB Device Check
echo ========================================

echo Checking target devices...
powershell -ExecutionPolicy Bypass -Command "Get-PnpDevice | Where-Object { $_.InstanceId -like '*VID_1235*' -or $_.InstanceId -like '*VID_1C75*' } | Select-Object FriendlyName, Status, Class"

echo.
echo Checking for USB problems...
powershell -ExecutionPolicy Bypass -Command "Get-PnpDevice | Where-Object { $_.Status -ne 'OK' -and $_.Class -eq 'USB' } | Select-Object FriendlyName, Status"

echo.
echo Disabling USB selective suspend...
powershell -ExecutionPolicy Bypass -Command "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\USB' -Name 'DisableSelectiveSuspend' -Value 1; Write-Host 'USB Selective Suspend disabled - restart required'"

echo.
echo ========================================
echo Check complete!
echo ========================================
pause
