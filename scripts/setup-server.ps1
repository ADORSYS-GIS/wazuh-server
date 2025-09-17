# Optimized Wazuh Server Setup Script for Silent Windows Server Environments
# This version focuses on dependencies, Suricata, and Npcap installation only
# Simplified from the original multi-component setup script

#Requires -RunAsAdministrator

param(
    [switch]$Help
)

# Set strict mode for script execution
Set-StrictMode -Version Latest

# Variables (default log level, app details, paths)
$LOG_LEVEL = if ($env:LOG_LEVEL) { $env:LOG_LEVEL } else { "INFO" }
$APP_NAME = if ($env:APP_NAME) { $env:APP_NAME } else { "wazuh-cert-oauth2-client" }
$WAZUH_MANAGER = if ($env:WAZUH_MANAGER) { $env:WAZUH_MANAGER } else { "wazuh.example.com" }
$WAZUH_AGENT_VERSION = if ($env:WAZUH_AGENT_VERSION) { $env:WAZUH_AGENT_VERSION } else { "4.12.0-1" }
$OSSEC_PATH = "C:\Program Files (x86)\ossec-agent\" 
$OSSEC_CONF_PATH = Join-Path -Path $OSSEC_PATH -ChildPath "ossec.conf"
$RepoUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/main"
$VERSION_FILE_URL = "$RepoUrl/version.txt"
$VERSION_FILE_PATH = Join-Path -Path $OSSEC_PATH -ChildPath "version.txt"
$TEMP_DIR = [System.IO.Path]::GetTempPath()
$WAZUH_YARA_VERSION = if ($env:WAZUH_YARA_VERSION) { $env:WAZUH_YARA_VERSION } else { "0.3.11" }
$WAZUH_SNORT_VERSION = if ($env:WAZUH_SNORT_VERSION) { $env:WAZUH_SNORT_VERSION } else { "0.2.4" }
$WOPS_VERSION = if ($env:WOPS_VERSION) { $env:WOPS_VERSION } else { "0.2.18" }
$WAZUH_SURICATA_VERSION = if ($env:WAZUH_SURICATA_VERSION) { $env:WAZUH_SURICATA_VERSION } else { "0.1.4" }

# Global array to track installer files
$global:InstallerFiles = @()

# Function to log messages with a timestamp
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
    Log "[INFO]" $Message "Cyan"
}

function WarningMessage {
    param ([string]$Message)
    Log "[WARNING]" $Message "Yellow"
}

function SuccessMessage {
    param ([string]$Message)
    Log "[SUCCESS]" $Message "Green"
}

function ErrorMessage {
    param ([string]$Message)
    Log "[ERROR]" $Message "Red"
}

function SectionSeparator {
    param (
        [string]$SectionName
    )
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Magenta
    Write-Host "  $SectionName" -ForegroundColor Magenta
    Write-Host "==================================================" -ForegroundColor Magenta
    Write-Host ""
}

# Cleanup function to remove installer files at the end
function Cleanup-Installers {
    foreach ($file in $global:InstallerFiles) {
        if (Test-Path $file) {
            Remove-Item $file -Force
            InfoMessage "Removed installer file: $file"
        }
    }
}

# Step 1: Download dependency script and execute
function Install-Dependencies {
    $InstallerURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/feature/silent-windows-server-scripts/scripts/deps.ps1"
    $InstallerPath = "$env:TEMP\deps.ps1"
    $global:InstallerFiles += $InstallerPath

    try {
        InfoMessage "Downloading and executing dependency script..."
        Invoke-WebRequest -Uri $InstallerURL -OutFile $InstallerPath -ErrorAction Stop
        InfoMessage "Dependency script downloaded successfully."
        & powershell.exe -ExecutionPolicy Bypass -File $InstallerPath -ErrorAction Stop
        SuccessMessage "Dependencies installed successfully"
    }
    catch {
        ErrorMessage "Error during dependency installation: $($_.Exception.Message)"
        throw
    }
}

