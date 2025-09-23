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

if [ "$(uname)" = "Darwin" ]; then
    OSSEC_PATH="/Library/Ossec/etc"
else
    OSSEC_PATH="/var/ossec/etc"
fi
OSSEC_CONF_PATH="$OSSEC_PATH/ossec.conf"

WAZUH_MANAGER=${WAZUH_MANAGER:-'wazuh.example.com'}
WAZUH_AGENT_VERSION=${WAZUH_AGENT_VERSION:-'4.12.0-1'}
WAZUH_SERVER_TAG=${WAZUH_SERVER_TAG:-'0.1.1'}

# Installation choice variables
INSTALL_TRIVY="FALSE"
INSTALL_CERT_OAUTH2="FALSE"

# Parse command line options
while getopts ":hc" opt; do
  case $opt in
    c) INSTALL_CERT_OAUTH2="TRUE"
    ;;
    h) echo "Usage: $0 [-c] [-h]"
       echo ""
       echo "Streamlined Wazuh Agent installation for Linux servers"
       echo ""
       echo "Options:"
       echo "  -c    Install cert-oauth2 client (optional)"
       echo "  -h    Show this help message"
       echo ""
       echo "Environment Variables:"
       echo "  WAZUH_MANAGER         Wazuh manager hostname (default: wazuh.example.com)"
       echo "  WAZUH_AGENT_VERSION   Wazuh agent version (default: 4.12.0-1)"
       echo "  WAZUH_SERVER_TAG      Repository tag (default: 0.1.1)"
       echo "  LOG_LEVEL            Logging level (default: INFO)"
       echo ""
       echo "Examples:"
       echo "  $0                    # Core installation only"
       echo "  $0 -c                 # With cert-oauth2"
       echo "  WAZUH_MANAGER='my-wazuh.com' $0 -c"
       echo ""
       exit 0
    ;;
    \?) echo "Invalid option: -$OPTARG" >&2
        echo "Use -h for help"
        exit 1
    ;;
  esac
done

# Check for extra arguments
shift $((OPTIND - 1))
if [ $# -gt 0 ]; then
  echo "Error: Extra arguments provided: $*"
  echo "Use -h for help"
  exit 1
fi

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
    local LEVEL="$1"
    shift
    local MESSAGE="$*"
    local TIMESTAMP
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${TIMESTAMP} ${LEVEL} ${MESSAGE}"
}

info_message() { log "${BLUE}${BOLD}[===========> INFO]${NORMAL}" "$*"; }
error_message() { log "${RED}${BOLD}[ERROR]${NORMAL}" "$*"; }
success_message() { log "${GREEN}${BOLD}[SUCCESS]${NORMAL}" "$*"; }

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
# Main Installation Logic
# ==============================================================================

info_message "Starting setup. Using temporary directory: \"$TMP_FOLDER\""
info_message "Options: INSTALL_CERT_OAUTH2=$INSTALL_CERT_OAUTH2"

# Step -1: Download all core scripts
info_message "Downloading core component scripts..."
curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/refs/tags/v$WAZUH_SERVER_TAG/scripts/deps.sh" > "$TMP_FOLDER/install-deps.sh"
curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/refs/tags/v$WAZUH_SERVER_TAG/scripts/install.sh" > "$TMP_FOLDER/install-wazuh-server.sh"

# Step 0: Install dependencies
info_message "Installing dependencies"
if ! (bash "$TMP_FOLDER/install-deps.sh") 2>&1; then
    error_message "Failed to install dependencies"
    exit 1
fi

# Step 1: Download and install Wazuh agent
info_message "Installing Wazuh agent"
if ! (maybe_sudo env LOG_LEVEL="$LOG_LEVEL" OSSEC_CONF_PATH=$OSSEC_CONF_PATH WAZUH_MANAGER="$WAZUH_MANAGER" WAZUH_AGENT_VERSION="$WAZUH_AGENT_VERSION" bash "$TMP_FOLDER/install-wazuh-server.sh") 2>&1; then
    error_message "Failed to install wazuh-server"
    exit 1
fi

# Step 2: Install Trivy if the flag is set
if [ "$INSTALL_TRIVY" = "TRUE" ]; then
    info_message "Installing Trivy..."
    curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/main/install.sh" > "$TMP_FOLDER/install-trivy.sh"
    if ! (bash "$TMP_FOLDER/install-trivy.sh") 2>&1; then
        error_message "Failed to install trivy"
        exit 1
    fi
fi

# Step 3: Install cert-oauth2 if the flag is set
if [ "$INSTALL_CERT_OAUTH2" = "TRUE" ]; then
    info_message "Installing cert-oauth2..."
    
    # Check if Wazuh Agent is installed first
    if ! maybe_sudo [ -d "$OSSEC_PATH" ]; then
        error_message "Wazuh Agent not found at $OSSEC_PATH"
        error_message "Please install Wazuh Agent first before installing cert-oauth2"
        exit 1
    fi
    
    # Variables for cert-oauth2
    WOPS_VERSION=${WOPS_VERSION:-"0.2.18"}
    APP_NAME=${APP_NAME:-"wazuh-cert-oauth2-client"}
    
    info_message "Downloading cert-oauth2 installation script..."
    info_message "Version: $WOPS_VERSION"
    
    OAUTH2_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-cert-oauth2/refs/tags/v$WOPS_VERSION/scripts/install.sh"
    OAUTH2_SCRIPT="$TMP_FOLDER/cert-oauth2-install.sh"
    
    if ! curl -SL -s "$OAUTH2_URL" -o "$OAUTH2_SCRIPT"; then
        error_message "Failed to download cert-oauth2 installation script"
        exit 1
    fi
    
    info_message "cert-oauth2 installation script downloaded successfully"
    info_message "Installing cert-oauth2 client..."
    
    # Make script executable and run it
    chmod +x "$OAUTH2_SCRIPT"
    
    # Export variables for the cert-oauth2 script
    export LOG_LEVEL
    export APP_NAME
    export WOPS_VERSION
    
    if ! "$OAUTH2_SCRIPT"; then
        error_message "cert-oauth2 installation failed"
        exit 1
    fi
    
    info_message "cert-oauth2 client installed successfully!"
    
    # Determine the correct path based on OS
    if [ "$(uname)" = "Darwin" ]; then
        OAUTH2_CLIENT_PATH="/Library/Ossec/bin/wazuh-cert-oauth2-client"
    else
        OAUTH2_CLIENT_PATH="/var/ossec/bin/wazuh-cert-oauth2-client"
    fi
    
    info_message "You can now use: sudo $OAUTH2_CLIENT_PATH o-auth2"
fi

# Step 4: Download version file
info_message "Downloading version file..."
if ! (maybe_sudo curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/refs/tags/v$WAZUH_SERVER_TAG/version.txt" -o "$OSSEC_PATH/version.txt") 2>&1; then
    error_message "Failed to download version file"
    exit 1
fi
info_message "Version file downloaded successfully."

success_message "Wazuh setup has been completed successfully."