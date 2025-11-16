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

WAZUH_SERVER_TAG=${WAZUH_SERVER_TAG:-'0.1.7'}
WAZUH_YARA_VERSION=${WAZUH_YARA_VERSION:-'0.3.12'}
WAZUH_SURICATA_VERSION=${WAZUH_SURICATA_VERSION:-'0.1.5'}

# Uninstall choice variables
UNINSTALL_TRIVY="FALSE"
UNINSTALL_SURICATA="FALSE"
UNINSTALL_YARA="FALSE"

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
# CLI Parsing
# ==============================================================================
show_help() {
    echo "Usage: $0 [-s] [-t] [-y] [-h]"
    echo ""
    echo "Streamlined Wazuh uninstallation for Linux servers"
    echo ""
    echo "Options:"
    echo "  -s    Uninstall Suricata (optional)"
    echo "  -t    Uninstall Trivy (optional)"
    echo "  -y    Uninstall Yara (optional)"
    echo "  -h    Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  WAZUH_SERVER_TAG        Repository tag for server scripts (default: $WAZUH_SERVER_TAG)"
    echo "  WAZUH_YARA_VERSION      Yara version (default: $WAZUH_YARA_VERSION)"
}

while getopts ":sthy" opt; do
  case $opt in
    s) UNINSTALL_SURICATA="TRUE" ;;
    t) UNINSTALL_TRIVY="TRUE" ;;
    y) UNINSTALL_YARA="TRUE" ;;
    h) show_help; exit 0 ;;
    \?) echo "Invalid option: -$OPTARG" >&2; show_help; exit 1 ;;
  esac
done

# ==============================================================================
# Main Uninstallation Logic
# ==============================================================================

info_message "Starting uninstallation. Using temporary directory: \"$TMP_FOLDER\""
info_message "Options: UNINSTALL_SURICATA=$UNINSTALL_SURICATA UNINSTALL_TRIVY=$UNINSTALL_TRIVY UNINSTALL_YARA=$UNINSTALL_YARA"

# Step 0: Download all uninstall scripts
info_message "Downloading all uninstall scripts..."
curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/refs/tags/v$WAZUH_SERVER_TAG/scripts/uninstall.sh > "$TMP_FOLDER/uninstall-wazuh-server.sh"

if [ "$UNINSTALL_TRIVY" = "TRUE" ]; then
    curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/main/uninstall.sh > "$TMP_FOLDER/uninstall-trivy.sh"
fi
if [ "$UNINSTALL_SURICATA" = "TRUE" ]; then
    curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/refs/tags/v$WAZUH_SURICATA_VERSION/scripts/uninstall.sh > "$TMP_FOLDER/uninstall-suricata.sh"
fi
if [ "$UNINSTALL_YARA" = "TRUE" ]; then
    curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/refs/tags/v$WAZUH_YARA_VERSION/scripts/uninstall-server.sh > "$TMP_FOLDER/uninstall-yara-server.sh"
fi


# Step 1: Uninstall Wazuh agent
print_step 1 "Uninstalling Wazuh agent..."
if ! (maybe_sudo bash "$TMP_FOLDER/uninstall-wazuh-server.sh") 2>&1; then
    error_message "Failed to uninstall wazuh-server"
    exit 1
fi

# Step 2: Uninstall Trivy if the flag is set
if [ "$UNINSTALL_TRIVY" = "TRUE" ]; then
    print_step 2 "Uninstalling trivy..."
    if ! (bash "$TMP_FOLDER/uninstall-trivy.sh") 2>&1; then
        error_message "Failed to uninstall 'trivy'"
        exit 1
    fi
fi

# Step 3: Uninstall Suricata if the flag is set
if [ "$UNINSTALL_SURICATA" = "TRUE" ]; then
    if command_exists suricata; then
        print_step 3 "Uninstalling suricata..."
        if ! (maybe_sudo bash "$TMP_FOLDER/uninstall-suricata.sh") 2>&1; then
            error_message "Failed to uninstall 'suricata'"
            exit 1
        fi
    else
        info_message "Suricata not found on system. Skipping."
    fi
fi

# Step 4: Uninstall Yara if the flag is set
if [ "$UNINSTALL_YARA" = "TRUE" ]; then
    if command_exists yara; then
        print_step 4 "Uninstalling yara..."
        if ! (maybe_sudo bash "$TMP_FOLDER/uninstall-yara-server.sh") 2>&1; then
            error_message "Failed to uninstall 'yara'"
            exit 1
        fi
    else
        info_message "Yara not found on system. Skipping."
    fi
fi

success_message "Uninstallation completed successfully."
