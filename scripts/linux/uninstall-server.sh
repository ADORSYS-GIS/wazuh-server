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
OSSEC_CONF_PATH="/var/ossec/etc/ossec.conf"
WAZUH_MANAGER=${WAZUH_MANAGER:-'wazuh.example.com'}
WAZUH_AGENT_VERSION=${WAZUH_AGENT_VERSION:-'4.14.2-1'}
WAZUH_SERVER_TAG=${WAZUH_SERVER_TAG:-'0.1.7'}
WOPS_VERSION=${WOPS_VERSION:-'0.3.0'}
APP_NAME=${APP_NAME:-'wazuh-cert-oauth2-client'}
WAZUH_SURICATA_VERSION=${WAZUH_SURICATA_VERSION:-'0.1.5'}
WAZUH_YARA_VERSION=${WAZUH_YARA_VERSION:-'0.3.14'}

# Repository references (can be overridden for testing)
WAZUH_SERVER_REPO_REF=${WAZUH_SERVER_REPO_REF:-"refs/tags/v${WAZUH_SERVER_REPO_VERSION}"}
WAZUH_SURICATA_REPO_REF=${WAZUH_SURICATA_REPO_REF:-"refs/tags/v${WAZUH_SURICATA_REPO_VERSION}"}
WAZUH_TRIVY_REPO_REF=${WAZUH_TRIVY_REPO_REF:-"refs/tags/v${WAZUH_TRIVY_REPO_VERSION}"}
WAZUH_YARA_REPO_REF=${WAZUH_YARA_REPO_REF:-"refs/tags/v${WAZUH_YARA_REPO_VERSION}"}
WAZUH_CERT_OAUTH2_REPO_REF=${WAZUH_CERT_OAUTH2_REPO_REF:-"refs/tags/v${WAZUH_CERT_OAUTH2_REPO_VERSION}"}

# Repository URLs
WAZUH_SERVER_REPO_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/$WAZUH_SERVER_REPO_REF"
WAZUH_SURICATA_REPO_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/$WAZUH_SURICATA_REPO_REF"
WAZUH_TRIVY_REPO_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/$WAZUH_TRIVY_REPO_REF"
WAZUH_YARA_REPO_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/$WAZUH_YARA_REPO_REF"
WAZUH_CERT_OAUTH2_REPO_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-cert-oauth2/$WAZUH_CERT_OAUTH2_REPO_REF"

# Installation choice variables
INSTALL_TRIVY="FALSE"
INSTALL_CERT_OAUTH2="FALSE"
INSTALL_SURICATA="FALSE"
INSTALL_YARA="FALSE"

# Create a secure temporary directory for utilities
TMP_FOLDER=$(mktemp -d)

# Download utils.sh from repository
trap 'rm -rf "$TMP_FOLDER"' EXIT
if ! curl "$WAZUH_SERVER_REPO_URL/scripts/shared/utils.sh" -o "$TMP_FOLDER/utils.sh"; then
    echo "Failed to download utils.sh"
    exit 1
fi

# Function to calculate SHA256 (cross-platform bootstrap)
calculate_sha256_bootstrap() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# Download checksums and verify utils.sh integrity BEFORE sourcing it
if ! curl "$WAZUH_SERVER_REPO_URL/checksums.sha256" -o "$TMP_FOLDER/checksums.sha256"; then
    echo "Failed to download checksums.sha256"
    exit 1
fi
CHECKSUMS_FILE="$TMP_FOLDER/checksums.sha256"

EXPECTED_HASH=$(grep "scripts/shared/utils.sh" "$TMP_FOLDER/checksums.sha256" | awk '{print $1}')
ACTUAL_HASH=$(calculate_sha256_bootstrap "$TMP_FOLDER/utils.sh")

