# Wazuh Agent Setup Script for Windows Server Environments
# Core components: Dependencies and Wazuh Agent only
# Matches the Linux setup-server.sh functionality

#Requires -RunAsAdministrator

param(
    [switch]$Help
)

# Set strict mode for script execution
Set-StrictMode -Version Latest

# Variables (default log level, paths)
$LOG_LEVEL = if ($env:LOG_LEVEL) { $env:LOG_LEVEL } else { "INFO" }
$WAZUH_MANAGER = if ($env:WAZUH_MANAGER) { $env:WAZUH_MANAGER } else { "wazuh.example.com" }
$WAZUH_AGENT_VERSION = if ($env:WAZUH_AGENT_VERSION) { $env:WAZUH_AGENT_VERSION } else { "4.12.0-1" }
$WAZUH_SERVER_TAG = if ($env:WAZUH_SERVER_TAG) { $env:WAZUH_SERVER_TAG } else { "0.1.2-rc1" }
$OSSEC_PATH = "C:\Program Files (x86)\ossec-agent\" 
$OSSEC_CONF_PATH = Join-Path -Path $OSSEC_PATH -ChildPath "ossec.conf"
$RepoUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/refs/tags/v$WAZUH_SERVER_TAG"
$VERSION_FILE_URL = "$RepoUrl/version.txt"
$VERSION_FILE_PATH = Join-Path -Path $OSSEC_PATH -ChildPath "version.txt"

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
function Remove-InstallerFiles {
    foreach ($file in $global:InstallerFiles) {
        if (Test-Path $file) {
            Remove-Item $file -Force
            InfoMessage "Removed installer file: $file"
        }
    }
}

# Step 1: Download dependency script and execute
function Install-Dependencies {
    $InstallerURL = "$RepoUrl/scripts/deps.ps1"
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
    $InstallerURL = "$RepoUrl/scripts/install.ps1"
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
    Write-Host "Usage:  .\setup-server.ps1 [-InstallCertOAuth2] [-Help]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Streamlined Wazuh Agent installation for Windows Server environments." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -InstallCertOAuth2    Install cert-oauth2 client (optional)" -ForegroundColor White
    Write-Host "  -Help                 Show this help message" -ForegroundColor White
    Write-Host ""
    Write-Host "Environment Variables:" -ForegroundColor Yellow
    Write-Host "  WAZUH_MANAGER         Wazuh manager hostname (default: wazuh.example.com)" -ForegroundColor White
    Write-Host "  WAZUH_AGENT_VERSION   Agent version (default: 4.12.0-1)" -ForegroundColor White
    Write-Host "  WAZUH_SERVER_TAG      Repository tag (default: $WAZUH_SERVER_TAG)" -ForegroundColor White
    Write-Host "  LOG_LEVEL             Logging level (default: INFO)" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\setup-server.ps1                                    # Core installation only" -ForegroundColor Cyan
    Write-Host "  .\setup-server.ps1 -InstallCertOAuth2                 # With cert-oauth2" -ForegroundColor Cyan
    Write-Host "  $env:WAZUH_MANAGER='my-wazuh.com'; .\setup-server.ps1 -InstallCertOAuth2" -ForegroundColor Cyan
    Write-Host ""
}

# Show help if -Help is specified
if ($Help) {
    Show-Help
    Exit 0
}

# Main Execution wrapped in a try-finally to ensure cleanup runs even if errors occur.
try {
    InfoMessage "=== Wazuh Agent Setup for Windows Server Environments ==="
    InfoMessage "Installing: Dependencies + Wazuh Agent (matches Linux setup-server.sh)"
    
    SectionSeparator "Installing Dependencies"
    Install-Dependencies
    
    SectionSeparator "Installing Wazuh Agent"
    Install-WazuhAgent
    
    # Install cert-oauth2 if the flag is set
    if ($InstallCertOAuth2) {
        SectionSeparator "Installing cert-oauth2"
        Install-CertOAuth2
    }
    
    SectionSeparator "Downloading Version File"
    DownloadVersionFile
    
    SuccessMessage "=== Wazuh Agent Setup Completed Successfully ==="
    InfoMessage "Components installed and configured:"
    InfoMessage "  [+] Dependencies (curl, jq)"
    InfoMessage "  [+] Wazuh Agent with silent installation"
    if ($InstallCertOAuth2) {
        InfoMessage "  [+] cert-oauth2 client for enhanced security"
        InfoMessage "  [+] Run: C:\Program Files (x86)\ossec-agent\wazuh-cert-oauth2-client.exe o-auth2"
    }
    InfoMessage "  [+] Version file downloaded"
    InfoMessage ""
    InfoMessage "Setup complete. Wazuh Agent is ready for use."
}
catch {
    ErrorMessage "Setup failed: $($_.Exception.Message)"
    exit 1
}
finally {
    InfoMessage "Cleaning up installer files..."
    Remove-InstallerFiles
}
