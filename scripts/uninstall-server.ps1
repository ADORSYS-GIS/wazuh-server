# Streamlined Wazuh Agent Uninstall Script for Windows Server
# Uninstalls only the Wazuh Agent (aligned with simplified installation)
#Requires -RunAsAdministrator

param(
    [switch]$UninstallCertOAuth2,
    [switch]$UninstallSuricata,
    [switch]$Help
)

# Set strict mode for script execution
Set-StrictMode -Version Latest

# Variables
$LOG_LEVEL = if ($env:LOG_LEVEL) { $env:LOG_LEVEL } else { "INFO" }
$WAZUH_SERVER_TAG = if ($env:WAZUH_SERVER_TAG) { $env:WAZUH_SERVER_TAG } else { "0.1.3" }
$RepoUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/refs/tags/v$WAZUH_SERVER_TAG"
$SuricataRepoUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/refs/heads/feature/automated-powershell-installation"

# Global array to track uninstaller files
$global:UninstallerFiles = @()

# Function to log messages with a timestamp and color
function Log {
    param (
        [string]$Level,
        [string]$Message,
        [string]$Color = "White"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$Timestamp $Level $Message" -ForegroundColor $Color
}

function InfoMessage { param([string]$Message) Log "[INFO]" $Message "Cyan" }
function WarningMessage { param([string]$Message) Log "[WARNING]" $Message "Yellow" }
function SuccessMessage { param([string]$Message) Log "[SUCCESS]" $Message "Green" }
function ErrorMessage { param([string]$Message) Log "[ERROR]" $Message "Red" }
function SectionSeparator {
    param ([string]$SectionName)
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Magenta
    Write-Host "  $SectionName" -ForegroundColor Magenta
    Write-Host "==================================================" -ForegroundColor Magenta
    Write-Host ""
}

# Cleanup function to remove uninstaller files at the end
function Remove-UninstallerFiles {
    foreach ($file in $global:UninstallerFiles) {
        if (Test-Path $file) {
            Remove-Item $file -Force
            InfoMessage "Removed uninstaller file: $file"
        }
    }
}

# Help Function
function Show-Help {
    Write-Host "Usage:  .\uninstall-server.ps1 [-UninstallCertOAuth2] [-UninstallSuricata] [-Help]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This script uninstalls the Wazuh Agent from Windows Server environments." -ForegroundColor Cyan
    Write-Host "Streamlined for Wazuh Agent removal with optional Suricata uninstallation." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Cyan
    Write-Host "  -UninstallCertOAuth2   : Also uninstall cert-oauth2 client (optional)" -ForegroundColor Cyan
    Write-Host "  -UninstallSuricata     : Also uninstall Suricata with automated cleanup (optional)" -ForegroundColor Cyan
    Write-Host "  -Help                  : Displays this help message." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Environment Variables (optional):" -ForegroundColor Cyan
    Write-Host "  LOG_LEVEL              : Sets the logging level (e.g., INFO, DEBUG). Default: INFO" -ForegroundColor Cyan
    Write-Host "  WAZUH_SERVER_TAG       : Repository tag to fetch uninstall script. Default: $WAZUH_SERVER_TAG" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\uninstall-server.ps1 -Help" -ForegroundColor Cyan
    Write-Host "  `$env:LOG_LEVEL='DEBUG'; .\uninstall-server.ps1" -ForegroundColor Cyan
    Write-Host "  `$env:WAZUH_SERVER_TAG='0.1.2-rc1'; .\uninstall-server.ps1" -ForegroundColor Cyan
    Write-Host ""
}

# Show help if -Help is specified
if ($Help) {
    Show-Help
    Exit 0
}

# Function to uninstall cert-oauth2 client
function Uninstall-OAuth2Client {
    $UninstallerURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-cert-oauth2/refs/tags/v0.2.18/scripts/uninstall.ps1"
    $UninstallerPath = "$env:TEMP\uninstall-cert-oauth2.ps1"
    $global:UninstallerFiles += $UninstallerPath

    $maxAttempts = 3
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            InfoMessage "Downloading cert-oauth2 uninstall script (attempt $attempt of $maxAttempts)..."
            Invoke-WebRequest -Uri $UninstallerURL -OutFile $UninstallerPath -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
            if ((Get-Item $UninstallerPath).Length -le 64) {
                throw "Downloaded file appears too small or empty."
            }
            InfoMessage "cert-oauth2 uninstall script downloaded successfully. Executing..."
            & PowerShell -ExecutionPolicy Bypass -File $UninstallerPath
            SuccessMessage "cert-oauth2 client uninstallation completed"
            return $true
        }
        catch {
            WarningMessage "Attempt $attempt failed: $($_.Exception.Message)"
            Start-Sleep -Seconds (2 * $attempt)
        }
    }

    ErrorMessage "Failed to download or execute cert-oauth2 uninstall script after $maxAttempts attempts."
    return $false
}

