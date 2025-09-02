@echo off
echo ========================================
echo KeyLab mkII Driver Fix
echo ========================================

echo Problem: KeyLab mkII 88 shows "Unknown" status
echo Solution: Install Arturia driver or force generic MIDI

echo.
echo [1/2] Attempting to force generic MIDI driver...
powershell -ExecutionPolicy Bypass -Command "pnputil /add-driver C:\Windows\inf\wdma_usb.inf /install"

echo.
echo [2/2] Restarting MIDI services...
net stop audiosrv
net start audiosrv

echo.
echo ========================================
echo Manual Steps if still not working:
echo ========================================
echo 1. Download Arturia Software Center from:
echo    https://www.arturia.com/support/downloads^&manuals
echo.
echo 2. Or try Device Manager:
echo    - Right-click "KeyLab mkII 88"
echo    - Update Driver
echo    - Browse my computer
echo    - Let me pick from a list
echo    - Select "USB Audio Device" or "Generic USB MIDI"
echo.
echo 3. Restart FL Studio after driver install
echo ========================================
pause
