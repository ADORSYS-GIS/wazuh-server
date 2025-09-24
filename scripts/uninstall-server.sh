#!/bin/sh

# Check if we're running in bash; if not, adjust behavior
if [ -n "$BASH_VERSION" ]; then
    set -euo pipefail
else
    set -eu
fi

# ==============================================================================
# Default Configuration
# ==============================================================================
LOG_LEVEL=${LOG_LEVEL:-"INFO"}

WAZUH_SERVER_TAG=${WAZUH_SERVER_TAG:-'0.1.1'}

# Uninstall choice variables
UNINSTALL_TRIVY="FALSE"

TMP_FOLDER="$(mktemp -d)"

# Define text formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NORMAL='\033[0m'

# ==============================================================================
# Helper Functions
# ==============================================================================

# Function for logging with timestamp
log() {
    LEVEL="$1"
    shift
    local MESSAGE="$*"
    local TIMESTAMP
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${TIMESTAMP} ${LEVEL} ${MESSAGE}"
}

info_message() { log "${BLUE}${BOLD}[===========> INFO]${NORMAL}" "$*"; }
error_message() { log "${RED}${BOLD}[ERROR]${NORMAL}" "$*"; }
success_message() { log "${GREEN}${BOLD}[SUCCESS]${NORMAL}" "$*"; }
print_step() { log "${BLUE}${BOLD}[STEP]${NORMAL}" "$1: $2"; }

# Check if cert-oauth2 client is installed
check_cert_oauth2_installed() {
    # Check for cert-oauth2 binary in common locations
    if [ -f "/var/ossec/bin/wazuh-cert-oauth2-client" ]; then
        return 0
    fi
    
    # Check for cert-oauth2 binary in user's PATH
    if command -v wazuh-cert-oauth2-client >/dev/null 2>&1; then
        return 0
    fi
    
    # Check for cert-oauth2 binary in /usr/local/bin
    if [ -f "/usr/local/bin/wazuh-cert-oauth2-client" ]; then
        return 0
    fi
    
    return 1
}

# Function to uninstall cert-oauth2 client
uninstall_cert_oauth2() {
    info_message "Checking for cert-oauth2 client..."
    
    if ! check_cert_oauth2_installed; then
        info_message "cert-oauth2 client not found. Skipping cert-oauth2 uninstallation."
        return 0
    fi
    
    info_message "cert-oauth2 client detected. Proceeding with uninstallation..."
    
    # Remove cert-oauth2 binary from common locations
    if [ -f "/var/ossec/bin/wazuh-cert-oauth2-client" ]; then
        info_message "Removing cert-oauth2 client from /var/ossec/bin/"
        maybe_sudo rm -f "/var/ossec/bin/wazuh-cert-oauth2-client"
    fi
    
    if [ -f "/usr/local/bin/wazuh-cert-oauth2-client" ]; then
        info_message "Removing cert-oauth2 client from /usr/local/bin/"
        maybe_sudo rm -f "/usr/local/bin/wazuh-cert-oauth2-client"
    fi
    
    # Remove cert-oauth2 configuration files if they exist
    if [ -f "/var/ossec/etc/wazuh-cert-oauth2.conf" ]; then
        info_message "Removing cert-oauth2 configuration file"
        maybe_sudo rm -f "/var/ossec/etc/wazuh-cert-oauth2.conf"
    fi
    
    success_message "cert-oauth2 client uninstalled successfully."
    return 0
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure root privileges, either directly or through sudo
maybe_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        if command_exists sudo; then
            sudo "$@"
        else
            error_message "This script requires root privileges. Please run with sudo or as root."
            exit 1
        fi
    else
        "$@"
    fi
}

cleanup() {
    # Remove temporary folder
    if [ -d "$TMP_FOLDER" ]; then
        rm -rf "$TMP_FOLDER"
    fi
}
trap cleanup EXIT

# ==============================================================================
# Main Uninstallation Logic
# ==============================================================================

info_message "Starting uninstallation. Using temporary directory: \"$TMP_FOLDER\""

# Step 0: Download all uninstall scripts
info_message "Downloading all uninstall scripts..."
curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/refs/tags/v$WAZUH_SERVER_TAG/scripts/uninstall.sh > "$TMP_FOLDER/uninstall-wazuh-server.sh"

if [ "$UNINSTALL_TRIVY" = "TRUE" ]; then
    curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/main/uninstall.sh > "$TMP_FOLDER/uninstall-trivy.sh"
fi

# Step 1: Uninstall cert-oauth2 client if present
print_step 1 "Checking and uninstalling cert-oauth2 client..."
if ! uninstall_cert_oauth2; then
    error_message "Failed to uninstall cert-oauth2 client"
    exit 1
fi

# Step 2: Uninstall Wazuh agent
print_step 2 "Uninstalling Wazuh agent..."
if ! (maybe_sudo bash "$TMP_FOLDER/uninstall-wazuh-server.sh") 2>&1; then
    error_message "Failed to uninstall wazuh-server"
    exit 1
fi

# Step 3: Uninstall Trivy if the flag is set
if [ "$UNINSTALL_TRIVY" = "TRUE" ]; then
    print_step 3 "Uninstalling trivy..."
    if ! (bash "$TMP_FOLDER/uninstall-trivy.sh") 2>&1; then
        error_message "Failed to uninstall 'trivy'"
        exit 1
    fi
fi

success_message "Uninstallation completed successfully."