# Function to uninstall Suricata using automated script
function Uninstall-SuricataClient {
    $UninstallerURL = "$SuricataRepoUrl/scripts/uninstall-automated.ps1"
    $UninstallerPath = "$env:TEMP\uninstall-suricata-automated.ps1"
    $global:UninstallerFiles += $UninstallerPath

    $maxAttempts = 3
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            InfoMessage "Downloading automated Suricata uninstall script (attempt $attempt of $maxAttempts)..."
            Invoke-WebRequest -Uri $UninstallerURL -OutFile $UninstallerPath -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
            if ((Get-Item $UninstallerPath).Length -le 64) {
                throw "Downloaded file appears too small or empty."
            }
            InfoMessage "Automated Suricata uninstall script downloaded successfully. Executing..."
            & PowerShell -ExecutionPolicy Bypass -File $UninstallerPath
            SuccessMessage "Suricata automated uninstallation completed"
            return $true
        }
        catch {
            WarningMessage "Attempt $attempt failed: $($_.Exception.Message)"
            Start-Sleep -Seconds (2 * $attempt)
        }
    }

    ErrorMessage "Failed to download or execute automated Suricata uninstall script after $maxAttempts attempts."
    return $false
}

# Function to uninstall Wazuh Agent by delegating to inner script
function Uninstall-WazuhAgent {
    $UninstallerURL = "$RepoUrl/scripts/uninstall.ps1"
    $UninstallerPath = "$env:TEMP\uninstall-wazuh-agent.ps1"
    $global:UninstallerFiles += $UninstallerPath

    $maxAttempts = 3
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            InfoMessage "Downloading Wazuh agent uninstall script (attempt $attempt of $maxAttempts)..."
            Invoke-WebRequest -Uri $UninstallerURL -OutFile $UninstallerPath -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
            if ((Get-Item $UninstallerPath).Length -le 64) {
                throw "Downloaded file appears too small or empty."
            }
            InfoMessage "Wazuh agent uninstall script downloaded successfully. Executing..."
            & PowerShell -ExecutionPolicy Bypass -File $UninstallerPath
            return $true
        }
        catch {
            WarningMessage "Attempt $attempt failed: $($_.Exception.Message)"
            Start-Sleep -Seconds (2 * $attempt)
        }
    }

    ErrorMessage "Failed to download or execute Wazuh agent uninstall script after $maxAttempts attempts."
    return $false
}

# Main execution - streamlined to uninstall only Wazuh Agent
$overallSuccess = $true

try {
    # Uninstall cert-oauth2 if the flag is set
    if ($UninstallCertOAuth2) {
        SectionSeparator "Uninstalling cert-oauth2 Client"
        if (-not (Uninstall-OAuth2Client)) {
            ErrorMessage "cert-oauth2 client uninstallation failed."
            $overallSuccess = $false
        }
    }
    
    # Uninstall Suricata if the flag is set
    if ($UninstallSuricata) {
        SectionSeparator "Uninstalling Suricata"
        if (-not (Uninstall-SuricataClient)) {
            ErrorMessage "Suricata uninstallation failed."
            $overallSuccess = $false
        }
    }
    
    SectionSeparator "Uninstalling Wazuh Agent"
    if (-not (Uninstall-WazuhAgent)) {
        ErrorMessage "Wazuh Agent uninstallation failed."
        $overallSuccess = $false
    }
}
finally {
    InfoMessage "Cleaning up uninstaller files..."
    Remove-UninstallerFiles

    if ($overallSuccess) {
        SuccessMessage "Wazuh Agent Uninstallation Completed Successfully"
    }
    else {
        ErrorMessage "Wazuh Agent uninstallation encountered errors"
        exit 1
    }
}