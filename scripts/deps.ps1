
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
        Invoke-WebRequest -Uri "https://curl.se/windows/dl-7.79.1_2/curl-7.79.1_2-win64-mingw.zip" -OutFile "$TEMP_DIR\curl.zip"
        Expand-Archive -Path "$TEMP_DIR\curl.zip" -DestinationPath "$TEMP_DIR\curl"
        Move-Item -Path "$TEMP_DIR\curl\curl-7.79.1_2-win64-mingw\bin\curl.exe" -Destination "C:\Program Files\curl.exe"
        Remove-Item -Path "$TEMP_DIR\curl.zip" -Recurse
        Remove-Item -Path "$TEMP_DIR\curl" -Recurse
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






function Install-GnuSed {
    <#
    .SYNOPSIS
        Downloads and installs GNU sed for Windows using portable version.
    
    .DESCRIPTION
        This function downloads the GNU sed portable binaries and installs them silently
        without requiring GUI interaction. Uses portable binaries for headless compatibility.
        This is an optional dependency - installation will continue if sed fails.
    
    .EXAMPLE
        Install-GnuSed
    #>
    
    InfoMessage "=== Installing GNU sed (Portable) - Optional Dependency ==="
    
    # Define URLs and paths for portable version with dependencies
    $BinUrl = "https://sourceforge.net/projects/gnuwin32/files/sed/4.2.1/sed-4.2.1-bin.zip/download"
    $DepUrl = "https://sourceforge.net/projects/gnuwin32/files/sed/4.2.1/sed-4.2.1-dep.zip/download"
    $BinPath = "$env:TEMP\sed-4.2.1-bin.zip"
    $DepPath = "$env:TEMP\sed-4.2.1-dep.zip"
    $InstallPath = "$env:ProgramFiles\GnuWin32"
    
    InfoMessage "[STEP 1/5] Checking if GNU sed is already installed..."
    
    # Check if sed is already available in PATH
    try {
        $sedVersion = & sed --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            InfoMessage "GNU sed is already installed and available in PATH"
            InfoMessage "Version info: $($sedVersion[0])"
            return $true
        }
    }
    catch {
        InfoMessage "GNU sed not found in PATH, proceeding with installation..."
    }
    
    try {
        # Download the portable binaries and dependencies using BITS
        InfoMessage "[STEP 2/5] Downloading GNU sed binaries and dependencies..."
        InfoMessage "Downloading binaries to $BinPath..."
        Start-BitsTransfer -Source $BinUrl -Destination $BinPath -ErrorAction Stop
        InfoMessage "Binaries download completed. File size: $((Get-Item $BinPath).Length) bytes"
        
        InfoMessage "Downloading dependencies to $DepPath..."
        Start-BitsTransfer -Source $DepUrl -Destination $DepPath -ErrorAction Stop
        InfoMessage "Dependencies download completed. File size: $((Get-Item $DepPath).Length) bytes"

        InfoMessage "[STEP 3/5] Extracting and installing binaries and dependencies..."
        
        # Create installation directory
        if (-not (Test-Path $InstallPath)) {
            New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
            InfoMessage "Created installation directory: $InstallPath"
        }
        
        # Extract both ZIP files
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            InfoMessage "Extracting binaries..."
            [System.IO.Compression.ZipFile]::ExtractToDirectory($BinPath, $InstallPath)
            InfoMessage "Extracting dependencies..."
            [System.IO.Compression.ZipFile]::ExtractToDirectory($DepPath, $InstallPath)
            InfoMessage "Binaries and dependencies extracted successfully to $InstallPath"
        }
        catch {
            # Fallback to PowerShell 5.0+ Expand-Archive
            InfoMessage "Using Expand-Archive fallback..."
            Expand-Archive -Path $BinPath -DestinationPath $InstallPath -Force
            Expand-Archive -Path $DepPath -DestinationPath $InstallPath -Force
            InfoMessage "Binaries and dependencies extracted successfully using Expand-Archive"
        }

        InfoMessage "[STEP 4/5] Configuring PATH and verifying installation..."
        
        # Add GNU sed to PATH
        $gnuSedBinPath = "$InstallPath\bin"
        if (Test-Path $gnuSedBinPath) {
            $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
            if ($currentPath -notlike "*$gnuSedBinPath*") {
                InfoMessage "Adding GNU sed to system PATH: $gnuSedBinPath"
                [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$gnuSedBinPath", "Machine")
                $env:PATH = "$env:PATH;$gnuSedBinPath"
            }
        } else {
            ErrorMessage "GNU sed bin directory not found at: $gnuSedBinPath"
            return $false
        }
        
        # Verify installation
        try {
            # First try with updated PATH in current session
            $sedExe = "$gnuSedBinPath\sed.exe"
            if (Test-Path $sedExe) {
                $sedVersion = & $sedExe --version 2>$null
                if ($LASTEXITCODE -eq 0) {
                    InfoMessage "GNU sed installation verified successfully"
                    InfoMessage "Version: $($sedVersion[0])"
                } else {
                    # Try with direct path if PATH verification fails
                    InfoMessage "GNU sed binaries installed successfully at: $gnuSedBinPath"
                    InfoMessage "Note: You may need to restart your terminal for PATH changes to take effect."
                }
            } else {
                ErrorMessage "GNU sed executable not found at: $sedExe"
                return $false
            }
        } catch {
            # If command fails, check if files exist
            if (Test-Path "$gnuSedBinPath\sed.exe") {
                InfoMessage "GNU sed binaries installed successfully at: $gnuSedBinPath"
                InfoMessage "Note: You may need to restart your terminal for PATH changes to take effect."
            } else {
                ErrorMessage "GNU sed installation verification failed: $_"
                return $false
            }
        }

        InfoMessage "[STEP 5/5] Cleaning up installer files..."
        
        # Clean up both ZIP files
        try {
            Remove-Item $BinPath -Force -ErrorAction Stop
            Remove-Item $DepPath -Force -ErrorAction Stop
            InfoMessage "Installer files cleaned up successfully"
        }
        catch {
            WarningMessage "Could not clean up installer files: $_"
        }
        
        InfoMessage "GNU sed portable installation completed successfully!"
        return $true
        
    }
    catch {
        WarningMessage "GNU sed installation failed: $_"
        WarningMessage "This is an optional dependency. Continuing with installation..."
        
        # Clean up on failure
        if (Test-Path $BinPath) {
            try {
                Remove-Item $BinPath -Force
                InfoMessage "Cleaned up failed binaries file"
            }
            catch {
                WarningMessage "Could not clean up failed binaries file: $_"
            }
        }
        if (Test-Path $DepPath) {
            try {
                Remove-Item $DepPath -Force
                InfoMessage "Cleaned up failed dependencies file"
            }
            catch {
                WarningMessage "Could not clean up failed dependencies file: $_"
            }
        }
        
        # Return true to continue installation since sed is optional
        InfoMessage "GNU sed installation skipped due to network/download issues"
        return $true
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
        
        Invoke-WebRequest -Uri "https://aka.ms/vs/16/release/vc_redist.x64.exe" -OutFile $vcRedistPath -ErrorAction Stop
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


# Install GNU sed (optional dependency)
InfoMessage "Installing GNU sed..."
if (-not (Install-GnuSed)) {
    WarningMessage "GNU sed installation failed, but this is optional. Continuing..."
    # Don't set $overallSuccess = $false since sed is optional
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


# Install BurntToast module
InfoMessage "Installing BurntToast PowerShell module..."
if (-not (Install-BurntToastModule)) {
    ErrorMessage "BurntToast module installation failed."
    $overallSuccess = $false
}


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


