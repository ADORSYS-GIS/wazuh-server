# Wazuh Agent Setup Script for Windows Server Environments
# Core components: Dependencies and Wazuh Agent only
# Matches the Linux setup-server.sh functionality

#Requires -RunAsAdministrator

param(
    [switch]$InstallCertOAuth2,
    [switch]$InstallSuricata,
    [switch]$Help
)

# Set strict mode for script execution
Set-StrictMode -Version Latest

# Variables
$WAZUH_MANAGER = if ($env:WAZUH_MANAGER) { $env:WAZUH_MANAGER } else { "wazuh.example.com" }
$WAZUH_AGENT_VERSION = if ($env:WAZUH_AGENT_VERSION) { $env:WAZUH_AGENT_VERSION } else { "4.14.2-1" }
$WAZUH_SERVER_TAG = if ($env:WAZUH_SERVER_TAG) { $env:WAZUH_SERVER_TAG } else { "0.1.7" }
$WAZUH_SURICATA_VERSION = if ($env:WAZUH_SURICATA_VERSION) { $env:WAZUH_SURICATA_VERSION } else { "0.1.5" }
$WOPS_VERSION = if ($env:WOPS_VERSION) { $env:WOPS_VERSION } else { "0.4.2" }
$APP_NAME = if ($env:APP_NAME) { $env:APP_NAME } else { "wazuh-cert-oauth2-client" }
$OSSEC_PATH = "C:\Program Files (x86)\ossec-agent\" 
$OSSEC_CONF_PATH = Join-Path -Path $OSSEC_PATH -ChildPath "ossec.conf"

$WAZUH_SERVER_REPO_REF = if ($env:WAZUH_SERVER_REPO_REF) { $env:WAZUH_SERVER_REPO_REF } else { "refs/tags/v$WAZUH_SERVER_TAG" }
$WAZUH_CERT_OAUTH2_REPO_REF = if ($env:WAZUH_CERT_OAUTH2_REPO_REF) { $env:WAZUH_CERT_OAUTH2_REPO_REF } else { "refs/tags/v$WOPS_VERSION" }
$WAZUH_SURICATA_REPO_REF = if ($env:WAZUH_SURICATA_REPO_REF) { $env:WAZUH_SURICATA_REPO_REF } else { "refs/tags/v$WAZUH_SURICATA_VERSION" }

$WAZUH_SERVER_REPO_URL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/$WAZUH_SERVER_REPO_REF"
$WAZUH_SURICATA_REPO_URL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/$WAZUH_SURICATA_REPO_REF"
$WAZUH_CERT_OAUTH2_REPO_URL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-cert-oauth2/$WAZUH_CERT_OAUTH2_REPO_REF"
$VERSION_FILE_URL = "$WAZUH_SERVER_REPO_URL/version.txt"
$VERSION_FILE_PATH = Join-Path -Path $OSSEC_PATH -ChildPath "version.txt"

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

# Global array to track installer files
$global:InstallerFiles = @()
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
    $InstallerPath = "$env:TEMP\deps.ps1"
    $global:InstallerFiles += $InstallerPath

    try {
        InfoMessage "Downloading and executing dependency script..."
        Download-And-VerifyFile -Url $WAZUH_SERVER_REPO_URL/scripts/windows/deps.ps1 -Destination $InstallerPath -ChecksumPattern "scripts/windows/deps.ps1" -FileName "deps.ps1" -ChecksumUrl "$WAZUH_SERVER_REPO_URL/checksums.sha256"
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
    $InstallerPath = "$env:TEMP\install.ps1"
    $global:InstallerFiles += $InstallerPath

    try {
        InfoMessage "Downloading and executing Wazuh agent script..."
        Download-And-VerifyFile -Url "$WAZUH_SERVER_REPO_URL/scripts/windows/install.ps1" -Destination $InstallerPath -ChecksumPattern "scripts/windows/install.ps1" -FileName "install.ps1" -ChecksumUrl "$WAZUH_SERVER_REPO_URL/checksums.sha256"
        & powershell.exe -ExecutionPolicy Bypass -File $InstallerPath -ErrorAction Stop
        SuccessMessage "Wazuh agent installed successfully"
    }
    catch {
        ErrorMessage "Error during Wazuh agent installation: $($_.Exception.Message)"
        throw
    }
}

