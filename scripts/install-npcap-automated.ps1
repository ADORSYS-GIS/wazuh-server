# Fast Automated Npcap Installation using SendKeys
# Optimized version with reduced wait times for Windows Server environments
# Designed for headless Windows Server environments where GUI interaction is required

# Requires Administrator privileges
#Requires -RunAsAdministrator

Add-Type -AssemblyName System.Windows.Forms

# Global configuration - OPTIMIZED TIMINGS
$global:NpcapConfig = @{
    TempDir = "C:\Temp"
    InstallerUrl = "https://npcap.com/dist/npcap-1.79.exe"
    InstallerPath = "C:\Temp\npcap-1.79.exe"
    InstallPath = "C:\Program Files\Npcap"
    MaxWaitTime = 45  # Reduced from 120 to 45 seconds
    PollInterval = 2  # Reduced from 5 to 2 seconds
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

# OPTIMIZED: Helper function to send keyboard input with reduced delay
function Send-KeysToWindow {
    param(
        [string]$Keys, 
        [int]$DelayMs = 200  # Reduced from 500 to 200ms
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

# OPTIMIZED: Smart window detection
function Wait-ForWindow {
    param(
        [string]$WindowTitle = "*npcap*",
        [int]$MaxWaitSeconds = 10  # Reduced from implied longer waits
    )
    
    $waited = 0
    while ($waited -lt $MaxWaitSeconds) {
        $windows = Get-Process | Where-Object { $_.MainWindowTitle -like $WindowTitle }
        if ($windows.Count -gt 0) {
            InfoMessage "Found installer window after $waited seconds"
            return $true
        }
        Start-Sleep -Milliseconds 500
        $waited += 0.5
    }
    
    WarnMessage "No installer window found after $MaxWaitSeconds seconds"
    return $false
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
        # Set TLS protocols for download (learned from our earlier fix)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        
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
        "Registry Entry" = $null -ne (Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | 
                                     Where-Object { $_.DisplayName -like "*npcap*" })
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

# OPTIMIZED: Wait for installer processes to complete with faster polling
function Wait-ForInstallerCompletion {
    InfoMessage "Waiting for Npcap installer to complete..."
    
    $waitTime = 0
    $maxWait = $global:NpcapConfig.MaxWaitTime
    $pollInterval = $global:NpcapConfig.PollInterval
    
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
        Start-Sleep -Seconds $pollInterval
        $waitTime += $pollInterval
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

# OPTIMIZED: Perform automated Npcap installation with faster timings
function Install-NpcapAutomated {
    InfoMessage "Starting FAST automated Npcap installation..."
    
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
    
    InfoMessage "Starting Npcap installer with OPTIMIZED keyboard automation..."
    InfoMessage "This will automatically navigate through the installer using SendKeys with reduced delays"
    
    try {
        # Start the installer process
        $process = Start-Process -FilePath $installerPath -PassThru -ErrorAction Stop
        InfoMessage "Npcap installer started (PID: $($process.Id))"
        
        # OPTIMIZED: Wait for installer window with smart detection
        InfoMessage "Waiting for installer window to load..."
        if (-not (Wait-ForWindow -WindowTitle "*npcap*" -MaxWaitSeconds 5)) {
            # Fallback: shorter generic wait
            Start-Sleep -Seconds 3
        }
        
        # Step 1: Accept license agreement (Alt+A or Enter) - FASTER
        InfoMessage "Step 1: Accepting license agreement..."
        Send-KeysToWindow -Keys "%a" -DelayMs 300  # Reduced delay
        Start-Sleep -Milliseconds 800  # Reduced from 2 seconds
        
        # Fallback: Try Enter if Alt+A doesn't work
        Send-KeysToWindow -Keys "{ENTER}" -DelayMs 300
        Start-Sleep -Milliseconds 1200  # Reduced from 3 seconds
        
        # Step 2: Navigate through options (use default settings) - FASTER
        InfoMessage "Step 2: Proceeding with default options..."
        Send-KeysToWindow -Keys "{ENTER}" -DelayMs 300  # Next button
        Start-Sleep -Milliseconds 1500  # Reduced from 4 seconds
        
        # Step 3: Start installation - FASTER
        InfoMessage "Step 3: Starting installation..."
        Send-KeysToWindow -Keys "{ENTER}" -DelayMs 300  # Install button
        Start-Sleep -Milliseconds 1000  # Reduced from 3 seconds
        
        # Step 4: Handle any additional prompts - FASTER
        InfoMessage "Step 4: Handling installation prompts..."
        Send-KeysToWindow -Keys "{ENTER}" -DelayMs 300  # Continue/Next
        Start-Sleep -Milliseconds 800  # Reduced from 2 seconds
        
        # Step 5: Complete installation - FASTER
        InfoMessage "Step 5: Completing installation..."
        Send-KeysToWindow -Keys "{ENTER}" -DelayMs 300  # Finish button
        Start-Sleep -Milliseconds 800  # Reduced from 2 seconds
        
        # Wait for installation to complete
        $completed = Wait-ForInstallerCompletion
        
        if (-not $completed) {
            WarnMessage "Installation may not have completed properly. Forcing cleanup..."
            Stop-InstallerProcesses
        }
        
        # OPTIMIZED: Enhanced verification with reduced wait time
        InfoMessage "Waiting for installation to complete..."
        Start-Sleep -Seconds 3  # Reduced from 10 seconds
        
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
            Start-Sleep -Seconds 3  # Reduced from 10 seconds
        }
    }
    
    ErrorMessage "All installation attempts failed"
    return $false
}

# Main execution
function Main {
    InfoMessage "=== FAST Automated Npcap Installation Script ==="
    InfoMessage "This OPTIMIZED script will install Npcap using keyboard automation with reduced wait times"
    InfoMessage "Designed for headless Windows Server environments with enhanced detection and faster execution"
    
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
