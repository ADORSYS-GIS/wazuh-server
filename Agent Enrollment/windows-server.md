# Windows Server Enrollment Guide
 This guide walks you through the process of enrolling a Windows Server system with the Wazuh Manager. By following these steps, you will install and configure necessary components, ensuring secure communication between the Wazuh Agent and the Wazuh Manager.

 ### Prerequisites


- **Internet Connectivity:** Verify that the system is connected to the internet.
- **Adiminstrator Privileges:**  Ensure you open Powershell In Administrator Mode


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
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/feature/silent-windows-server-scripts/scripts/setup-server.ps1' `
  -UseBasicParsing -OutFile "$env:TEMP\setup-server.ps1"; `
& "$env:TEMP\setup-server.ps1" 
```

**NB:** You have other components that can be installed from this script, to know of them and how to install then run this command
```powershell
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/feature/silent-windows-server-scripts/scripts/setup-server.ps1' `
  -UseBasicParsing -OutFile "$env:TEMP\setup-server.ps1"; `
& "$env:TEMP\setup-server.ps1" -Help
```

### Step 2: Silent Installation Process

**Note:** This installation is now fully automated and silent - no GUI interactions are required!

The script will automatically install all dependencies including GNU sed, without any pop-ups or user interaction required. This is perfect for Windows Server environments.

**The Installation will continue automatically**
   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-07 13-36-39.png">


### Step 3: Suricata and Npcap Installation

**Note:** Suricata and Npcap installation is now fully automated!

The script will automatically install Suricata IDS and Npcap without any GUI interactions. The installation includes:
- Automated Npcap installation (no manual clicks required)
- Silent Suricata configuration
- Automatic service registration

   #### Installation will continue automatically:

   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-07 13-39-23.png">


###  Step 4: Please Restart Your Powershell terminal in Administrator mode.

This is a **very** important step, the installation will not work well if this step is not completed

### Step 5: Enrolling your agent with cert-oauth2
  #### 1. Generate the Enrollment URL
   Run the following command to start the enrollment process:

   ```powershell
   & 'C:\Program Files (x86)\ossec-agent\wazuh-cert-oauth2-client.exe' o-auth2
   ```
   This command will generate a URL. Copy the link and paste it into your web browser.


  #### 2. Authentication via browser

   - **i. Login:** You will be prompted to log in page,Log in using **Active  directories: `Adorsys GIS `or `adorsys GmbH & CO KG`**, which will  generate an authentication token using Keycloak.
  
   <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-28-14.png">

   - **ii. Two-Factor Authentication:** For first-time logins, authentication via an authenticator is required.
  
   <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-29-08.png">

   - **iii. Token generation:** After a successful authentication a token will be generated.
   
   <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-28-45.png">

  #### 3. Complete the Enrollment 
   Return to the command line and complete the enrollment process using the generated token.


  #### 4. Reboot your Device
   Reboot your device to apply the changes. 

### Step 6: Validate the Installation
   After completing the agent enrollment, verify that the agent is properly connected and functioning:

  #### 1. Check the Agent Status:
   Look for the Wazuh icon in the system tray to confirm that the agent is running and connected.

  
   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-07 14-44-53.png">


  #### 2. Verify Agent Logs:
   Check the Wazuh agent logs to ensure there are no errors:

   ```powershell
   Get-Content 'C:\Program Files (x86)\ossec-agent\ossec.log' -Tail 20
   ```
   Check the Wazuh agent logs to ensure there are no errors:


  #### 3. Check Agent service
   Run the following command:
   ```powershell
   Get-Service -Name "Wazuh"
   ``` 
  
   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-07 14-54-19.png">


  #### 4. Check the Wazuh Manager Dashboard:
   Ping an admin for confirmation that the agent appears in the Wazuh Manager dashboard.



  ## Checklist of Elements Installed and Configured During Agent Enrollment 
   ### i. Components Installed by the Script:

   **1. Wazuh Dependencies:**

   The dependencies installed for the wazuh-agent and other components include:
   - [Visual C++ Redistributable](https://www.microsoft.com/en-us/download/details.aspx?id=48145)
   - [GNU sed](https://www.gnu.org/software/sed/) 
   - [jq](https://jqlang.github.io/jq/)
   


   **2. Wazuh Agent:**
   Monitors your endpoint and sends data to the Wazuh Manager.
   The agent is installed and configured to connect to the specified manager (WAZUH_MANAGER).
   
   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-07 13-36-39.png">

   **3. OAuth2 Authentication Client:** Adds certificate-based OAuth2 authentication for secure communications.

   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-07 13-38-14.png">

   **4. Wazuh Agent Status:** Provides real-time health and connection status of the agent.

   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-07 13-38-39.png" >

   **5. Yara:** Enables advanced file-based malware detection by integrating Yara rules into Wazuh.

   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-07 13-39-01.png">

   **6. Suricata:**
   Adds network intrusion detection capabilities to monitor suspicious traffic.

   **Note:** Suricata installation is now fully automated with silent Npcap installation - no user interaction required!

   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-07 13-39-23.png">

   ### ii. Tools Installed:
   - YARA
   ```powershell
   yara64 -v
   ``` 
    
   - Suricata
   ```powershell
   suricata --version
   ```
   - Agent Status
   ```powershell
   Select-String -Path 'C:\Program Files (x86)\ossec-agent\wazuh-agent.state' -Pattern '^status'
   ```
   OR
   ```powershell
   Get-Service -Name "Wazuh"
   ```

  ### iii. Installation Validation:
   - Test registration successful
   - Logs reviewed for errors
   - Cleanup Completed


## Troubleshooting

- If the enrollment URL fails to generate, check internet connectivity and script permissions.

- For errors during authentication, ensure Active Directory credentials are correct and two-factor authentication is set up.

- Consult the Wazuh logs (C:\Program Files (x86)\ossec-agent\ossec.log) for detailed error messages.
   ``` powershell
   Get-Content 'C:\Program Files (x86)\ossec-agent\ossec.log' -Tail 20
   ```

## Uninstallation Guide

Should you need to uninstall the Wazuh agent, follow these steps:

### Step 1: Download and Run the Uninstall Script
   Download the uninstall script from the repository and run it to remove the Wazuh agent and its components.
   
```powershell
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/feature/silent-windows-server-scripts/scripts/uninstall-server.ps1' `
  -UseBasicParsing -OutFile "$env:TEMP\uninstall-server.ps1"; `
& "$env:TEMP\uninstall-server.ps1" -UninstallSuricata
```
  **NB:** Use the `-UninstallSuricata` option for **Suricata**. The uninstall script will remove all Suricata components and Npcap.

- Reboot the user's machine



### Additional Resources
- [Wazuh Documentation](https://documentation.wazuh.com/current/user-manual/agent/index.html#wazuh-agent)
