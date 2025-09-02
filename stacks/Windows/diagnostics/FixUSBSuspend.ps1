# Fix USB Selective Suspend for Audio Production
param(
    [switch]$Apply
)

Write-Host "=== USB Selective Suspend Fix ===" -ForegroundColor Green
Write-Host ""

if (-not $Apply) {
    Write-Host "This will disable USB Selective Suspend to prevent audio dropouts." -ForegroundColor Yellow
    Write-Host "Run with -Apply to make changes." -ForegroundColor Yellow
    Write-Host ""
}

# Check current setting
try {
    $current = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\USB" -Name "DisableSelectiveSuspend" -ErrorAction SilentlyContinue
    if ($current -and $current.DisableSelectiveSuspend -eq 1) {
        Write-Host "Current status: USB Selective Suspend is DISABLED ✓" -ForegroundColor Green
    } else {
        Write-Host "Current status: USB Selective Suspend is ENABLED" -ForegroundColor Red
        
        if ($Apply) {
            Write-Host "Disabling USB Selective Suspend..." -ForegroundColor Yellow
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\USB" -Name "DisableSelectiveSuspend" -Value 1
            Write-Host "✓ USB Selective Suspend disabled. Restart required." -ForegroundColor Green
        }
    }
} catch {
    Write-Host "Error: Could not access USB registry settings" -ForegroundColor Red
    Write-Host "Make sure you're running as Administrator" -ForegroundColor Yellow
}

# Also disable for current power scheme
if ($Apply) {
    Write-Host ""
    Write-Host "Disabling USB selective suspend for current power plan..." -ForegroundColor Yellow
    try {
        & powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
        & powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
        & powercfg /setactive SCHEME_CURRENT
        Write-Host "✓ Power plan updated" -ForegroundColor Green
    } catch {
        Write-Host "Warning: Could not update power plan settings" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Fix Complete ===" -ForegroundColor Green
