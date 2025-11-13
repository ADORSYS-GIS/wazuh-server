# Wazuh Server Endpoint Setup

[![Release Client](https://github.com/ADORSYS-GIS/wazuh-server/actions/workflows/release.yaml/badge.svg?branch=main)](https://github.com/ADORSYS-GIS/wazuh-server/actions/workflows/release.yaml)



## Key Features

- **Automated Installation:** Quick setup of Wazuh agent for servers and dependencies.

- **Cross-Platform Support:** Compatible with Ubuntu, macOS, and Windows.

- **Security Tools Integration:** Pre-configured with Yara for enhanced threat detection.

## Supported Operating Systems


- **Ubuntu Server**
- **Debian**
- **Centos**
- **RHEL** 
- **Windows Server**

## Installation

### Wazuh Agent for Server Enrollment Guide

This guide provides instructions to enroll Wazuh agents for servers on various platforms, integrating them with the Wazuh Manager for enhanced monitoring and security. Additionally, it automates the installation of tools like Yara to augment security capabilities.

### Introduction

Wazuh agents for servers collect and transmit security data from endpoints to the Wazuh Manager for analysis. Proper enrollment ensures seamless integration and secure communication. Refer to the respective guide:

- [Linux Agent for Server Enrollment Guide](/Agent%20Enrollment/linux-server.md)
- [MacOS Agent for Server Enrollment Guide](/Agent%20Enrollment/macos-server.md)
- [Windows Agent for Server Enrollment Guide](/Agent%20Enrollment/windows-server.md)

## Additional Notes

### Scripts Overview

This repository includes several scripts for configuring and deploying Wazuh and additional security components:

- **deps.sh:** Installs dependencies required for the Wazuh Agent for servers and Yara on Linux/macOS, ensuring all necessary packages and configurations are in place for a smooth installation.

- **deps.ps1:** Installs required dependencies on Windows, ensuring that Yara and the Wazuh Agent for servers have all prerequisites met for a seamless setup.

- **install.sh:** Sets up the core Wazuh Agent for servers on Linux/macOS, including necessary configuration files and establishing integration with the Wazuh management server.

- **setup-server.sh:** Combines both dependency installation and agent for servers setup into a single streamlined process, allowing you to set up everything with one command on Linux/macOS.

- **setup-server.ps1:** Installs the Wazuh Agent for servers and optional components on Windows. It configures the agent to communicate with the Wazuh Manager and integrates essential logging and alerting functions.

- **install.ps1:** Manages the entire Wazuh Agent for servers installation process on Windows, including error-handling and logging. This script checks dependencies and manages the full setup process, from configuration to package management.

### Wazuh Integration with Additional Tools

- **Yara:** Scans files for malware signatures, forwarding results to the Wazuh Manager for correlation and alerting.


### Troubleshooting

Ensure the necessary environment variables (e.g., WAZUH_MANAGER) are set correctly before running the scripts to avoid installation issues or misconfigurations. Proper configurations will help ensure reliable and secure operation across different environments.
