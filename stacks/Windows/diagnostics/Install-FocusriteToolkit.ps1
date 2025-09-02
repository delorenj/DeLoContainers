# =============================================================================
# Install-FocusriteToolkit.ps1
# Installation script for Focusrite USB Toolkit
# Author: Hive Mind Coder Agent
# Version: 1.0.0
# =============================================================================

#Requires -Version 5.1

param(
    [Parameter(Mandatory = $false)]
    [string]$InstallPath = "$env:ProgramFiles\FocusriteUSBToolkit",
    
    [Parameter(Mandatory = $false)]
    [switch]$CreateDesktopShortcuts = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$CreateStartMenuShortcuts = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$AddToPath = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$Silent = $false
)

function Write-InstallLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    if (-not $Silent) {
        $color = switch ($Level) {
            "SUCCESS" { "Green" }
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            default { "White" }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

function Test-AdminPrivileges {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    return $isAdmin
}

function Copy-ToolkitFiles {
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )
    
    Write-InstallLog "Copying toolkit files to $DestinationPath"
    
    try {
        # Create destination directory
        if (-not (Test-Path $DestinationPath)) {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        }
        
        # Create subdirectories
        $subdirs = @("scripts\powershell", "scripts\batch", "tests", "docs", "logs")
        foreach ($subdir in $subdirs) {
            $fullPath = Join-Path $DestinationPath $subdir
            if (-not (Test-Path $fullPath)) {
                New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
            }
        }
        
        # Copy PowerShell scripts
        $psScripts = @(
            "scripts\powershell\FocusriteUSBToolkit.psm1",
            "scripts\powershell\Fix-FocusriteUSB.ps1",
            "scripts\powershell\Verify-USBPassthrough.ps1",
            "scripts\powershell\Install-FocusriteDrivers.ps1"
        )
        
        foreach ($script in $psScripts) {
            $srcPath = Join-Path $SourcePath $script
            $dstPath = Join-Path $DestinationPath $script
            if (Test-Path $srcPath) {
                Copy-Item -Path $srcPath -Destination $dstPath -Force
                Write-InstallLog "Copied: $script" "SUCCESS"
            } else {
                Write-InstallLog "Source file not found: $srcPath" "WARN"
            }
        }
        
        # Copy batch scripts
        $batchScripts = @(
            "scripts\batch\FocusriteUSBFix.bat",
            "scripts\batch\QuickFix.bat"
        )
        
        foreach ($script in $batchScripts) {
            $srcPath = Join-Path $SourcePath $script
            $dstPath = Join-Path $DestinationPath $script
            if (Test-Path $srcPath) {
                Copy-Item -Path $srcPath -Destination $dstPath -Force
                Write-InstallLog "Copied: $script" "SUCCESS"
            } else {
                Write-InstallLog "Source file not found: $srcPath" "WARN"
            }
        }
        
        # Copy test suite
        $testScript = "tests\Test-FocusriteToolkit.ps1"
        $srcPath = Join-Path $SourcePath $testScript
        $dstPath = Join-Path $DestinationPath $testScript
        if (Test-Path $srcPath) {
            Copy-Item -Path $srcPath -Destination $dstPath -Force
            Write-InstallLog "Copied: $testScript" "SUCCESS"
        }
        
        # Copy documentation
        $docFile = "docs\FocusriteUSBToolkit-README.md"
        $srcPath = Join-Path $SourcePath $docFile
        $dstPath = Join-Path $DestinationPath $docFile
        if (Test-Path $srcPath) {
            Copy-Item -Path $srcPath -Destination $dstPath -Force
            Write-InstallLog "Copied: $docFile" "SUCCESS"
        }
        
        # Copy this installer script
        $installerSrc = Join-Path $SourcePath "Install-FocusriteToolkit.ps1"
        $installerDst = Join-Path $DestinationPath "Install-FocusriteToolkit.ps1"
        if (Test-Path $installerSrc) {
            Copy-Item -Path $installerSrc -Destination $installerDst -Force
        }
        
        return $true
    }
    catch {
        Write-InstallLog "Error copying files: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Create-DesktopShortcuts {
    param(
        [string]$InstallPath
    )
    
    Write-InstallLog "Creating desktop shortcuts"
    
    try {
        $WshShell = New-Object -comObject WScript.Shell
        $desktopPath = [System.Environment]::GetFolderPath('Desktop')
        
        # Quick Fix shortcut
        $shortcut = $WshShell.CreateShortcut("$desktopPath\Focusrite Quick Fix.lnk")
        $shortcut.TargetPath = Join-Path $InstallPath "scripts\batch\QuickFix.bat"
        $shortcut.WorkingDirectory = Join-Path $InstallPath "scripts\batch"
        $shortcut.Description = "Focusrite USB Quick Fix Tool"
        $shortcut.Save()
        
        # Main toolkit shortcut
        $shortcut = $WshShell.CreateShortcut("$desktopPath\Focusrite USB Toolkit.lnk")
        $shortcut.TargetPath = Join-Path $InstallPath "scripts\batch\FocusriteUSBFix.bat"
        $shortcut.WorkingDirectory = Join-Path $InstallPath "scripts\batch"
        $shortcut.Description = "Focusrite USB Troubleshooting Toolkit"
        $shortcut.Save()
        
        Write-InstallLog "Desktop shortcuts created" "SUCCESS"
        return $true
    }
    catch {
        Write-InstallLog "Error creating desktop shortcuts: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Create-StartMenuShortcuts {
    param(
        [string]$InstallPath
    )
    
    Write-InstallLog "Creating Start Menu shortcuts"
    
    try {
        $WshShell = New-Object -comObject WScript.Shell
        $startMenuPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Focusrite USB Toolkit"
        
        # Create start menu folder
        if (-not (Test-Path $startMenuPath)) {
            New-Item -ItemType Directory -Path $startMenuPath -Force | Out-Null
        }
        
        # Quick Fix shortcut
        $shortcut = $WshShell.CreateShortcut("$startMenuPath\Quick Fix.lnk")
        $shortcut.TargetPath = Join-Path $InstallPath "scripts\batch\QuickFix.bat"
        $shortcut.WorkingDirectory = Join-Path $InstallPath "scripts\batch"
        $shortcut.Description = "Focusrite USB Quick Fix Tool"
        $shortcut.Save()
        
        # Main toolkit shortcut
        $shortcut = $WshShell.CreateShortcut("$startMenuPath\USB Toolkit.lnk")
        $shortcut.TargetPath = Join-Path $InstallPath "scripts\batch\FocusriteUSBFix.bat"
        $shortcut.WorkingDirectory = Join-Path $InstallPath "scripts\batch"
        $shortcut.Description = "Focusrite USB Troubleshooting Toolkit"
        $shortcut.Save()
        
        # Documentation shortcut
        $docPath = Join-Path $InstallPath "docs\FocusriteUSBToolkit-README.md"
        if (Test-Path $docPath) {
            $shortcut = $WshShell.CreateShortcut("$startMenuPath\Documentation.lnk")
            $shortcut.TargetPath = $docPath
            $shortcut.WorkingDirectory = Join-Path $InstallPath "docs"
            $shortcut.Description = "Focusrite USB Toolkit Documentation"
            $shortcut.Save()
        }
        
        Write-InstallLog "Start Menu shortcuts created" "SUCCESS"
        return $true
    }
    catch {
        Write-InstallLog "Error creating Start Menu shortcuts: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Add-ToSystemPath {
    param(
        [string]$InstallPath
    )
    
    Write-InstallLog "Adding toolkit to system PATH"
    
    try {
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
        $toolkitBatchPath = Join-Path $InstallPath "scripts\batch"
        
        if ($currentPath -notlike "*$toolkitBatchPath*") {
            $newPath = "$currentPath;$toolkitBatchPath"
            [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
            Write-InstallLog "Added to system PATH: $toolkitBatchPath" "SUCCESS"
        } else {
            Write-InstallLog "Already in system PATH: $toolkitBatchPath" "SUCCESS"
        }
        
        return $true
    }
    catch {
        Write-InstallLog "Error adding to system PATH: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Register-PowerShellModule {
    param(
        [string]$InstallPath
    )
    
    Write-InstallLog "Registering PowerShell module"
    
    try {
        $modulePath = Join-Path $InstallPath "scripts\powershell"
        $userModulePath = Join-Path $env:USERPROFILE "Documents\PowerShell\Modules\FocusriteUSBToolkit"
        
        # Create user module directory
        if (-not (Test-Path (Split-Path $userModulePath -Parent))) {
            New-Item -ItemType Directory -Path (Split-Path $userModulePath -Parent) -Force | Out-Null
        }
        
        # Create symbolic link to module
        if (Test-Path $userModulePath) {
            Remove-Item $userModulePath -Force -Recurse
        }
        
        # Copy module file to user modules
        New-Item -ItemType Directory -Path $userModulePath -Force | Out-Null
        $moduleFile = Join-Path $modulePath "FocusriteUSBToolkit.psm1"
        $destModuleFile = Join-Path $userModulePath "FocusriteUSBToolkit.psm1"
        
        if (Test-Path $moduleFile) {
            Copy-Item -Path $moduleFile -Destination $destModuleFile -Force
            Write-InstallLog "PowerShell module registered" "SUCCESS"
        }
        
        return $true
    }
    catch {
        Write-InstallLog "Error registering PowerShell module: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Set-ExecutionPolicy {
    Write-InstallLog "Configuring PowerShell execution policy"
    
    try {
        $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
        if ($currentPolicy -eq "Restricted" -or $currentPolicy -eq "Undefined") {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-InstallLog "Set PowerShell execution policy to RemoteSigned" "SUCCESS"
        } else {
            Write-InstallLog "PowerShell execution policy already configured: $currentPolicy" "SUCCESS"
        }
        return $true
    }
    catch {
        Write-InstallLog "Error setting execution policy: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-Installation {
    param(
        [string]$InstallPath
    )
    
    Write-InstallLog "Testing installation"
    
    $requiredFiles = @(
        "scripts\powershell\FocusriteUSBToolkit.psm1",
        "scripts\powershell\Fix-FocusriteUSB.ps1",
        "scripts\batch\FocusriteUSBFix.bat",
        "scripts\batch\QuickFix.bat"
    )
    
    $allPresent = $true
    foreach ($file in $requiredFiles) {
        $fullPath = Join-Path $InstallPath $file
        if (-not (Test-Path $fullPath)) {
            Write-InstallLog "Missing required file: $file" "ERROR"
            $allPresent = $false
        }
    }
    
    if ($allPresent) {
        Write-InstallLog "Installation verification: PASSED" "SUCCESS"
    } else {
        Write-InstallLog "Installation verification: FAILED" "ERROR"
    }
    
    return $allPresent
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

try {
    if (-not $Silent) {
        Write-Host @"
╔═══════════════════════════════════════════════════════════════════════════════╗
║                    FOCUSRITE USB TOOLKIT INSTALLER                           ║
║                              Version 1.0.0                                   ║
╚═══════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
        Write-Host ""
    }
    
    # Check prerequisites
    Write-InstallLog "Checking installation prerequisites"
    
    $isAdmin = Test-AdminPrivileges
    if (-not $isAdmin -and ($AddToPath -or $CreateStartMenuShortcuts)) {
        Write-InstallLog "Administrator privileges required for system-wide installation" "ERROR"
        Write-InstallLog "Run as Administrator or use -AddToPath:`$false -CreateStartMenuShortcuts:`$false" "ERROR"
        exit 1
    }
    
    # Get source directory
    $sourceDir = $PSScriptRoot
    if (-not $sourceDir) {
        $sourceDir = (Get-Location).Path
    }
    
    Write-InstallLog "Source directory: $sourceDir"
    Write-InstallLog "Install directory: $InstallPath"
    
    # Install steps
    $installSteps = @()
    
    # Step 1: Copy files
    Write-InstallLog "Step 1/7: Copying toolkit files"
    if (Copy-ToolkitFiles -SourcePath $sourceDir -DestinationPath $InstallPath) {
        $installSteps += "Files copied successfully"
    } else {
        Write-InstallLog "File copy failed - aborting installation" "ERROR"
        exit 1
    }
    
    # Step 2: Set execution policy
    Write-InstallLog "Step 2/7: Configuring PowerShell"
    if (Set-ExecutionPolicy) {
        $installSteps += "PowerShell configured"
    }
    
    # Step 3: Register module
    Write-InstallLog "Step 3/7: Registering PowerShell module"
    if (Register-PowerShellModule -InstallPath $InstallPath) {
        $installSteps += "PowerShell module registered"
    }
    
    # Step 4: Create desktop shortcuts
    Write-InstallLog "Step 4/7: Creating desktop shortcuts"
    if ($CreateDesktopShortcuts) {
        if (Create-DesktopShortcuts -InstallPath $InstallPath) {
            $installSteps += "Desktop shortcuts created"
        }
    } else {
        Write-InstallLog "Desktop shortcuts skipped (disabled)" "SUCCESS"
        $installSteps += "Desktop shortcuts skipped"
    }
    
    # Step 5: Create Start Menu shortcuts
    Write-InstallLog "Step 5/7: Creating Start Menu shortcuts"
    if ($CreateStartMenuShortcuts -and $isAdmin) {
        if (Create-StartMenuShortcuts -InstallPath $InstallPath) {
            $installSteps += "Start Menu shortcuts created"
        }
    } else {
        Write-InstallLog "Start Menu shortcuts skipped" "SUCCESS"
        $installSteps += "Start Menu shortcuts skipped"
    }
    
    # Step 6: Add to PATH
    Write-InstallLog "Step 6/7: Adding to system PATH"
    if ($AddToPath -and $isAdmin) {
        if (Add-ToSystemPath -InstallPath $InstallPath) {
            $installSteps += "Added to system PATH"
        }
    } else {
        Write-InstallLog "System PATH modification skipped" "SUCCESS"
        $installSteps += "System PATH modification skipped"
    }
    
    # Step 7: Test installation
    Write-InstallLog "Step 7/7: Testing installation"
    $testResult = Test-Installation -InstallPath $InstallPath
    if ($testResult) {
        $installSteps += "Installation verified"
    }
    
    # Show results
    if (-not $Silent) {
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "INSTALLATION COMPLETE" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        
        Write-Host "Installation Steps Completed:" -ForegroundColor Yellow
        foreach ($step in $installSteps) {
            Write-Host "  ✓ $step" -ForegroundColor Green
        }
        Write-Host ""
        
        if ($testResult) {
            Write-Host "🎵 Installation successful! You can now:" -ForegroundColor Green
            Write-Host ""
            
            if ($CreateDesktopShortcuts) {
                Write-Host "• Double-click 'Focusrite Quick Fix' on your desktop" -ForegroundColor White
            }
            
            if ($CreateStartMenuShortcuts) {
                Write-Host "• Use Start Menu → Focusrite USB Toolkit" -ForegroundColor White
            }
            
            Write-Host "• Navigate to: $InstallPath" -ForegroundColor White
            Write-Host "• Run: scripts\batch\QuickFix.bat" -ForegroundColor White
            Write-Host ""
            Write-Host "📖 Documentation available at:" -ForegroundColor Yellow
            Write-Host "   $InstallPath\docs\FocusriteUSBToolkit-README.md" -ForegroundColor White
        } else {
            Write-Host "⚠️ Installation completed with issues" -ForegroundColor Yellow
            Write-Host "Some files may be missing. Check the log above for details." -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "🔧 To troubleshoot Focusrite USB issues:" -ForegroundColor Cyan
        Write-Host "1. Right-click on batch files and 'Run as administrator'" -ForegroundColor White
        Write-Host "2. Start with QuickFix.bat for simple issues" -ForegroundColor White
        Write-Host "3. Use FocusriteUSBFix.bat for comprehensive troubleshooting" -ForegroundColor White
    }
    
    if ($testResult) {
        exit 0
    } else {
        exit 1
    }
}
catch {
    Write-InstallLog "Installation failed: $($_.Exception.Message)" "ERROR"
    exit 1
}