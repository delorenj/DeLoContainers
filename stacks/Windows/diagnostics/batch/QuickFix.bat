@echo off
REM =============================================================================
REM QuickFix.bat
REM Quick Focusrite USB troubleshooting launcher
REM Author: Hive Mind Coder Agent
REM Version: 1.0.0
REM =============================================================================

setlocal EnableDelayedExpansion

REM Check for admin privileges
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo ERROR: This script must be run as Administrator
    echo Right-click and select "Run as administrator"
    pause
    exit /b 1
)

REM Set script directory
set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT_DIR=%SCRIPT_DIR%..\powershell"

echo.
echo ============================================================================
echo                      FOCUSRITE QUICK FIX LAUNCHER
echo                            Version 1.0.0
echo ============================================================================
echo.

REM Quick device detection
echo [1/3] Checking for Focusrite devices...
powershell.exe -Command "Get-PnPDevice | Where-Object { $_.InstanceId -like '*VID_1235&PID_821A*' } | Select-Object FriendlyName, Status"

if errorlevel 1 (
    echo No Focusrite devices detected in Windows
    echo.
    echo This could mean:
    echo   - Device is not connected
    echo   - USB passthrough not configured
    echo   - Drivers not installed
    echo.
    echo Running comprehensive fix...
    goto :RunFix
)

echo.
echo [2/3] Testing device functionality...
powershell.exe -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force; & '%PS_SCRIPT_DIR%\Verify-USBPassthrough.ps1'"

echo.
echo [3/3] Quick reset attempt...
powershell.exe -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force; & '%PS_SCRIPT_DIR%\Fix-FocusriteUSB.ps1' -Mode Quick -AutoFix"

set "QUICK_EXIT_CODE=%ERRORLEVEL%"

if %QUICK_EXIT_CODE% EQU 0 (
    echo.
    echo ============================================================================
    echo SUCCESS: Quick fix completed successfully!
    echo ============================================================================
    echo.
    echo Your Focusrite device should now be working.
    echo Test it in FL Studio or Windows Sound Settings.
    echo.
    goto :End
)

:RunFix
echo.
echo Quick fix was not sufficient. Running full repair...
echo.
powershell.exe -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force; & '%PS_SCRIPT_DIR%\Fix-FocusriteUSB.ps1' -Mode Full -AutoFix"

set "FULL_EXIT_CODE=%ERRORLEVEL%"

echo.
echo ============================================================================
if %FULL_EXIT_CODE% EQU 0 (
    echo SUCCESS: Full repair completed successfully!
    echo ============================================================================
    echo.
    echo Your Focusrite device should now be working.
    echo Test it in FL Studio or Windows Sound Settings.
) else (
    echo PARTIAL SUCCESS: Some issues may remain
    echo ============================================================================
    echo.
    echo Try the following if problems persist:
    echo   1. Restart Windows
    echo   2. Run "FocusriteUSBFix.bat Reset" 
    echo   3. Install drivers manually from focusrite.com
    echo   4. Check VM USB passthrough configuration
)

:End
echo.
echo Press any key to exit...
pause >nul