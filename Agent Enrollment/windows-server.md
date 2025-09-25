# Windows Server Enrollment Guide (Agent + cert-oauth2 only)

This guide installs the Wazuh Agent (with minimal dependencies) and enrolls it using cert-oauth2. It is designed for Windows Server endpoints and runs fully unattended except for the browser authentication during enrollment.

### Prerequisites

- **Internet connectivity**
- **Run PowerShell as Administrator**

## Step-by-step

### Step 0: Allow script execution 
```
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```
When prompted, choose A (Yes to All).

### Step 1: Install the Wazuh Agent 
Set your manager hostname, download the setup script, and run it. This installs only the core dependencies and the Wazuh Agent.

```powershell
$env:WAZUH_MANAGER = "manager.wazuh.adorsys.team"
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/refs/tags/v0.1.2-rc1/scripts/setup-server.ps1' `
  -UseBasicParsing -OutFile "$env:TEMP\setup-server.ps1"; `
PowerShell -ExecutionPolicy Bypass -File "$env:TEMP\setup-server.ps1"
```

- Optional: If you want to install the cert-oauth2 client during setup, add the flag:
```powershell
PowerShell -ExecutionPolicy Bypass -File "$env:TEMP\setup-server.ps1" -InstallCertOAuth2
```

### Step 2: Enroll your agent with cert-oauth2
1) Generate the enrollment URL:
```powershell
& 'C:\Program Files (x86)\ossec-agent\wazuh-cert-oauth2-client.exe' o-auth2
```
Copy the URL printed by the command and open it in your browser.

2) Authenticate in the browser:
- Login using Active Directories: `Adorsys GIS` or `adorsys GmbH & CO KG` (Keycloak based)

![Login](./images/linux/Screenshot%20from%202024-12-20%2008-28-14.png)

- Complete two‑factor authentication if prompted

![Two-Factor Authentication](./images/linux/Screenshot%20from%202024-12-20%2008-29-08.png)

- A token will be generated upon success

![Token generation](./images/linux/Screenshot%20from%202024-12-20%2008-28-45.png)

3) Complete the enrollment:
Return to PowerShell and follow the client prompts to paste/confirm the token and finish.

- Optional: Reboot the server after enrollment if requested by IT policy.

## Validate the installation
- Check service status:
```powershell
Get-Service -Name "WazuhSvc"
```

- Tail recent agent logs:
```powershell
Get-Content 'C:\Program Files (x86)\ossec-agent\ossec.log' -Tail 20
```

- Confirm manager configuration exists:
```powershell
Select-String -Path 'C:\Program Files (x86)\ossec-agent\ossec.conf' -Pattern '<server>'
```

## Uninstallation (when needed)
Run elevated PowerShell and execute the uninstall wrapper. This delegates to the inner uninstall and removes the agent cleanly.
```powershell
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/refs/tags/v0.1.2-rc1/scripts/uninstall-server.ps1' `
  -UseBasicParsing -OutFile "$env:TEMP\uninstall-server.ps1"; `
PowerShell -ExecutionPolicy Bypass -File "$env:TEMP\uninstall-server.ps1"
```

### Notes
- The setup installs only: curl, jq, and the Wazuh Agent
- cert-oauth2 client is optional; enrollment requires a browser login to obtain a token 
