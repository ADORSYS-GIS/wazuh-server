# Automated Npcap Installation using SendKeys
# This script uses keyboard automation to interact with the Npcap installer
# Designed for headless Windows Server environments where GUI interaction is required

# Requires Administrator privileges
#Requires -RunAsAdministrator

Add-Type -AssemblyName System.Windows.Forms

# Global configuration
$global:NpcapConfig = @{
    TempDir = "C:\Temp"
    InstallerUrl = "https://npcap.com/dist/npcap-1.79.exe"
    InstallerPath = "C:\Temp\npcap-1.79.exe"
    InstallPath = "C:\Program Files\Npcap"
    MaxWaitTime = 45  # Maximum wait time in seconds (reduced from 120)
}

# Logging functions with colors
function Log {
    param (
        [string]$Level,
        [string]$Message,
        [string]$Color = "White"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$Timestamp $Level $Message" -ForegroundColor $Color
}

function InfoMessage {
    param ([string]$Message)
    Log "[INFO]" $Message "White"
}

function WarnMessage {
    param ([string]$Message)
    Log "[WARNING]" $Message "Yellow"
}

function ErrorMessage {
    param ([string]$Message)
    Log "[ERROR]" $Message "Red"
}

function SuccessMessage {
    param ([string]$Message)
    Log "[SUCCESS]" $Message "Green"
}

# Helper function to send keyboard input with delay
function Send-KeysToWindow {
    param(
        [string]$Keys, 
        [int]$DelayMs = 500
    )
    Start-Sleep -Milliseconds $DelayMs
    try {
        [System.Windows.Forms.SendKeys]::SendWait($Keys)
        InfoMessage "Sent keys: $Keys"
    }
    catch {
        WarnMessage "Failed to send keys: $Keys - $_"
    }
}

# Ensure temp directory exists
function Ensure-TempDirectory {
    if (-not (Test-Path $global:NpcapConfig.TempDir)) {
        New-Item -ItemType Directory -Path $global:NpcapConfig.TempDir -Force | Out-Null
        InfoMessage "Created temp directory: $($global:NpcapConfig.TempDir)"
    }
}

# Download Npcap installer
function Download-NpcapInstaller {
    $installerPath = $global:NpcapConfig.InstallerPath
    
    if (Test-Path $installerPath) {
        InfoMessage "Npcap installer already exists at $installerPath"
        return $installerPath
    }
    
    InfoMessage "Downloading Npcap installer from $($global:NpcapConfig.InstallerUrl)..."
    try {
        Invoke-WebRequest -Uri $global:NpcapConfig.InstallerUrl -OutFile $installerPath -UseBasicParsing -ErrorAction Stop
        
        if (Test-Path $installerPath) {
            SuccessMessage "Npcap installer downloaded successfully"
            return $installerPath
        } else {
            ErrorMessage "Failed to download Npcap installer"
            return $null
        }
    } catch {
        ErrorMessage "Failed to download Npcap installer: $($_.Exception.Message)"
        return $null
    }
}

# Check if Npcap is completely installed (files + registry + drivers)
function Test-NpcapInstalled {
    # Check 1: Installation directory AND sufficient files
    $hasFiles = $false
    if (Test-Path $global:NpcapConfig.InstallPath) {
        $fileCount = (Get-ChildItem $global:NpcapConfig.InstallPath -ErrorAction SilentlyContinue | Measure-Object).Count
        $hasFiles = ($fileCount -gt 5)  # Require minimum files for complete installation
    }
    
    # Check 2: Registry entry (proper Windows installation)
    $hasRegistry = $null -ne (Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | 
                             Where-Object { $_.DisplayName -like "*npcap*" })
    
    # Check 3: Drivers (existing check)
    $hasDrivers = $null -ne (Get-WmiObject Win32_SystemDriver -Filter "Name LIKE 'npf%' OR Name LIKE 'npcap%'" -ErrorAction SilentlyContinue)
    
    # Require BOTH files AND drivers for complete installation
    if ($hasFiles -and $hasDrivers) {
        InfoMessage "Complete Npcap installation detected (Files: $hasFiles, Registry: $hasRegistry, Drivers: $hasDrivers)"
        return $true
    } elseif ($hasDrivers -and -not $hasFiles) {
        WarnMessage "Partial Npcap installation detected (drivers only). Reinstallation required..."
        return $false
    } else {
        InfoMessage "Npcap not installed or incomplete"
        return $false
    }
}

# Remove partial Npcap installation
function Remove-PartialNpcapInstallation {
    WarnMessage "Cleaning up partial Npcap installation..."
    
    # Stop and remove drivers
    $drivers = Get-WmiObject Win32_SystemDriver -Filter "Name LIKE 'npf%' OR Name LIKE 'npcap%'" -ErrorAction SilentlyContinue
    foreach ($driver in $drivers) {
        try {
            if ($driver.State -eq "Running") {
                $driver.StopService()
                WarnMessage "Stopped driver: $($driver.Name)"
            }
        } catch {
            WarnMessage "Could not stop driver: $($driver.Name) - $($_.Exception.Message)"
        }
    }
    
    # Remove installation directory if exists
    if (Test-Path $global:NpcapConfig.InstallPath) {
        try {
            Remove-Item $global:NpcapConfig.InstallPath -Recurse -Force -ErrorAction Stop
            InfoMessage "Removed partial installation directory"
        } catch {
            WarnMessage "Could not remove installation directory: $($_.Exception.Message)"
        }
    }
}

# Comprehensive installation verification
function Verify-NpcapInstallation {
    InfoMessage "Performing comprehensive Npcap installation verification..."
    
    $checks = @{
        "Installation Directory" = Test-Path $global:NpcapConfig.InstallPath
        "Sufficient Files" = if (Test-Path $global:NpcapConfig.InstallPath) { 
            (Get-ChildItem $global:NpcapConfig.InstallPath -ErrorAction SilentlyContinue | Measure-Object).Count -gt 5 
        } else { $false }
        "Driver Status" = $null -ne (Get-WmiObject Win32_SystemDriver -Filter "Name LIKE 'npf%' OR Name LIKE 'npcap%'" -ErrorAction SilentlyContinue)
    }
    
    $allPassed = $true
    foreach ($check in $checks.GetEnumerator()) {
        if ($check.Value) {
            SuccessMessage "[PASS] $($check.Key): OK"
        } else {
            ErrorMessage "[FAIL] $($check.Key): MISSING"
            $allPassed = $false
        }
    }
    
    return $allPassed
}

# Check if running in SSH session (no interactive desktop)
function Test-SSHSession {
    try {
        # Check if we're in a non-interactive session
        $sessionType = [System.Environment]::UserInteractive
        
        # Additional check for SSH indicators
        $isSSH = $null -ne $env:SSH_CLIENT -or $null -ne $env:SSH_CONNECTION -or $null -ne $env:SSH_TTY
        
        return (-not $sessionType) -or $isSSH -or ($null -eq $env:SESSIONNAME)
    } catch {
        return $true  # Assume SSH if we can't determine
    }
}

# Scheduled task installation for SSH sessions
function Install-NpcapViaScheduledTask {
    [CmdletBinding()]
    param()
    
    try {
        InfoMessage "Using scheduled task method for SSH-compatible GUI automation"
        
        # Download installer if needed
        if (-not (Test-Path $global:NpcapConfig.InstallerPath)) {
            if (-not (Download-NpcapInstaller)) {
                return $false
            }
        }
        
        # Create a PowerShell script that will run the GUI automation
        $taskScriptPath = "C:\Temp\npcap-install-task.ps1"
        $logPath = "C:\Temp\npcap-install.log"
        
        $taskScript = @"
# Npcap Installation Task Script
Start-Transcript -Path '$logPath' -Append
Write-Host "Starting Npcap installation via scheduled task..."

try {
    # Load the automation functions
    `$global:NpcapConfig = @{
        TempDir = "C:\Temp"
        InstallerPath = "$($global:NpcapConfig.InstallerPath)"
        InstallPath = "C:\Program Files\Npcap"
        MaxWaitTime = 45
    }
    
    # Start the installer process
    `$process = Start-Process -FilePath '$($global:NpcapConfig.InstallerPath)' -PassThru -ErrorAction Stop
    Write-Host "Npcap installer started (PID: `$(`$process.Id))"
    
    # Wait for installer window to appear
    Start-Sleep -Seconds 5
    
    # Load Windows Forms for SendKeys
    Add-Type -AssemblyName System.Windows.Forms
    
    # Step 1: Press Enter to start installation
    Write-Host "Step 1: Starting installation..."
    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
    Start-Sleep -Seconds 10
    
    # Step 2: Navigate through default options (25 second wait)
    Write-Host "Step 2: Navigating default options..."
    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
    Start-Sleep -Seconds 25
    
    # Step 3: Accept license agreement
    Write-Host "Step 3: Accepting license..."
    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
    Start-Sleep -Seconds 10
    
    # Step 4: Proceed with installation options
    Write-Host "Step 4: Installation options..."
    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
    Start-Sleep -Seconds 10
    
    # Step 5: Start installation
    Write-Host "Step 5: Starting installation process..."
    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
    Start-Sleep -Seconds 10
    
    # Wait for installation to complete
    Write-Host "Waiting for installation to complete..."
    `$waitTime = 0
    while (`$waitTime -lt 45 -and -not `$process.HasExited) {
        Start-Sleep -Seconds 2
        `$waitTime += 2
        Write-Host "Waiting... `$waitTime seconds"
    }
    
    if (`$process.HasExited) {
        Write-Host "Installation completed successfully"
        exit 0
    } else {
        Write-Host "Installation timed out"
        exit 1
    }
    
} catch {
    Write-Host "Error during installation: `$(`$_.Exception.Message)"
    exit 1
} finally {
    Stop-Transcript
}
"@
        
        # Write the task script
        $taskScript | Out-File -FilePath $taskScriptPath -Encoding UTF8 -Force
        InfoMessage "Created installation task script at: $taskScriptPath"
        
        # Create and run scheduled task
        $taskName = "NpcapInstallTask_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        InfoMessage "Creating scheduled task: $taskName"
        
        # Create the scheduled task to run immediately in interactive session
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$taskScriptPath`""
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(5)
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
        InfoMessage "Scheduled task created and will start in 5 seconds..."
        
        # Monitor the task execution
        Start-Sleep -Seconds 10
        
        $timeout = 120  # 2 minutes timeout
        $elapsed = 0
        $taskCompleted = $false
        
        while ($elapsed -lt $timeout -and -not $taskCompleted) {
            $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            if ($task) {
                $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction SilentlyContinue
                if ($taskInfo -and $null -ne $taskInfo.LastTaskResult) {
                    $taskCompleted = $true
                    InfoMessage "Task completed with result: $($taskInfo.LastTaskResult)"
                }
            }
            
            # Show log content if available
            if (Test-Path $logPath) {
                $logContent = Get-Content $logPath -Tail 5 -ErrorAction SilentlyContinue
                if ($logContent) {
                    InfoMessage "Recent log: $($logContent -join ' | ')"
                }
            }
            
            Start-Sleep -Seconds 5
            $elapsed += 5
            InfoMessage "Monitoring task... ($elapsed/$timeout seconds)"
        }
        
        # Cleanup
        try {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
            Remove-Item $taskScriptPath -Force -ErrorAction SilentlyContinue
            InfoMessage "Cleaned up scheduled task and script"
        } catch {
            WarnMessage "Could not cleanup task: $($_.Exception.Message)"
        }
        
        # Check if installation was successful
        Start-Sleep -Seconds 5
        if (Test-NpcapInstalled) {
            SuccessMessage "Npcap installation completed successfully via scheduled task"
            return $true
        } else {
            ErrorMessage "Npcap installation failed via scheduled task"
            return $false
        }
        
    } catch {
        ErrorMessage "Scheduled task installation failed: $($_.Exception.Message)"
        return $false
    }
}

# Wait for installer processes to complete
function Wait-ForInstallerCompletion {
    InfoMessage "Waiting for Npcap installer to complete..."
    
    $waitTime = 0
    $maxWait = $global:NpcapConfig.MaxWaitTime
    
    while ($waitTime -lt $maxWait) {
        # Check for Npcap installer processes
        $installerProcesses = Get-Process | Where-Object { 
            $_.ProcessName -like "*npcap*" -or 
            $_.ProcessName -like "*setup*" -or
            $_.MainWindowTitle -like "*Npcap*"
        }
        
        if ($installerProcesses.Count -eq 0) {
            SuccessMessage "Npcap installer processes have completed"
            return $true
        }
        
        InfoMessage "Installer still running... ($($waitTime)/$($maxWait) seconds)"
        Start-Sleep -Seconds 5
        $waitTime += 5
    }
    
    WarnMessage "Timeout reached while waiting for installer completion"
    return $false
}

# Force close any remaining installer processes
function Stop-InstallerProcesses {
    $processes = Get-Process | Where-Object { 
        $_.ProcessName -like "*npcap*" -or 
        $_.ProcessName -like "*setup*"
    }
    
    foreach ($process in $processes) {
        try {
            $process.Kill()
            WarnMessage "Force closed process: $($process.ProcessName)"
        } catch {
            ErrorMessage "Could not force close process: $($process.ProcessName)"
        }
    }
}

# Perform automated Npcap installation with retry logic
function Install-NpcapAutomated {
    InfoMessage "Starting automated Npcap installation..."
    
    # Enhanced detection with cleanup
    if (Test-NpcapInstalled) {
        SuccessMessage "Complete Npcap installation detected. Skipping installation."
        return $true
    }
    
    # Clean partial installations
    Remove-PartialNpcapInstallation
    
    # Ensure temp directory exists
    Ensure-TempDirectory
    
    # Download installer
    $installerPath = Download-NpcapInstaller
    if (-not $installerPath) {
        ErrorMessage "Cannot proceed without Npcap installer"
        return $false
    }
    
    # Check if running in SSH session and use appropriate method
    if (Test-SSHSession) {
        WarnMessage "SSH session detected - using scheduled task method for GUI automation"
        return Install-NpcapViaScheduledTask
    }
    
    InfoMessage "Starting Npcap installer with keyboard automation..."
    InfoMessage "This will automatically navigate through the installer using SendKeys"
    
    try {
        # Start the installer process
        $process = Start-Process -FilePath $installerPath -PassThru -ErrorAction Stop
        InfoMessage "Npcap installer started (PID: $($process.Id))"
        
        # Wait for installer window to appear and stabilize
        InfoMessage "Waiting for installer window to load..."
        Start-Sleep -Seconds 8
        
        # Step 1: Accept license agreement (Alt+A or Enter)
        InfoMessage "Step 1: Accepting license agreement..."
        Send-KeysToWindow -Keys "%a" -DelayMs 1000  # Alt+A for "I Agree"
        Start-Sleep -Seconds 2
        
        # Fallback: Try Enter if Alt+A doesn't work
        Send-KeysToWindow -Keys "{ENTER}" -DelayMs 1000
        Start-Sleep -Seconds 3
        
        # Step 2: Navigate through options (use default settings)
        InfoMessage "Step 2: Proceeding with default options..."
        Send-KeysToWindow -Keys "{ENTER}" -DelayMs 1000  # Next button
        Start-Sleep -Seconds 25  # Wait 25 seconds before next step
        
        # Step 3: Start installation
        InfoMessage "Step 3: Starting installation..."
        Send-KeysToWindow -Keys "{ENTER}" -DelayMs 1000  # Install button
        Start-Sleep -Seconds 10  # Wait 10 seconds before next step
        
        # Step 4: Handle any additional prompts
        InfoMessage "Step 4: Handling installation prompts..."
        Send-KeysToWindow -Keys "{ENTER}" -DelayMs 1000  # Continue/Next
        Start-Sleep -Seconds 10  # Wait 10 seconds before next step
        
        # Step 5: Complete installation
        InfoMessage "Step 5: Completing installation..."
        Send-KeysToWindow -Keys "{ENTER}" -DelayMs 1000  # Finish button
        Start-Sleep -Seconds 10  # Wait 10 seconds for completion
        
        # Wait for installation to complete
        $completed = Wait-ForInstallerCompletion
        
        if (-not $completed) {
            WarnMessage "Installation may not have completed properly. Forcing cleanup..."
            Stop-InstallerProcesses
        }
        
        # Enhanced verification with comprehensive checks
        InfoMessage "Waiting for installation to complete..."
        Start-Sleep -Seconds 10  # Allow more time for files to be written
        
        if (Verify-NpcapInstallation) {
            SuccessMessage "Npcap installation completed and verified successfully!"
            
            # Additional driver status info
            $drivers = Get-WmiObject Win32_SystemDriver -Filter "Name LIKE 'npf%' OR Name LIKE 'npcap%'" -ErrorAction SilentlyContinue
            if ($drivers) {
                SuccessMessage "Npcap drivers are loaded and running!"
                $drivers | ForEach-Object { 
                    InfoMessage "  - Driver: $($_.Name) - Status: $($_.State)" 
                }
            }
            
            return $true
        } else {
            ErrorMessage "Npcap installation verification failed!"
            return $false
        }
        
    } catch {
        ErrorMessage "Failed to start Npcap installer: $($_.Exception.Message)"
        return $false
    } finally {
        # Cleanup installer file
        if (Test-Path $installerPath) {
            try {
                Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
                InfoMessage "Cleaned up installer file"
            } catch {
                WarnMessage "Could not remove installer file: $installerPath"
            }
        }
    }
}

# Install Npcap with retry logic
function Install-NpcapWithRetry {
    $maxRetries = 2
    for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
        InfoMessage "Installation attempt $attempt of $maxRetries"
        
        if (Install-NpcapAutomated) {
            return $true
        }
        
        if ($attempt -lt $maxRetries) {
            WarnMessage "Installation failed. Cleaning up and retrying..."
            Remove-PartialNpcapInstallation
            Start-Sleep -Seconds 10
        }
    }
    
    ErrorMessage "All installation attempts failed"
    return $false
}

# Main execution
function Main {
    InfoMessage "=== Automated Npcap Installation Script ==="
    InfoMessage "This script will install Npcap using keyboard automation"
    InfoMessage "Designed for headless Windows Server environments with enhanced detection"
    
    try {
        $result = Install-NpcapWithRetry
        
        if ($result) {
            SuccessMessage "Npcap installation process completed successfully!"
            InfoMessage "Npcap is now ready for use with Suricata and other network monitoring tools"
            exit 0
        } else {
            ErrorMessage "Npcap installation failed after all retry attempts!"
            exit 1
        }
    } catch {
        ErrorMessage "Script execution failed: $($($_.Exception.Message))"
        exit 1
    }
}

# Execute main function if script is run directly
if ($MyInvocation.InvocationName -ne '.') {
    Main
}
