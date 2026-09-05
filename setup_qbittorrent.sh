#!/usr/bin/env bash
# ==============================================================================
#  qBittorrent Setup Wizard (Docker Host: Linux / macOS)
#  Forwarder -> setup-files/setup_qbittorrent.sh
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_SCRIPT="${SCRIPT_DIR}/setup-files/setup_qbittorrent.sh"

if [ -f "${TARGET_SCRIPT}" ]; then
    chmod +x "${TARGET_SCRIPT}"
    exec bash "${TARGET_SCRIPT}" "$@"
else
    echo "Error: ${TARGET_SCRIPT} not found."
    exit 1
fi
