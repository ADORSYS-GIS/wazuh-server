# Streamlined Wazuh Server Setup Script for Silent Windows Server Environments
# Core components: Dependencies, Wazuh Agent, and OAuth2 Certificate Authentication
# Optimized for SSH compatibility and minimal installation footprint

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
$WOPS_VERSION = if ($env:WOPS_VERSION) { $env:WOPS_VERSION } else { "0.2.18" }

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
    Write-Host "This script automates the streamlined installation of core Wazuh Agent components for Windows Server environments." -ForegroundColor Cyan
    Write-Host "Optimized for SSH compatibility and minimal installation footprint." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Components installed:" -ForegroundColor Yellow
    Write-Host "  - Dependencies (curl, jq, chocolatey, etc.)" -ForegroundColor White
    Write-Host "  - Wazuh Agent with silent installation" -ForegroundColor White
    Write-Host "  - OAuth2 Certificate Authentication" -ForegroundColor White
    Write-Host ""
    Write-Host "Requirements:" -ForegroundColor Yellow
    Write-Host "  - Administrator privileges" -ForegroundColor White
    Write-Host "  - Internet connectivity" -ForegroundColor White
    Write-Host "  - Windows Server 2016+ or Windows 10+" -ForegroundColor White
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -Help    Show this help message" -ForegroundColor White
    Write-Host ""
    Write-Host "Example:" -ForegroundColor Yellow
    Write-Host "  .\setup-server.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "Note: This streamlined version focuses on core SIEM functionality." -ForegroundColor Yellow
    Write-Host "For network monitoring (Suricata/Npcap), use the dedicated installation scripts." -ForegroundColor Yellow
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
    InfoMessage "=== Streamlined Wazuh Agent Setup for Silent Windows Server Environments ==="
    InfoMessage "Installing: Dependencies + Wazuh Agent + OAuth2 Certificate Authentication"
    InfoMessage "Optimized for SSH compatibility and minimal installation footprint"
    
    SectionSeparator "Installing Dependencies"
    Install-Dependencies
    
    SectionSeparator "Installing Wazuh Agent"
    Install-WazuhAgent
    
    SectionSeparator "Installing OAuth2 Certificate Authentication"
    Install-OAuth2Client
    
    SectionSeparator "Downloading Version File"
    DownloadVersionFile
    
    SuccessMessage "=== Streamlined Wazuh Agent Setup Completed Successfully ==="
    InfoMessage "Core components installed and configured:"
    InfoMessage "  [+] Dependencies (curl, jq, chocolatey, etc.)"
    InfoMessage "  [+] Wazuh Agent with silent installation"
    InfoMessage "  [+] OAuth2 Certificate Authentication"
    InfoMessage "  [+] All services configured for automatic startup"
    InfoMessage ""
    InfoMessage "This streamlined setup focuses on core SIEM functionality without network monitoring."
    InfoMessage "For network monitoring (Suricata/Npcap), use the full installation scripts separately."
}
catch {
    ErrorMessage "Setup failed: $($_.Exception.Message)"
    exit 1
}
finally {
    InfoMessage "Cleaning up installer files..."
    Cleanup-Installers
}
