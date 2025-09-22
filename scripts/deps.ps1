# PowerShell script to install dependencies for Wazuh on Windows
# This script installs Visual C++ Redistributable, GNU sed, curl, and jq

# Function to log messages with a timestamp
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

function Ensure-Dependencies {
    InfoMessage "Ensuring dependencies are installed (curl, jq)"   

    # Check if curl is available
    if (-not (Get-Command curl -ErrorAction SilentlyContinue)) {
        InfoMessage "curl is not installed. Installing curl..."
        Invoke-WebRequest -Uri "https://curl.se/windows/dl-7.79.1_2/curl-7.79.1_2-win64-mingw.zip" -OutFile "$env:TEMP\curl.zip"
        Expand-Archive -Path "$env:TEMP\curl.zip" -DestinationPath "$env:TEMP\curl"
        Move-Item -Path "$env:TEMP\curl\curl-7.79.1_2-win64-mingw\bin\curl.exe" -Destination "C:\Program Files\curl.exe"
        Remove-Item -Path "$env:TEMP\curl.zip" -Recurse
        Remove-Item -Path "$env:TEMP\curl" -Recurse
        InfoMessage "curl installed successfully."

        # Add curl to the PATH environment variable
        $env:Path += ";C:\Program Files"
        [System.Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::Machine)
        InfoMessage "curl added to PATH environment variable."
    }

    # Check if jq is available
    if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
        InfoMessage "jq is not installed. Installing jq..."
        Invoke-WebRequest -Uri "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-win64.exe" -OutFile "C:\Program Files\jq.exe"
        InfoMessage "jq installed successfully."

        # Add jq to the PATH environment variable
        $env:Path += ";C:\Program Files"
        [System.Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::Machine)
        InfoMessage "jq added to PATH environment variable."
    }
}


function Install-BurntToastModule {
    [CmdletBinding()]
    param()

    try {
        InfoMessage "[STEP 1/3] Checking NuGet provider installation..."
        # Check if the NuGet provider is installed (minimum version 2.8.5.201) without using a variable.
        if (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue) {
            InfoMessage "NuGet provider is already installed."
        }
        else {
            InfoMessage "NuGet provider not found. Installing NuGet provider..."
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop
            InfoMessage "NuGet provider installed successfully."
        }

        InfoMessage "[STEP 2/3] Checking BurntToast module installation..."
        # Check if the BurntToast module is already installed.
        if (Get-Module -ListAvailable -Name BurntToast -ErrorAction SilentlyContinue) {
            InfoMessage "Module 'BurntToast' is already installed."
        }
        else {
            InfoMessage "BurntToast Module not found. Installing module 'BurntToast'..."
            Install-Module -Name BurntToast -Force -Confirm:$false -ErrorAction Stop
            InfoMessage "Module 'BurntToast' installed successfully."
        }

        InfoMessage "[STEP 3/3] Importing BurntToast module..."
        # Import the BurntToast module to ensure commands like New-BurntToastNotification are recognized.
        Import-Module BurntToast -ErrorAction Stop
        SuccessMessage "Module 'BurntToast' imported successfully."
        return $true
    }
    catch {
        ErrorMessage "Failed to install or import module 'BurntToast'. Error details: $($_.Exception.Message)"
        return $false
    }
}

function Install-Chocolatey {
    try {
        InfoMessage "Chocolatey not found. Installing Chocolatey..."
        
        # Set execution policy for current process
        Set-ExecutionPolicy Bypass -Scope Process -Force
        
        # Download and install Chocolatey
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        
        # Refresh environment variables
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
        
        # Verify installation
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            SuccessMessage "Chocolatey installed successfully"
            return $true
        } else {
            ErrorMessage "Chocolatey installation verification failed"
            return $false
        }
    } catch {
        ErrorMessage "Failed to install Chocolatey: $($_.Exception.Message)"
        return $false
    }
}

function Install-GnuSed {
    # Define a test command to check if GNU sed is installed
    $TestCommand = "sed --version"

    try {
        # Check if GNU sed is already installed
        InfoMessage "[STEP 1/4] Checking if GNU sed is already installed..."
        $versionOutput = & cmd /c $TestCommand 2>&1
        if ($versionOutput -match "GNU sed") {
            InfoMessage "GNU sed is already installed. Version: $($versionOutput -split '\n' | Select-Object -First 1)" 
            return $true
        }
    } catch {
        InfoMessage "GNU sed is not installed. Proceeding with Chocolatey installation..." 
    }

    try {
        # Check if Chocolatey is available, install if needed
        InfoMessage "[STEP 2/4] Checking Chocolatey availability..."
        if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
            InfoMessage "Chocolatey not found. Installing Chocolatey first..."
            if (-not (Install-Chocolatey)) {
                ErrorMessage "Failed to install Chocolatey. Cannot proceed with GNU sed installation."
                return $false
            }
        } else {
            InfoMessage "Chocolatey is available"
        }
        
        # Install sed using Chocolatey (silent by default)
        InfoMessage "[STEP 3/4] Installing GNU sed via Chocolatey..."
        $chocoProcess = Start-Process -FilePath "choco" -ArgumentList "install", "sed", "-y" -Wait -PassThru -NoNewWindow -ErrorAction Stop
        
        if ($chocoProcess.ExitCode -eq 0) {
            InfoMessage "GNU sed installed successfully via Chocolatey"
        } else {
            ErrorMessage "Chocolatey sed installation failed with exit code: $($chocoProcess.ExitCode)"
            return $false
        }

        InfoMessage "[STEP 4/4] Verifying GNU sed installation..."
        # Refresh environment variables
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
        
        # Final verification
        try {
            $finalTest = & cmd /c "sed --version" 2>&1
            if ($finalTest -match "GNU sed") {
                SuccessMessage "GNU sed installation completed and verified successfully."
                return $true
            } else {
                ErrorMessage "GNU sed installation verification failed."
                return $false
            }
        } catch {
            ErrorMessage "GNU sed installation verification failed: $($_.Exception.Message)"
            return $false
        }
        
    } catch {
        # Catch and display any errors
        ErrorMessage "GNU sed installation failed: $($_.Exception.Message)" 
        return $false
    }
}

