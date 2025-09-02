@echo off
echo ========================================
echo Working USB Diagnostics
echo ========================================

REM Copy to local directory
set LOCAL_DIR=C:\temp\diag
if exist "%LOCAL_DIR%" rmdir /s /q "%LOCAL_DIR%"
mkdir "%LOCAL_DIR%"
xcopy /s /q "%~dp0*" "%LOCAL_DIR%\"
cd /d "%LOCAL_DIR%"

echo [1/3] Simple USB device check...
powershell -ExecutionPolicy Bypass -File "SimpleUSBCheck.ps1" -Export

echo.
echo [2/3] Fixing USB selective suspend...
powershell -ExecutionPolicy Bypass -File "FixUSBSuspend.ps1" -Apply

echo.
echo [3/3] Final device status...
powershell -ExecutionPolicy Bypass -Command "Get-PnpDevice | Where-Object { $_.InstanceId -like '*VID_1235*' -or $_.InstanceId -like '*VID_1C75*' } | Select-Object FriendlyName, Status, Class"

echo.
echo ========================================
echo Diagnostics complete!
echo Reports saved to: %LOCAL_DIR%
echo ========================================
pause
