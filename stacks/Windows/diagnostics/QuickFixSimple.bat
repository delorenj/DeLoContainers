@echo off
echo ========================================
echo Simple USB Diagnostic Fix
echo ========================================

REM Copy to local directory to avoid UNC issues
set LOCAL_DIR=C:\temp\diag
if exist "%LOCAL_DIR%" rmdir /s /q "%LOCAL_DIR%"
mkdir "%LOCAL_DIR%"
xcopy /s /q "%~dp0*" "%LOCAL_DIR%\"
cd /d "%LOCAL_DIR%"

echo Checking Focusrite devices...
powershell -ExecutionPolicy Bypass -Command "Get-PnPDevice | Where-Object { $_.InstanceId -like '*VID_1235&PID_821A*' } | Select-Object FriendlyName, Status"

echo.
echo Running USB conflict detection...
powershell -ExecutionPolicy Bypass -File "usb-conflict-detection.ps1" -Detailed

echo.
echo Running controller health check...
powershell -ExecutionPolicy Bypass -File "usb-controller-health-check.ps1" -FullReport

echo.
echo Done! Check C:\temp\diag for reports.
pause
