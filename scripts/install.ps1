$WAZUH_MANAGER = if ($env:WAZUH_MANAGER) { $env:WAZUH_MANAGER } else { "wazuh.example.com" }
$WAZUH_AGENT_VERSION = if ($env:WAZUH_AGENT_VERSION) { $env:WAZUH_AGENT_VERSION } else { "4.13.1-1" }



# Global variables
$OSSEC_PATH = "C:\Program Files (x86)\ossec-agent\"
$OSSEC_CONF_PATH = Join-Path -Path $OSSEC_PATH -ChildPath "ossec.conf"
# Variables
$AgentFileName = "wazuh-agent-$WAZUH_AGENT_VERSION.msi"
$TempDir = $env:TEMP
$DownloadUrl = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$WAZUH_AGENT_VERSION.msi"
$MsiPath = Join-Path -Path $TempDir -ChildPath $AgentFileName




# Function for logging with timestamp
function Log {
    param (
        [string]$Level,
        [string]$Message,
        [string]$Color = "White"  # Default color
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$Timestamp $Level $Message" -ForegroundColor $Color
}


# Logging helpers with colors
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


function PrintStep {
    param (
        [int]$StepNumber,
        [string]$Message
    )
    Log "[STEP]" "Step ${StepNumber}: $Message" "White"
}


# Exit script with an error message
function ErrorExit {
    param ([string]$Message)
    ErrorMessage $Message
    exit 1
}


# Function to get installed Wazuh agent version
function Get-InstalledVersion {
    try {
        $wazuhProduct = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Wazuh Agent*" }
        if ($wazuhProduct) {
            return $wazuhProduct.Version
        }
        return $null
    } catch {
        return $null
    }
}

# Function to install Wazuh Agent
function Install-Agent {
    InfoMessage "[STEP 1/7] Validating system requirements..."
    
    # Check if system architecture is supported
    if (-not [System.Environment]::Is64BitOperatingSystem) {
        ErrorMessage "Unsupported architecture. Only 64-bit systems are supported."
        return $false
    }
    InfoMessage "System architecture: 64-bit (supported)"
    
    # Check installed version
    $installedVersion = Get-InstalledVersion
    if ($installedVersion) {
        if ($installedVersion -eq $WAZUH_AGENT_VERSION) {
            InfoMessage "Wazuh agent $WAZUH_AGENT_VERSION is already installed. Skipping installation."
            return $true
        } else {
            InfoMessage "Upgrading Wazuh agent ($installedVersion → $WAZUH_AGENT_VERSION)..."
        }
    } else {
        InfoMessage "Installing fresh Wazuh agent $WAZUH_AGENT_VERSION..."
    }


    InfoMessage "[STEP 2/7] Downloading Wazuh agent version $WAZUH_AGENT_VERSION..."
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $MsiPath -ErrorAction Stop
        InfoMessage "Download completed successfully. File size: $((Get-Item $MsiPath).Length) bytes"
    } catch {
        ErrorMessage "Failed to download Wazuh agent: $($_.Exception.Message)"
        return $false
    }


    InfoMessage "[STEP 3/7] Installing Wazuh agent silently..."
    
    # Filling up MSI installer arguments
    $MsiArguments = @(
        "/i", $MsiPath,
        "/q",
        "WAZUH_MANAGER=$WAZUH_MANAGER"
    )
    
    InfoMessage "Installation parameters: Manager=$WAZUH_MANAGER, Version=$WAZUH_AGENT_VERSION"
    
    try {
        $installProcess = Start-Process "msiexec.exe" -ArgumentList $MsiArguments -Wait -PassThru -ErrorAction Stop
        
        if ($installProcess.ExitCode -eq 0) {
            InfoMessage "Wazuh agent installer completed with exit code: $($installProcess.ExitCode)"
        } else {
            ErrorMessage "Wazuh agent installer failed with exit code: $($installProcess.ExitCode)"
            return $false
        }
    } catch {
        ErrorMessage "Failed to install Wazuh agent: $($_.Exception.Message)"
        return $false
    }


    InfoMessage "[STEP 4/7] Verifying installation..."
    
    # Verify installation directory exists
    if (-not (Test-Path $OSSEC_PATH)) {
        ErrorMessage "Wazuh installation directory not found at $OSSEC_PATH"
        return $false
    }
    InfoMessage "Installation directory verified: $OSSEC_PATH"
    
    # Verify configuration file exists
    if (-not (Test-Path $OSSEC_CONF_PATH)) {
        ErrorMessage "Wazuh configuration file not found at $OSSEC_CONF_PATH"
        return $false
    }
    
    InfoMessage "[STEP 5/7] Configuring Wazuh manager address..."
    # Update the manager address in the configuration file
    try {
        [xml]$configXml = Get-Content -Path $OSSEC_CONF_PATH -ErrorAction Stop
        $configXml.ossec_config.client.server.address = $WAZUH_MANAGER
        $configXml.Save($OSSEC_CONF_PATH)
        InfoMessage "Manager address updated successfully in ossec.conf: $WAZUH_MANAGER"
    } catch {
        ErrorMessage "Failed to update manager address: $($_.Exception.Message)"
        return $false
    }
    
    InfoMessage "[STEP 6/7] Configuring active response monitoring..."
    # Add active response log monitoring (matches Linux install.sh functionality)
    try {
        [xml]$configXml = Get-Content -Path $OSSEC_CONF_PATH -ErrorAction Stop
        
        # Check if active response localfile already exists
        $activeResponseExists = $false
        foreach ($localfile in $configXml.ossec_config.localfile) {
            if ($localfile.location -eq "C:\Program Files (x86)\ossec-agent\active-response\active-responses.log") {
                $activeResponseExists = $true
                break
            }
        }
        
        if (-not $activeResponseExists) {
            # Create new localfile element for active response logs
            $newLocalfile = $configXml.CreateElement("localfile")
            $logFormat = $configXml.CreateElement("log_format")
            $logFormat.InnerText = "syslog"
            $location = $configXml.CreateElement("location")
            $location.InnerText = "C:\Program Files (x86)\ossec-agent\active-response\active-responses.log"
            
            $newLocalfile.AppendChild($logFormat)
            $newLocalfile.AppendChild($location)
            $configXml.ossec_config.AppendChild($newLocalfile)
            
            $configXml.Save($OSSEC_CONF_PATH)
            InfoMessage "Active response logs are now being monitored"
        } else {
            InfoMessage "Active response monitoring already exists in ossec.conf"
        }
    } catch {
        WarnMessage "Failed to configure active response monitoring: $($_.Exception.Message)"
        # Don't fail installation for this
    }
    
    InfoMessage "[STEP 7/7] Starting Wazuh service..."
    # Start the Wazuh service
    try {
        Start-Service -Name "WazuhSvc" -ErrorAction Stop
        
        # Wait a moment and verify service is running
        Start-Sleep -Seconds 3
        $service = Get-Service -Name "WazuhSvc" -ErrorAction Stop
        
        if ($service.Status -eq 'Running') {
            InfoMessage "Wazuh service started and verified successfully. Status: $($service.Status)"
        } else {
            ErrorMessage "Wazuh service failed to start properly. Status: $($service.Status)"
            return $false
        }
    } catch {
        ErrorMessage "Failed to start Wazuh service: $($_.Exception.Message)"
        return $false
    }


    SuccessMessage "Wazuh agent installed and configured successfully!"
    return $true
}




