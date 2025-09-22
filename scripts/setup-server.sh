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

# Step 3: Download version file
info_message "Downloading version file..."
if ! (maybe_sudo curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/refs/tags/v$WAZUH_SERVER_TAG/version.txt" -o "$OSSEC_PATH/version.txt") 2>&1; then
    error_message "Failed to download version file"
    exit 1
fi
info_message "Version file downloaded successfully."

success_message "Wazuh setup has been completed successfully."