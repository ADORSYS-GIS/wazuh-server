# PowerShell script to install core dependencies for Wazuh Agent on Windows
# This script installs only essential dependencies: curl and jq (aligned with Linux deps.sh)

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

# Logging helpers
function InfoMessage {
    param ([string]$Message)
    Log "[INFO]" $Message "White"
}

function ErrorMessage {
    param ([string]$Message)
    Log "[ERROR]" $Message "Red"
}

function SuccessMessage {
    param ([string]$Message)
    Log "[SUCCESS]" $Message "Green"
}

# Function to install core dependencies (curl and jq only)
function Install-CoreDependencies {
    InfoMessage "Installing core dependencies: curl and jq"
    
    # Check if curl is available
    if (-not (Get-Command curl -ErrorAction SilentlyContinue)) {
        InfoMessage "Installing curl..."
        try {
            Invoke-WebRequest -Uri "https://curl.se/windows/dl-7.79.1_2/curl-7.79.1_2-win64-mingw.zip" -OutFile "$env:TEMP\curl.zip" -ErrorAction Stop
            Expand-Archive -Path "$env:TEMP\curl.zip" -DestinationPath "$env:TEMP\curl" -ErrorAction Stop
            New-Item -ItemType Directory -Path "C:\Program Files\curl" -Force | Out-Null
            Move-Item -Path "$env:TEMP\curl\curl-7.79.1_2-win64-mingw\bin\curl.exe" -Destination "C:\Program Files\curl\curl.exe" -ErrorAction Stop
            
            # Add to PATH
            $currentPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
            if ($currentPath -notlike "*C:\Program Files\curl*") {
                [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;C:\Program Files\curl", [System.EnvironmentVariableTarget]::Machine)
                $env:Path += ";C:\Program Files\curl"
            }
            
            # Cleanup
            Remove-Item -Path "$env:TEMP\curl.zip" -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "$env:TEMP\curl" -Recurse -Force -ErrorAction SilentlyContinue
            
            InfoMessage "curl installed successfully"
        } catch {
            ErrorMessage "Failed to install curl: $($_.Exception.Message)"
            return $false
        }
    } else {
        InfoMessage "curl is already available"
    }

    # Check if jq is available
    if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
        InfoMessage "Installing jq..."
        try {
            New-Item -ItemType Directory -Path "C:\Program Files\jq" -Force | Out-Null
            Invoke-WebRequest -Uri "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-win64.exe" -OutFile "C:\Program Files\jq\jq.exe" -ErrorAction Stop
            
            # Add to PATH
            $currentPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
            if ($currentPath -notlike "*C:\Program Files\jq*") {
                [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;C:\Program Files\jq", [System.EnvironmentVariableTarget]::Machine)
                $env:Path += ";C:\Program Files\jq"
            }
            
            InfoMessage "jq installed successfully"
        } catch {
            ErrorMessage "Failed to install jq: $($_.Exception.Message)"
            return $false
        }
    } else {
        InfoMessage "jq is already available"
    }
    
    return $true
}

# Main execution
InfoMessage "=== Wazuh Agent Dependencies Installation ==="
InfoMessage "Installing core dependencies (aligned with Linux deps.sh)"
InfoMessage "Dependencies: curl, jq"
InfoMessage "=" * 50

try {
    if (Install-CoreDependencies) {
        SuccessMessage "All core dependencies installed successfully!"
        exit 0
    } else {
        ErrorMessage "Failed to install some dependencies"
        exit 1
    }
} catch {
    ErrorMessage "Dependency installation failed: $($_.Exception.Message)"
    exit 1
}