# Step 2: Download and execute Wazuh agent script with error handling
function Install-WazuhAgent {
    $InstallerURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/feature/silent-windows-server-scripts/scripts/install.ps1"
    $InstallerPath = "$env:TEMP\install.ps1"
    $global:InstallerFiles += $InstallerPath

    try {
        InfoMessage "Downloading and executing Wazuh agent script..."
        Invoke-WebRequest -Uri $InstallerURL -OutFile $InstallerPath -ErrorAction Stop
        InfoMessage "Wazuh agent script downloaded successfully."
        & powershell.exe -ExecutionPolicy Bypass -File $InstallerPath -ErrorAction Stop
        SuccessMessage "Wazuh agent installed successfully"
    }
    catch {
        ErrorMessage "Error during Wazuh agent installation: $($_.Exception.Message)"
        throw
    }
}

# Step 3: Download and install wazuh-cert-oauth2-client with error handling
function Install-OAuth2Client {
    $OAuth2Url = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-cert-oauth2/refs/tags/v$WOPS_VERSION/scripts/install.ps1"
    $OAuth2Script = "$env:TEMP\wazuh-cert-oauth2-client-install.ps1"
    $global:InstallerFiles += $OAuth2Script

    try {
        InfoMessage "Downloading and executing wazuh-cert-oauth2-client script..."
        Invoke-WebRequest -Uri $OAuth2Url -OutFile $OAuth2Script -ErrorAction Stop
        InfoMessage "wazuh-cert-oauth2-client script downloaded successfully."
        & powershell.exe -ExecutionPolicy Bypass -File $OAuth2Script -ArgumentList "-LOG_LEVEL", $LOG_LEVEL, "-OSSEC_CONF_PATH", $OSSEC_CONF_PATH, "-APP_NAME", $APP_NAME, "-WOPS_VERSION", $WOPS_VERSION -ErrorAction Stop
        SuccessMessage "OAuth2 cert authentication installed successfully"
    }
    catch {
        ErrorMessage "Error during wazuh-cert-oauth2-client installation: $($_.Exception.Message)"
        throw
    }
}

# Step 4: Download and install YARA with error handling
function Install-Yara {
    $YaraUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/refs/tags/v$WAZUH_YARA_VERSION/scripts/install.ps1"
    $YaraScript = "$env:TEMP\install_yara.ps1"
    $global:InstallerFiles += $YaraScript

    try {
        InfoMessage "Downloading and executing YARA installation script..."
        Invoke-WebRequest -Uri $YaraUrl -OutFile $YaraScript -ErrorAction Stop
        InfoMessage "YARA installation script downloaded successfully."
        & powershell.exe -ExecutionPolicy Bypass -File $YaraScript -ErrorAction Stop
        SuccessMessage "YARA installed successfully"
    }
    catch {
        ErrorMessage "Error during YARA installation: $($_.Exception.Message)"
        throw
    }
}


# Step 6: Download and execute Silent Suricata installation (includes Npcap)
function Install-SuricataWithNpcap {
    $SuricataURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/feature/silent-windows-server-scripts/scripts/install-suricata-silent.ps1"
    $SuricataPath = "$env:TEMP\install-suricata-silent.ps1"
    $global:InstallerFiles += $SuricataPath

    try {
        InfoMessage "Downloading and executing Silent Suricata installation script (includes automated Npcap)..."
        Invoke-WebRequest -Uri $SuricataURL -OutFile $SuricataPath -ErrorAction Stop
        InfoMessage "Silent Suricata script downloaded successfully."
        & powershell.exe -ExecutionPolicy Bypass -File $SuricataPath -ErrorAction Stop
        SuccessMessage "Suricata and Npcap installed successfully"
    }
    catch {
        ErrorMessage "Error during Suricata installation: $($_.Exception.Message)"
        throw
    }
}

function DownloadVersionFile {
    InfoMessage "Downloading version file..."
    if (!(Test-Path -Path $OSSEC_PATH)) {
        WarningMessage "ossec-agent folder does not exist. Skipping."
    }
    else {
        try {
            Invoke-WebRequest -Uri $VERSION_FILE_URL -OutFile $VERSION_FILE_PATH -ErrorAction Stop
            SuccessMessage "Version file downloaded successfully"
        } catch {
            ErrorMessage "Failed to download version file: $($_.Exception.Message)"
        }
    }
}

