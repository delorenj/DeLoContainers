@echo off
echo ========================================
echo MIDI Device Diagnostic
echo ========================================

echo Checking MIDI devices in Windows...
powershell -ExecutionPolicy Bypass -Command "Get-PnpDevice | Where-Object { $_.Class -eq 'MEDIA' -or $_.FriendlyName -like '*MIDI*' -or $_.FriendlyName -like '*Arturia*' } | Select-Object FriendlyName, Status, Class"

echo.
echo Checking Windows MIDI services...
powershell -ExecutionPolicy Bypass -Command "Get-Service | Where-Object { $_.Name -like '*MIDI*' -or $_.Name -like '*Audio*' } | Select-Object Name, Status"

echo.
echo Checking MIDI endpoints...
powershell -ExecutionPolicy Bypass -Command "Get-PnpDevice | Where-Object { $_.Class -eq 'AudioEndpoint' } | Where-Object { $_.FriendlyName -like '*MIDI*' -or $_.FriendlyName -like '*Arturia*' } | Select-Object FriendlyName, Status"

echo.
echo ========================================
echo MIDI Check Complete
echo ========================================
echo.
echo FL Studio MIDI Setup:
echo 1. Open FL Studio
echo 2. Go to Options ^> MIDI Settings
echo 3. Look for "KeyLab mkII 88" in the Input list
echo 4. Enable it and set to "Generic Controller"
echo 5. If not visible, try restarting FL Studio
echo ========================================
pause
