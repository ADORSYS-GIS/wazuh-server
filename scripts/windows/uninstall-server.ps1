# Streamlined Wazuh Agent Uninstall Script for Windows Server
# Uninstalls only the Wazuh Agent (aligned with simplified installation)
#Requires -RunAsAdministrator

param(
    [switch]$UninstallSuricata,
    [switch]$Help
)

# Set strict mode for script execution
Set-StrictMode -Version Latest

# Variables
$WAZUH_SERVER_TAG = if ($env:WAZUH_SERVER_TAG) { $env:WAZUH_SERVER_TAG } else { "0.1.7" }
$WAZUH_SURICATA_VERSION = if ($env:WAZUH_SURICATA_VERSION) { $env:WAZUH_SURICATA_VERSION } else { "0.1.5" }

$WAZUH_SERVER_REPO_REF = if ($env:WAZUH_SERVER_REPO_REF) { $env:WAZUH_SERVER_REPO_REF } else { "refs/tags/v$WAZUH_SERVER_TAG" }
$WAZUH_CERT_OAUTH2_REPO_REF = if ($env:WAZUH_CERT_OAUTH2_REPO_REF) { $env:WAZUH_CERT_OAUTH2_REPO_REF } else { "refs/tags/v$WOPS_VERSION" }
$WAZUH_SURICATA_REPO_REF = if ($env:WAZUH_SURICATA_REPO_REF) { $env:WAZUH_SURICATA_REPO_REF } else { "refs/tags/v$WAZUH_SURICATA_VERSION" }
$REPO_URL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/$WAZUH_SERVER_REPO_REF"

$WAZUH_SERVER_REPO_URL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/$WAZUH_SERVER_REPO_REF"
$WAZUH_SURICATA_REPO_URL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/$WAZUH_SURICATA_REPO_REF"
$WAZUH_CERT_OAUTH2_REPO_URL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-cert-oauth2/$WAZUH_CERT_OAUTH2_REPO_REF"
$SuricataRepoUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/$WAZUH_SURICATA_REPO_REF"

# Create a secure temporary directory for utilities
$UtilsTmp = Join-Path $env:TEMP "wazuh-utils-$(Get-Random)"
New-Item -ItemType Directory -Path $UtilsTmp -Force | Out-Null

# Source shared utilities
try {
    $ChecksumsURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/$WAZUH_SERVER_REPO_REF/checksums.sha256"
    $UtilsURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/$WAZUH_SERVER_REPO_REF/scripts/shared/utils.ps1"

    $global:ChecksumsPath = Join-Path $UtilsTmp "checksums.sha256"
    $UtilsPath = Join-Path $UtilsTmp "utils.ps1"

    Invoke-WebRequest -Uri $ChecksumsURL -OutFile $ChecksumsPath -ErrorAction Stop
    Invoke-WebRequest -Uri $UtilsURL -OutFile $UtilsPath -ErrorAction Stop

    # Verification function (bootstrap)
    function Get-FileChecksum-Bootstrap {
        param([string]$FilePath)
        return (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.ToLower()
    }

    $ExpectedHash = (Select-String -Path $ChecksumsPath -Pattern "scripts/shared/utils.ps1").Line.Split(" ")[0]
    $ActualHash = Get-FileChecksum-Bootstrap -FilePath $UtilsPath

    if ([string]::IsNullOrWhiteSpace($ExpectedHash) -or ($ActualHash -ne $ExpectedHash.ToLower())) {
        Write-Error "Checksum verification failed for utils.ps1"
        exit 1
    }

    . $UtilsPath
}
catch {
    Write-Error "Failed to initialize utilities: $($_.Exception.Message)"
    exit 1
}

# Global array to track uninstaller files
$global:UninstallerFiles = @()

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
    Write-Host "Usage:  .\uninstall-server.ps1 [-UninstallSuricata] [-Help]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This script uninstalls the Wazuh Agent from Windows Server environments." -ForegroundColor Cyan
    Write-Host "Streamlined for Wazuh Agent removal with optional Suricata uninstallation." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Cyan
    Write-Host "  -UninstallSuricata     : Also uninstall Suricata with automated cleanup (optional)" -ForegroundColor Cyan
    Write-Host "  -Help                  : Displays this help message." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Environment Variables (optional):" -ForegroundColor Cyan
    Write-Host "  LOG_LEVEL              : Sets the logging level (e.g., INFO, DEBUG). Default: INFO" -ForegroundColor Cyan
    Write-Host "  WAZUH_SERVER_TAG       : Repository tag to fetch uninstall script. Default: $WAZUH_SERVER_TAG" -ForegroundColor Cyan
    Write-Host "  WAZUH_SURICATA_VERSION : Suricata version to uninstall. Default: $WAZUH_SURICATA_VERSION" -ForegroundColor Cyan
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


# Function to uninstall Suricata using automated script
function Uninstall-SuricataClient {
    $UninstallerPath = "$env:TEMP\uninstall-suricata-automated.ps1"
    $global:UninstallerFiles += $UninstallerPath

    $maxAttempts = 3
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            InfoMessage "Downloading automated Suricata uninstall script (attempt $attempt of $maxAttempts)..."
            Download-And-VerifyFile -Url "$WAZUH_SURICATA_REPO_URL/scripts/windows/uninstall-automated.ps1" -Destination $UninstallerPath -ChecksumPattern "scripts/windows/uninstall-automated.ps1" -FileName "uninstall-suricata-automated.ps1"
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
    $UninstallerPath = "$env:TEMP\uninstall-wazuh-agent.ps1"
    $global:UninstallerFiles += $UninstallerPath

    $maxAttempts = 3
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            InfoMessage "Downloading Wazuh agent uninstall script (attempt $attempt of $maxAttempts)..."
            Download-And-VerifyFile -Url "$WAZUH_SERVER_REPO_URL/scripts/windows/uninstall.ps1" -Destination $UninstallerPath -ChecksumPattern "scripts/windows/uninstall.ps1" -FileName "uninstall-wazuh-agent.ps1" -ChecksumUrl "$WAZUH_SERVER_REPO_URL/checksums.sha256"
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