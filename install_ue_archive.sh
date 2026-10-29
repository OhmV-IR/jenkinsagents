#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# CONFIGURATION
# ==========================================
# Pass the version as an argument or environment variable (e.g., 5.5.4)
UE_VERSION="${1:-${UE_VERSION:-}}"
# Path to the local pre-downloaded zip file or directory containing it
ARCHIVE_PATH="${2:-${ARCHIVE_PATH:-}}"

TARGET_DIR="/opt/unrealengine/${UE_VERSION}"

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "[-] Error: This script must be run as root (or with sudo)." >&2
    exit 1
fi

if [ -z "${UE_VERSION}" ] || [ -z "${ARCHIVE_PATH}" ]; then
    echo "[-] Usage: sudo ./install-ue-archive.sh <version> <path_to_zip_or_folder>" >&2
    echo "    Example: sudo ./install-ue-archive.sh 5.5.4 /tmp/Linux_Unreal_Engine_5.5.4.zip" >&2
    exit 1
fi

if [ ! -e "${ARCHIVE_PATH}" ]; then
    echo "[-] Error: Archive path '${ARCHIVE_PATH}' does not exist." >&2
    exit 1
fi

# Determine the actual non-root user who invoked sudo for later ownership assignment
TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"

echo "[+] Preparing installation directory: ${TARGET_DIR}"
mkdir -p "${TARGET_DIR}"

# Extract depending on whether it's a single zip or multi-part/directory
echo "[+] Extracting Unreal Engine ${UE_VERSION} binaries..."
if [ -d "${ARCHIVE_PATH}" ]; then
    # If it's a directory containing files
    cp -r "${ARCHIVE_PATH}/"* "${TARGET_DIR}/"
elif [[ "${ARCHIVE_PATH}" == *.zip ]]; then
    # Check if 7zip is available (handles split/large archives efficiently)
    if command -v 7zz &>/dev/null; then
        7zz x "${ARCHIVE_PATH}" -o"${TARGET_DIR}" -y
    elif command -v unzip &>/dev/null; then
        unzip -q "${ARCHIVE_PATH}" -d "${TARGET_DIR}"
    else
        echo "[-] Error: Neither 'unzip' nor '7zz' (7-Zip) is installed." >&2
        exit 1
    fi
elif [[ "${ARCHIVE_PATH}" == *.zip.001 ]]; then
    # Multi-part zip file handling
    if command -v 7zz &>/dev/null; then
        7zz x "${ARCHIVE_PATH}" -o"${TARGET_DIR}" -y
    else
        echo "[-] Error: '7zz' is required to extract multi-part Unreal Engine archives." >&2
        exit 1
    fi
else
    echo "[-] Error: Unsupported archive format." >&2
    exit 1
fi

# Set proper ownership so the standard developer user can access/modify projects safely
echo "[+] Setting ownership of ${TARGET_DIR} to user: ${TARGET_USER}"
chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_DIR}"

echo "[✔] Success! Unreal Engine ${UE_VERSION} is installed and ready at ${TARGET_DIR}"