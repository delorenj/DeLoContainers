@echo off
REM =============================================================================
REM FocusriteUSBFix.bat
REM Batch wrapper for Focusrite USB troubleshooting PowerShell scripts
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
set "MAIN_SCRIPT=%PS_SCRIPT_DIR%\Fix-FocusriteUSB.ps1"

REM Check if PowerShell script exists
if not exist "%MAIN_SCRIPT%" (
    echo ERROR: PowerShell script not found at: %MAIN_SCRIPT%
    pause
    exit /b 1
)

echo.
echo ============================================================================
echo                    FOCUSRITE USB TROUBLESHOOTER
echo                         Batch Launcher v1.0.0
echo ============================================================================
echo.

REM Show menu if no arguments provided
if "%~1"=="" goto :ShowMenu

REM Direct execution with parameters
set "MODE=%~1"
set "AUTOFIX="
if /i "%~2"=="auto" set "AUTOFIX=-AutoFix"

goto :ExecuteScript

:ShowMenu
echo Please select a troubleshooting mode:
echo.
echo 1. Quick Test - Fast device detection and basic fixes
echo 2. Full Repair - Comprehensive troubleshooting (Recommended)
echo 3. Diagnostic Mode - Generate detailed system report  
echo 4. Reset Mode - Force reset all USB devices and services
echo 5. Power Optimization - Optimize USB power settings
echo 6. VM Optimization - Optimize VM USB configuration
echo 7. Auto-Fix Full Repair - Full repair with automatic fixes
echo.
echo 0. Exit
echo.

choice /c 1234567Q /n /m "Enter your choice (1-7, Q to quit): "

if errorlevel 8 goto :Exit
if errorlevel 7 goto :AutoFix
if errorlevel 6 goto :VM
if errorlevel 5 goto :Power  
if errorlevel 4 goto :Reset
if errorlevel 3 goto :Diagnostic
if errorlevel 2 goto :Full
if errorlevel 1 goto :Quick

:Quick
set "MODE=Quick"
goto :ExecuteScript

:Full
set "MODE=Full"
goto :ExecuteScript

:Diagnostic
set "MODE=Diagnostic"
goto :ExecuteScript

:Reset
set "MODE=Reset"
echo.
echo WARNING: This will reset all USB devices and services!
choice /m "Are you sure you want to continue"
if errorlevel 2 goto :ShowMenu
goto :ExecuteScript

:Power
set "MODE=Power"
goto :ExecuteScript

:VM
set "MODE=VM"
goto :ExecuteScript

:AutoFix
set "MODE=Full"
set "AUTOFIX=-AutoFix"
goto :ExecuteScript

:ExecuteScript
echo.
echo Executing PowerShell script with mode: %MODE%
echo.

REM Set PowerShell execution policy for current session
powershell.exe -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force"

REM Execute the PowerShell script
powershell.exe -Command "& '%MAIN_SCRIPT%' -Mode '%MODE%' %AUTOFIX% -Verbose"

set "PS_EXIT_CODE=%ERRORLEVEL%"

echo.
echo ============================================================================
echo EXECUTION COMPLETE
echo ============================================================================

if %PS_EXIT_CODE% EQU 0 (
    echo Status: SUCCESS
    echo.
    echo Your Focusrite device should now be working properly.
    echo Test it in FL Studio or Windows Sound Settings.
) else (
    echo Status: FAILED or PARTIAL SUCCESS
    echo.
    echo Some issues may still exist. Consider:
    echo - Running "Reset Mode" if problems persist
    echo - Checking VM USB passthrough configuration
    echo - Installing latest Focusrite drivers from focusrite.com
    echo - Restarting Windows
)

echo.
echo Log files saved to: %TEMP%
echo.

if "%~1"=="" (
    echo Press any key to return to menu...
    pause >nul
    goto :ShowMenu
)

goto :Exit

:Exit
echo.
echo Exiting Focusrite USB Troubleshooter
exit /b %PS_EXIT_CODE%