function Show-Help {
    Write-Host "Usage:  .\setup-server.ps1 [-Help]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This script automates the complete installation of Wazuh Agent and security components for Windows Server environments." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Components Installed:" -ForegroundColor Cyan
    Write-Host "  - Dependencies (curl, jq, chocolatey, etc.) - SILENT" -ForegroundColor Cyan
    Write-Host "  - Wazuh Agent - SILENT" -ForegroundColor Cyan
    Write-Host "  - OAuth2 Certificate Authentication - SILENT" -ForegroundColor Cyan
    Write-Host "  - YARA malware detection - SILENT" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan
    Write-Host "  - Suricata IDS with automated Npcap - SILENT" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Cyan
    Write-Host "  -Help              : Displays this help message." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Environment Variables (optional):" -ForegroundColor Cyan
    Write-Host "  LOG_LEVEL          : Sets the logging level (e.g., INFO, DEBUG). Default: INFO" -ForegroundColor Cyan
    Write-Host "  APP_NAME           : Sets the application name. Default: wazuh-cert-oauth2-client" -ForegroundColor Cyan
    Write-Host "  WAZUH_MANAGER      : Sets the Wazuh Manager address. Default: wazuh.example.com" -ForegroundColor Cyan
    Write-Host "  WAZUH_AGENT_VERSION: Sets the Wazuh Agent version. Default: 4.12.0-1" -ForegroundColor Cyan
    Write-Host "  WAZUH_YARA_VERSION : Sets the Wazuh YARA module version. Default: 0.3.11" -ForegroundColor Cyan
    Write-Host "  WAZUH_SURICATA_VERSION: Sets the Wazuh Suricata module version. Default: 0.1.4" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan
    Write-Host "  WOPS_VERSION       : Sets the WOPS client version. Default: 0.2.18" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\setup-server.ps1" -ForegroundColor Cyan
    Write-Host "  $env:LOG_LEVEL='DEBUG'; .\setup-server.ps1" -ForegroundColor Cyan
    Write-Host ""
}

# Show help if -Help is specified
if ($Help) {
    Show-Help
    Exit 0
}

# Main Execution wrapped in a try-finally to ensure cleanup runs even if errors occur.
try {
    InfoMessage "=== COMPLETE Wazuh Agent Setup for Silent Windows Server Environments ==="
    InfoMessage "Installing: Dependencies + Wazuh Agent + OAuth2 Auth + YARA + Suricata + Npcap"
    
    SectionSeparator "Installing Dependencies"
    Install-Dependencies
    
    SectionSeparator "Installing Wazuh Agent"
    Install-WazuhAgent
    
    SectionSeparator "Installing OAuth2 Certificate Authentication"
    Install-OAuth2Client
    
    SectionSeparator "Installing YARA Malware Detection"
    Install-Yara
    
    SectionSeparator "Installing Suricata IDS with Automated Npcap"
    Install-SuricataWithNpcap
    
    SectionSeparator "Downloading Version File"
    DownloadVersionFile
    
    SuccessMessage "=== COMPLETE Wazuh Agent Setup Completed Successfully ==="
    InfoMessage "All components installed and configured:"
    InfoMessage "  [+] Dependencies (curl, jq, chocolatey, etc.)"
    InfoMessage "  [+] Wazuh Agent with silent installation"
    InfoMessage "  [+] OAuth2 Certificate Authentication"
    InfoMessage "  [+] YARA malware detection engine"
    InfoMessage "  [+] Suricata IDS with automated Npcap (no GUI)"
    InfoMessage "  [+] All services configured for automatic startup"
}
catch {
    ErrorMessage "Setup failed: $($_.Exception.Message)"
    exit 1
}
finally {
    InfoMessage "Cleaning up installer files..."
    Cleanup-Installers
}
