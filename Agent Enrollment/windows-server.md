# Windows Server Enrollment Guide

This guide walks you through the streamlined process of installing the Wazuh Agent on Windows Server systems. The installation focuses on core components only - Wazuh Agent with essential dependencies - providing a clean, silent installation perfect for headless/SSH environments.

### Prerequisites

- **Internet Connectivity:** Verify that the system is connected to the internet.
- **Adiminstrator Privileges:** Ensure you open Powershell In Administrator Mode

## Step by step process

### Step 0: Set Execution Policy

Set Execution Policy to Remote Signed to allow powershell scripts to run.

```
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

When prompted, respond with A [Yes to All], to enable the execution policy.

### Step 1: Download and Run the Setup Script

Download the setup script from the repository and run it to configure the Wazuh agent with the necessary parameters for secure communication with the Wazuh Manager.

```powershell
$env:WAZUH_MANAGER = "manager.wazuh.adorsys.team"
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/refs/tags/v0.1.2-rc1/scripts/setup-server.ps1' `
  -UseBasicParsing -OutFile "$env:TEMP\setup-server.ps1"; `
PowerShell -ExecutionPolicy Bypass -File "$env:TEMP\setup-server.ps1"
```

### Step 2: Streamlined Installation Process

**Note:** This installation is fully automated and silent - no GUI interactions required!

The streamlined script will automatically install:

- **Core dependencies:** curl and jq only
- **Wazuh Agent:** Latest version with silent installation
- **Configuration:** Automatic manager connection setup
- **Service management:** Automatic service start and verification

**The installation completes automatically without additional components like OAuth2, Suricata, or YARA.**

### Step 3: Validate the Installation

After the streamlined installation completes, verify that the agent is properly installed and functioning:

#### 1. Check the Agent Service:

Verify the Wazuh service is running:

```powershell
Get-Service -Name "WazuhSvc"
```

#### 2. Verify Agent Logs:

Check the Wazuh agent logs to ensure there are no errors:

```powershell
Get-Content 'C:\Program Files (x86)\ossec-agent\ossec.log' -Tail 20
```

Check the Wazuh agent logs to ensure there are no errors:

#### 3. Check Agent Configuration:

Verify the manager connection is configured:

```powershell
Select-String -Path 'C:\Program Files (x86)\ossec-agent\ossec.conf' -Pattern '<server>'
```

#### 4. Check the Wazuh Manager Dashboard:

Ping an admin for confirmation that the agent appears in the Wazuh Manager dashboard.

## Components Installed by the Streamlined Script

### Core Dependencies:

- **curl:** For downloading files and making HTTP requests
- **jq:** For JSON processing and configuration management

### Wazuh Agent:

- **Wazuh Agent:** Monitors your endpoint and sends data to the Wazuh Manager
- **Configuration:** Automatically configured to connect to the specified manager (WAZUH_MANAGER)
- **Service:** Installed and started as a Windows service (WazuhSvc)
- **Active Response:** Configured for log monitoring and response capabilities

### Validation Commands:

```powershell
# Check service status
Get-Service -Name "WazuhSvc"

# Verify agent logs
Get-Content 'C:\Program Files (x86)\ossec-agent\ossec.log' -Tail 10

# Check configuration
Select-String -Path 'C:\Program Files (x86)\ossec-agent\ossec.conf' -Pattern '<server>'
```

### iii. Installation Validation:

- Test registration successful
- Logs reviewed for errors
- Cleanup Completed

## Troubleshooting

- If the enrollment URL fails to generate, check internet connectivity and script permissions.

- For errors during authentication, ensure Active Directory credentials are correct and two-factor authentication is set up.

- Consult the Wazuh logs (C:\Program Files (x86)\ossec-agent\ossec.log) for detailed error messages.
  ```powershell
  Get-Content 'C:\Program Files (x86)\ossec-agent\ossec.log' -Tail 20
  ```

## Uninstallation Guide

Should you need to uninstall the Wazuh agent, follow these steps:

### Step 1: Download and Run the Uninstall Script

Download the uninstall script from the repository and run it to remove the Wazuh agent and its components.

```powershell
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/refs/tags/v0.1.2-rc1/scripts/uninstall-server.ps1' `
  -UseBasicParsing -OutFile "$env:TEMP\uninstall-server.ps1"; `
PowerShell -ExecutionPolicy Bypass -File "$env:TEMP\uninstall-server.ps1"
```

**Note:** The streamlined uninstall script automatically detects if Wazuh Agent is installed and removes only the core components. No additional parameters needed.

### Additional Resources

- [Wazuh Documentation](https://documentation.wazuh.com/current/user-manual/agent/index.html#wazuh-agent)
