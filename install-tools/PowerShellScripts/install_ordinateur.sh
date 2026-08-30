#!/bin/bash

# Exit on any error
set -e

# Terminal Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Status Tracker Function
print_status() {
  local step=$1
  local msg=$2
  echo -e "${BLUE}[Step ${step}/7]${NC} ${msg}..."
}

# AI Error Logger Trap
error_handler() {
  local line_no=$1
  local error_code=$2
  echo "" | tee -a install_errors.log
  echo -e "${RED}[!] FATAL ERROR ENCOUNTERED${NC}" | tee -a install_errors.log
  echo "Error occurred at line: $line_no" | tee -a install_errors.log
  echo "Exit code: $error_code" | tee -a install_errors.log
  echo "Timestamp: $(date)" | tee -a install_errors.log
  echo "System Info: $(uname -a)" | tee -a install_errors.log
  echo -e "${YELLOW}Please provide the contents of 'install_errors.log' to your AI agent for debugging.${NC}" | tee -a install_errors.log
}
trap 'error_handler ${LINENO} $?' ERR

clear
echo "=============================================="
echo " MediaStack Installation & Migration Script"
echo " Target: ordinateur.local (192.168.4.21)"
echo "=============================================="
echo ""

# 1. Require root or sudo
print_status "1" "Checking permissions"
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Please run as root or with sudo.${NC}"
  exit 1
fi

# 2. Check for the backup zip argument
print_status "2" "Validating backup archive"
if [ -z "$1" ]; then
  echo "Usage: sudo ./install_ordinateur.sh <path_to_backup_zip>"
  exit 1
fi

BACKUP_ZIP="$1"
if [ ! -f "$BACKUP_ZIP" ]; then
  echo -e "${RED}Error: Backup file '$BACKUP_ZIP' not found.${NC}"
  exit 1
fi

# 3. Setup directories
print_status "3" "Provisioning storage directories"
INSTALL_DIR="/opt/mediastack"
MEDIA_DIR="/mnt/media"

mkdir -p "$INSTALL_DIR"
mkdir -p "$MEDIA_DIR/Videos"
mkdir -p "$MEDIA_DIR/Music"
mkdir -p "$MEDIA_DIR/LiveTV"
mkdir -p "$MEDIA_DIR/Pictures"

# 4. Extract backup
print_status "4" "Extracting configuration to $INSTALL_DIR"
unzip -q -o "$BACKUP_ZIP" -d "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 5. Environment & Routing Configuration
print_status "5" "Configuring environment variables and routing"
# Rename the Linux template to the active .env
if [ -f ".env.linux" ]; then
  cp .env.linux .env
fi

# The current Caddyfile routes to ordinateur.local natively via the Windows migration,
# but we ensure it binds properly here if needed.

# Get the UID/GID of the user who ran sudo (if applicable) or use 1000
REAL_UID=${SUDO_UID:-1000}
REAL_GID=${SUDO_GID:-1000}

# Ensure permissions are correct
chown -R $REAL_UID:$REAL_GID "$INSTALL_DIR"
chown -R $REAL_UID:$REAL_GID "$MEDIA_DIR"

# 6. Start Stack
print_status "6" "Pulling Docker images (Multi-Arch x64 detection)"
docker compose pull -q

print_status "7" "Starting containers"
docker compose up -d

echo ""
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN} Installation Complete!${NC}"
echo -e "${GREEN}==============================================${NC}"
echo ""
echo "[Active Service Ports]"
echo "----------------------------------------------"
echo -e "${YELLOW}Caddy (Reverse Proxy)${NC}  : 80, 443"
echo -e "${YELLOW}Jellyfin (Media)${NC}       : 8096"
echo -e "${YELLOW}Sonarr (TV)${NC}            : 8989"
echo -e "${YELLOW}Radarr (Movies)${NC}        : 7878"
echo -e "${YELLOW}Prowlarr (Indexers)${NC}    : 9696"
echo -e "${YELLOW}Bazarr (Subtitles)${NC}     : 6767"
echo -e "${YELLOW}Transmission (DL)${NC}      : 9091"
echo -e "${YELLOW}Jellyseerr (Requests)${NC}  : 5055"
echo -e "${YELLOW}TVHeadend (Live TV)${NC}    : 9981"
echo -e "${YELLOW}Homepage (Dashboard)${NC}   : 3000"
echo "----------------------------------------------"
echo ""
echo "Next Steps:"
echo " 1. Manually copy your media files to $MEDIA_DIR"
echo " 2. Access your stack at http://ordinateur.local (Port 80/443)"
echo ""
