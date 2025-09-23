# Streamlined Wazuh Agent Uninstall Script for Windows Server
# Uninstalls only the Wazuh Agent (aligned with simplified installation)

param(
    [switch]$Help
)

# Set strict mode for script execution
Set-StrictMode -Version Latest

# Variables
$LOG_LEVEL = if ($env:LOG_LEVEL) { $env:LOG_LEVEL } else { "INFO" }
$WAZUH_AGENT_VERSION = if ($env:WAZUH_AGENT_VERSION) { $env:WAZUH_AGENT_VERSION } else { "4.12.0-1" }

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
    Write-Host "Usage:  .\uninstall-server.ps1 [-Help]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This script uninstalls the Wazuh Agent from Windows Server environments." -ForegroundColor Cyan
    Write-Host "Streamlined for Wazuh Agent-only removal (aligned with simplified installation)." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Cyan
    Write-Host "  -Help                  : Displays this help message." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Environment Variables (optional):" -ForegroundColor Cyan
    Write-Host "  LOG_LEVEL              : Sets the logging level (e.g., INFO, DEBUG). Default: INFO" -ForegroundColor Cyan
    Write-Host "  WAZUH_AGENT_VERSION    : Sets the Wazuh Agent version. Default: 4.12.0-1" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\uninstall-server.ps1 -Help" -ForegroundColor Cyan
    Write-Host "  `$env:LOG_LEVEL='DEBUG'; .\uninstall-server.ps1" -ForegroundColor Cyan
    Write-Host ""
}



# Show help if -Help is specified
if ($Help) {
    Show-Help
    Exit 0
}

# Function to check if Wazuh Agent is installed
function Test-WazuhAgentInstalled {
    # Check for Wazuh service
    $wazuhService = Get-Service -Name "WazuhSvc" -ErrorAction SilentlyContinue
    if ($wazuhService) {
        return $true
    }
    
    # Check for installation directory
    $wazuhPath = "C:\Program Files (x86)\ossec-agent"
    if (Test-Path $wazuhPath) {
        return $true
    }
    
    # Check for installed program via WMI
    $wazuhProduct = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Wazuh Agent*" }
    if ($wazuhProduct) {
        return $true
    }
    
    return $false
}

# Function to uninstall Wazuh Agent
function Uninstall-WazuhAgent {
    # First check if Wazuh Agent is installed
    if (-not (Test-WazuhAgentInstalled)) {
        InfoMessage "Wazuh Agent is not installed on this system. Skipping uninstallation."
        return $true
    }
    
    InfoMessage "Wazuh Agent detected. Proceeding with uninstallation..."
    
    $UninstallerURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/refs/heads/feat/windows-server-agent/scripts/uninstall.ps1"
    $UninstallerPath = "$env:TEMP\uninstall-wazuh-agent.ps1"
    $global:UninstallerFiles += $UninstallerPath
    try {
        InfoMessage "Downloading and executing Wazuh agent uninstall script..."
        Invoke-WebRequest -Uri $UninstallerURL -OutFile $UninstallerPath -ErrorAction Stop
        InfoMessage "Wazuh agent uninstall script downloaded successfully."
        & PowerShell -ExecutionPolicy Bypass -File $UninstallerPath
        return $true
    } catch {
        ErrorMessage "Failed to download or execute Wazuh agent uninstall script: $($_.Exception.Message)"
        return $false
    }
}

# Main execution - streamlined to uninstall only Wazuh Agent
$overallSuccess = $true

try {
    SectionSeparator "Uninstalling Wazuh Agent"
    if (-not (Uninstall-WazuhAgent)) {
        ErrorMessage "Wazuh Agent uninstallation failed."
        $overallSuccess = $false
    }
    
} finally {
    InfoMessage "Cleaning up uninstaller files..."
    Remove-UninstallerFiles
    
    if ($overallSuccess) {
        SuccessMessage "Wazuh Agent Uninstallation Completed Successfully"
    } else {
        ErrorMessage "Wazuh Agent uninstallation encountered errors"
        exit 1
    }
}