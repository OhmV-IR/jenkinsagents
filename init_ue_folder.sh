#!/bin/bash

# Ensure script is run with root privileges
if [ "$EUID" -ne 0 ]; then
    echo "[-] Error: This script must be run with sudo/root privileges." >&2
    echo "Usage: sudo ./init_ui_folder.sh"
    exit 1
fi

# Determine the actual non-root user who invoked sudo
TARGET_USER="${SUDO_USER:-$(whoami)}"
if [ "$TARGET_USER" = "root" ]; then
    read -p "Enter the username that should own the folder: " TARGET_USER
fi

# Set default path (e.g., system-wide /opt path)
TARGET_PATH="/opt/unreal-engine"

# Create the directory
echo "[+] Creating directory: $TARGET_PATH"
mkdir -p "$TARGET_PATH"

# Set ownership to the standard user
echo "[+] Setting ownership to user: $TARGET_USER"
chown -R "$TARGET_USER":"$TARGET_USER" "$TARGET_PATH"

echo "[✔] Success! Folder created and owned by $TARGET_USER."