# Function to check if Visual C++ Redistributable is installed
function Install-VCppRedistributable {
    InfoMessage "[STEP 1/3] Checking Visual C++ Redistributable installation status..."
    
    $vcppKey = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
    if (Test-Path $vcppKey) {
        $vcppInstalled = Get-ItemProperty -Path $vcppKey
        if ($vcppInstalled -and $vcppInstalled.Installed -eq 1) {
            InfoMessage "Visual C++ Redistributable is already installed. Version: $($vcppInstalled.Version)" 
            return $true
        }
    }
    
    try {
        InfoMessage "[STEP 2/3] Downloading and installing Visual C++ Redistributable..."
        $vcRedistPath = "$env:TEMP\vc_redist.x64.exe"
        
        Invoke-WebRequest -Uri "https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x64.exe" -OutFile $vcRedistPath -ErrorAction Stop
        InfoMessage "Download completed. File size: $((Get-Item $vcRedistPath).Length) bytes"
        
        $installProcess = Start-Process -FilePath $vcRedistPath -ArgumentList "/quiet", "/install" -Wait -PassThru -ErrorAction Stop
        
        if ($installProcess.ExitCode -eq 0) {
            InfoMessage "Visual C++ Redistributable installer completed with exit code: $($installProcess.ExitCode)"
        } else {
            ErrorMessage "Visual C++ Redistributable installer failed with exit code: $($installProcess.ExitCode)"
            return $false
        }
        
        InfoMessage "[STEP 3/3] Verifying Visual C++ Redistributable installation..."
        # Re-check installation
        if (Test-Path $vcppKey) {
            $vcppInstalled = Get-ItemProperty -Path $vcppKey
            if ($vcppInstalled -and $vcppInstalled.Installed -eq 1) {
                SuccessMessage "Visual C++ Redistributable installation completed and verified successfully."
                return $true
            }
        }
        
        ErrorMessage "Visual C++ Redistributable installation verification failed."
        return $false
        
    } catch {
        ErrorMessage "Visual C++ Redistributable installation failed: $($_.Exception.Message)"
        return $false
    } finally {
        # Clean up installer file
        if (Test-Path "$env:TEMP\vc_redist.x64.exe") {
            Remove-Item -Path "$env:TEMP\vc_redist.x64.exe" -Force -ErrorAction SilentlyContinue
            InfoMessage "Installer file cleaned up: $env:TEMP\vc_redist.x64.exe"
        }
    }
}

# Main execution with proper error handling and exit codes
$overallSuccess = $true

InfoMessage "Starting dependency installation process..."
InfoMessage "=" * 60

# Install Visual C++ Redistributable
InfoMessage "Installing Visual C++ Redistributable..."
if (-not (Install-VCppRedistributable)) {
    ErrorMessage "Visual C++ Redistributable installation failed."
    $overallSuccess = $false
}

InfoMessage "=" * 60

# Install GNU sed
InfoMessage "Installing GNU sed..."
if (-not (Install-GnuSed)) {
    ErrorMessage "GNU sed installation failed."
    $overallSuccess = $false
}

InfoMessage "=" * 60

# Ensure other dependencies (curl, jq)
InfoMessage "Ensuring additional dependencies (curl, jq)..."
try {
    Ensure-Dependencies
    InfoMessage "Additional dependencies check completed."
} catch {
    ErrorMessage "Additional dependencies installation failed: $($_.Exception.Message)"
    $overallSuccess = $false
}

InfoMessage "=" * 60

# BurntToast module removed - not needed for silent server installation

InfoMessage "=" * 60

# Final status and exit
if ($overallSuccess) {
    SuccessMessage "All dependencies installed successfully!"
    InfoMessage "Dependencies installation completed. You may need to restart your terminal for PATH changes to take effect."
    exit 0
} else {
    ErrorMessage "One or more dependency installations failed. Please check the logs above for details."
    exit 1
}
