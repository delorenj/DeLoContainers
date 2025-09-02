@echo off
echo ========================================
echo Windows VM USB Diagnostic Suite
echo ========================================
echo.

REM Copy files to local temp directory to avoid UNC path issues
set TEMP_DIR=%TEMP%\diagnostics
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"
mkdir "%TEMP_DIR%"
xcopy /s /q "%~dp0*" "%TEMP_DIR%\"

REM Change to temp directory
cd /d "%TEMP_DIR%"

echo [1/4] Running USB Conflict Detection...
powershell -ExecutionPolicy Bypass -File "usb-conflict-detection.ps1" -Detailed -Export
echo.

echo [2/4] Running USB Controller Health Check...
powershell -ExecutionPolicy Bypass -File "usb-controller-health-check.ps1" -FullReport
echo.

echo [3/4] Running Device Manager Cleanup (Dry Run)...
powershell -ExecutionPolicy Bypass -File "device-manager-cleanup.ps1" -DryRun
echo.

echo [4/4] Running Quick Fix...
call "batch\QuickFix.bat"
echo.

echo ========================================
echo Diagnostics Complete!
echo Check the generated reports in: %TEMP_DIR%
echo ========================================
pause