if [ -z "$EXPECTED_HASH" ] || [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
    echo "Error: Checksum verification failed for utils.sh" >&2
    echo "Expected hash: $EXPECTED_HASH" >&2
    echo "Actual hash: $ACTUAL_HASH" >&2
    exit 1
fi

# Source utils.sh only after verification
. "$TMP_FOLDER/utils.sh"

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
    echo "  WAZUH_SERVER_TAG           Repository tag for server scripts (default: $WAZUH_SERVER_TAG)"
    echo "  WAZUH_SERVER_REPO_REF      Full repository reference (default: refs/tags/v\${WAZUH_SERVER_TAG})"
    echo "  WAZUH_SURICATA_VERSION     Suricata version (default: $WAZUH_SURICATA_VERSION)"
    echo "  WAZUH_SURICATA_REPO_REF    Suricata repository reference (default: refs/tags/v\${WAZUH_SURICATA_VERSION})"
    echo "  WAZUH_YARA_VERSION         Yara version (default: $WAZUH_YARA_VERSION)"
    echo "  WAZUH_YARA_REPO_REF        Yara repository reference (default: refs/tags/v\${WAZUH_YARA_VERSION})"
    echo "  WAZUH_TRIVY_REPO_REF       Trivy repository reference (default: main)"
    echo "  WOPS_VERSION                cert-oauth2 client version (default: $WOPS_VERSION)"
    echo "  WAZUH_CERT_OAUTH2_REPO_REF  cert-oauth2 repository reference (default: refs/tags/v\${WOPS_VERSION})"
    echo ""
    echo "  Note: You can pass either tags (e.g., '0.1.7') or full repo refs"
    echo "        (e.g., 'refs/tags/v0.1.7' or 'refs/heads/main')"
    echo ""
    echo "Examples:"
    echo "  $0                       # Uninstall Wazuh agent only"
    echo "  $0 -s                    # Uninstall Wazuh agent + Suricata"
    echo "  $0 -t                    # Uninstall Wazuh agent + Trivy"
    echo "  $0 -y                    # Uninstall Wazuh agent + Yara"
    echo "  $0 -s -t -y              # Uninstall all components"
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

STEP_NUMBER=0

# Step 0: Download all uninstall scripts
info_message "Downloading all uninstall scripts..."

print_step ((++STEP_NUMBER)) "Uninstalling Wazuh agent..."
download_and_verify_file "$WAZUH_SERVER_REPO_URL/scripts/linux/uninstall-agent.sh" "$TMP_FOLDER/uninstall-agent.sh" "scripts/linux/uninstall-agent.sh" "Wazuh agent uninstall script" "$WAZUH_SERVER_REPO_URL/checksums.sha256"
if ! (maybe_sudo bash "$TMP_FOLDER/uninstall-wazuh-server.sh") 2>&1; then
    error_message "Failed to uninstall wazuh-server"
    exit 1
fi

linux_uninstall_pattern="scripts/linux/uninstall.sh"
for component in "trivy" "cert-oauth2" "suricata" "yara"; do
    INSTALL_VAR="INSTALL_$(echo "$component" | tr '[:lower:]' '[:upper:]')"

    print_step ((++STEP_NUMBER)) "Processing $component uninstallation..."

    if [ "${!INSTALL_VAR}" = "TRUE" ]; then
        case "$component" in
            "trivy")
                download_and_verify_file "$WAZUH_TRIVY_REPO_URL/$linux_uninstall_pattern" "$TMP_FOLDER/uninstall-trivy.sh" "$linux_uninstall_pattern" "trivy uninstall script" "$WAZUH_TRIVY_REPO_URL/checksums.sha256"
                if ! (maybe_sudo env bash "$TMP_FOLDER/uninstall-trivy.sh") 2>&1; then
                    error_exit "Failed to uninstall trivy"
                fi
                ;;
            "cert-oauth2")
                download_and_verify_file "$WAZUH_CERT_OAUTH2_REPO_URL/$linux_uninstall_pattern" "$TMP_FOLDER/uninstall-cert-oauth2.sh" "$linux_uninstall_pattern" "cert-oauth2 uninstall script" "$WAZUH_CERT_OAUTH2_REPO_URL/checksums.sha256"
                if ! (maybe_sudo env OSSEC_CONF_PATH="$OSSEC_CONF_PATH" bash "$TMP_FOLDER/uninstall-cert-oauth2.sh") 2>&1; then
                    error_exit "Failed to uninstall cert-oauth2"
                fi
                ;;
            "suricata")
                download_and_verify_file "$WAZUH_SURICATA_REPO_URL/$linux_uninstall_pattern" "$TMP_FOLDER/uninstall-suricata.sh" "$linux_uninstall_pattern" "suricata uninstall script" "$WAZUH_SURICATA_REPO_URL/checksums.sha256"
                if ! (maybe_sudo env bash "$TMP_FOLDER/uninstall-suricata.sh" --mode ids) 2>&1; then
                    error_exit "Failed to uninstall Suricata"
                fi
                ;;
            "yara")
                download_and_verify_file "$WAZUH_YARA_REPO_URL/$linux_uninstall_pattern" "$TMP_FOLDER/uninstall-yara-server.sh" "$linux_uninstall_pattern" "yara uninstall script" "$WAZUH_YARA_REPO_URL/checksums.sha256"
                if ! (maybe_sudo env bash "$TMP_FOLDER/uninstall-yara-server.sh") 2>&1; then
                    error_exit "Failed to uninstall Yara"
                fi
                 ;;
        esac
    fi
done

success_message "Uninstallation completed successfully."