function Remove-InstallerFiles {
    InfoMessage "Cleaning up installer files..."
    try {
        if (Test-Path $MsiPath) {
            Remove-Item -Path $MsiPath -Force -ErrorAction Stop
            InfoMessage "MSI installer file removed: $MsiPath"
        } else {
            InfoMessage "MSI installer file not found (may have been cleaned up already)"
        }
        return $true
    }
    catch {
        ErrorMessage "Failed to remove MSI installer file: $($_.Exception.Message)"
        return $false
    }
}


# Main execution with proper error handling and exit codes
$overallSuccess = $true


InfoMessage "Starting Wazuh agent installation process..."
InfoMessage "Target Manager: $WAZUH_MANAGER"
InfoMessage "Agent Version: $WAZUH_AGENT_VERSION"
InfoMessage "=" * 60


try {
    # Install Wazuh Agent
    InfoMessage "Installing Wazuh agent..."
    if (-not (Install-Agent)) {
        ErrorMessage "Wazuh agent installation failed."
        $overallSuccess = $false
    }
    
    InfoMessage "=" * 60
    
    
} finally {
    InfoMessage "=" * 60
    
    # Always attempt cleanup
    InfoMessage "Performing cleanup..."
    Remove-InstallerFiles | Out-Null
}


# Final status and exit
if ($overallSuccess) {
    SuccessMessage "Wazuh agent installation completed successfully!"
    InfoMessage "Agent is configured to connect to: $WAZUH_MANAGER"
    InfoMessage "Service status: $((Get-Service -Name 'WazuhSvc' -ErrorAction SilentlyContinue).Status)"
    exit 0
} else {
    ErrorMessage "Wazuh agent installation failed. Please check the logs above for details."
    exit 1
}