function Install-OAuth2Client {
    $OAuth2Script = "$env:TEMP\wazuh-cert-oauth2-client-install.ps1"
    $global:InstallerFiles += $OAuth2Script

    try {
        InfoMessage "Downloading and executing wazuh-cert-oauth2-client script..."
        Download-And-VerifyFile -Url "$WAZUH_CERT_OAUTH2_REPO_URL/scripts/windows/install.ps1" -Destination $OAuth2Script -ChecksumPattern "scripts/windows/install.ps1" -FileName "wazuh-cert-oauth2-client-install.ps1" -ChecksumUrl "$WAZUH_CERT_OAUTH2_REPO_URL/checksums.sha256"
        & powershell.exe -ExecutionPolicy Bypass -File $OAuth2Script -ErrorAction Stop
        SuccessMessage "wazuh-cert-oauth2-client installed successfully"
    }
    catch {
        ErrorMessage "Error during wazuh-cert-oauth2-client installation: $($_.Exception.Message)"
    }
}

function Install-SuricataClient {
    $SuricataScript = "$env:TEMP\install-suricata-silent.ps1"
    $global:InstallerFiles += $SuricataScript

    try {
        InfoMessage "Downloading and executing silent Suricata installation script..."
        Download-And-VerifyFile -Url "$WAZUH_SURICATA_REPO_URL/scripts/windows/install-suricata-silent.ps1" -Destination $SuricataScript -ChecksumPattern "scripts/windows/install-suricata-silent.ps1" -FileName "install-suricata-silent.ps1" -ChecksumUrl "$WAZUH_SURICATA_REPO_URL/checksums.sha256"
        & powershell.exe -ExecutionPolicy Bypass -File $SuricataScript -ErrorAction Stop
        SuccessMessage "Suricata installed successfully with automated silent installation"
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
            Download-And-VerifyFile -Url $VERSION_FILE_URL -Destination $VERSION_FILE_PATH -ChecksumPattern "version.txt" -FileName "version.txt"
            SuccessMessage "Version file downloaded successfully"
        } catch {
            ErrorMessage "Failed to download version file: $($_.Exception.Message)"
        }
    }
}

function Show-Help {
    Write-Host "Usage:  .\setup-server.ps1 [-InstallCertOAuth2] [-InstallSuricata] [-Help]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Streamlined Wazuh Agent installation for Windows Server environments." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -InstallCertOAuth2    Install cert-oauth2 client (optional)" -ForegroundColor White
    Write-Host "  -InstallSuricata      Install Suricata with silent automation (optional)" -ForegroundColor White
    Write-Host "  -Help                 Show this help message" -ForegroundColor White
    Write-Host ""
    Write-Host "Environment Variables:" -ForegroundColor Yellow
    Write-Host "  WAZUH_MANAGER         Wazuh manager hostname (default: wazuh.example.com)" -ForegroundColor White
    Write-Host "  WAZUH_AGENT_VERSION   Agent version (default: 4.13.1-1)" -ForegroundColor White
    Write-Host "  WAZUH_SERVER_TAG      Repository tag (default: $WAZUH_SERVER_TAG)" -ForegroundColor White
    Write-Host "  WAZUH_SURICATA_VERSION Suricata version (default: $WAZUH_SURICATA_VERSION)" -ForegroundColor White
    Write-Host "  LOG_LEVEL             Logging level (default: INFO)" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\setup-server.ps1                                    # Core installation only" -ForegroundColor Cyan
    Write-Host "  .\setup-server.ps1 -InstallCertOAuth2                 # With cert-oauth2" -ForegroundColor Cyan
    Write-Host "  .\setup-server.ps1 -InstallSuricata                   # With silent Suricata" -ForegroundColor Cyan
    Write-Host "  $env:WAZUH_MANAGER='my-wazuh.com'; .\setup-server.ps1 -InstallCertOAuth2 -InstallSuricata" -ForegroundColor Cyan
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
        Install-OAuth2Client
    }
    
    # Install Suricata if the flag is set
    if ($InstallSuricata) {
        SectionSeparator "Installing Suricata"
        Install-SuricataClient
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
    if ($InstallSuricata) {
        InfoMessage "  [+] Suricata IDS with automated silent installation"
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
