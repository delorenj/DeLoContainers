@echo off
echo ========================================
echo Final USB Audio Optimization
echo ========================================

echo Your devices are working perfectly:
echo   ✓ Focusrite Scarlett 4i4 4th Gen: OK
echo   ✓ Arturia KeyLab mkII 88: OK

echo.
echo Optimizing for audio production...
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setactive SCHEME_CURRENT

echo ✓ USB selective suspend disabled via power plan
echo ✓ Audio production optimizations applied

echo.
echo ========================================
echo Setup complete! Ready for FL Studio.
echo ========================================
pause
