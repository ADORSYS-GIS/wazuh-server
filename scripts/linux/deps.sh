#!/bin/sh

set -eu

WAZUH_SERVER_TAG=${WAZUH_SERVER_TAG:-'0.1.7'}
WAZUH_SERVER_REPO_REF=${WAZUH_SERVER_REPO_REF:-"refs/tags/v${WAZUH_SERVER_REPO_VERSION}"}
REPO_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-server/$WAZUH_SERVER_REPO_REF"

# Create a secure temporary directory for utilities
UTILS_TMP=$(mktemp -d)

# Download utils.sh from repository
trap 'rm -rf "$UTILS_TMP"' EXIT
if ! curl "$REPO_URL/scripts/shared/utils.sh" -o "$UTILS_TMP/utils.sh"; then
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
if ! curl "$REPO_URL/checksums.sha256" -o "$UTILS_TMP/checksums.sha256"; then
    echo "Failed to download checksums.sha256"
    exit 1
fi
CHECKSUMS_FILE="$UTILS_TMP/checksums.sha256"

EXPECTED_HASH=$(grep "scripts/shared/utils.sh" "$UTILS_TMP/checksums.sha256" | awk '{print $1}')
ACTUAL_HASH=$(calculate_sha256_bootstrap "$UTILS_TMP/utils.sh")

if [ -z "$EXPECTED_HASH" ] || [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
    echo "Error: Checksum verification failed for utils.sh" >&2
    echo "Expected hash: $EXPECTED_HASH" >&2
    echo "Actual hash: $ACTUAL_HASH" >&2
    exit 1
fi

# Source utils.sh only after verification
. "$UTILS_TMP/utils.sh"

LOGGED_IN_USER=""

if [ "$(uname -s)" = "Darwin" ]; then
    LOGGED_IN_USER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ {print $3}')
fi

#Get the logged-in user on macOS
brew_command() {
    sudo -u "$LOGGED_IN_USER" -i brew "$@"
}



# Detect OS and install packages
OS_NAME=$(uname -s)
case "$OS_NAME" in
    "Linux")
        if command_exists apt; then
            info_message "Detected Debian/Ubuntu-based system"
            maybe_sudo apt update
            maybe_sudo apt install -y curl jq
        elif command_exists yum; then
            info_message "Detected Red Hat/CentOS-based system"
            maybe_sudo yum install -y curl jq
        elif command_exists apk; then
            info_message "Detected Alpine Linux system"
            maybe_sudo apk add --no-cache curl jq
        else
            error_message "Unsupported Linux distribution"
            exit 1
        fi
        ;;
    "Darwin")
        info_message "Detected macOS"
        brew_command install jq gsed bash
        ;;
    *)
        error_message "Unsupported operating system: $OS_NAME"
        exit 1
        ;;
esac

success_message "Dependencies installed successfully!"