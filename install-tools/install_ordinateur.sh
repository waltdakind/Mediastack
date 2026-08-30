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
  echo -e "${BLUE}[Step ${step}/8]${NC} ${msg}..."
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
echo " MediaStack Robust Installation Script"
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
  echo "Usage: sudo bash install_ordinateur.sh <path_to_backup_zip>"
  exit 1
fi

BACKUP_ZIP="$1"
if [ ! -f "$BACKUP_ZIP" ]; then
  echo -e "${RED}Error: Backup file '$BACKUP_ZIP' not found.${NC}"
  exit 1
fi

# 3. Network & Route Checking
print_status "3" "Network & Docker Health Check"
if ! ping -c 1 8.8.8.8 &> /dev/null; then
    echo -e "${RED}Error: No internet connectivity. Cannot pull Docker images.${NC}"
    exit 1
fi
if ! systemctl is-active --quiet docker; then
    echo -e "${YELLOW}Docker daemon is not running. Attempting to start...${NC}"
    systemctl start docker || { echo -e "${RED}Error: Failed to start Docker.${NC}"; exit 1; }
fi
echo -e "${GREEN}Network and Docker are healthy.${NC}"

# 4. Setup directories
print_status "4" "Provisioning storage directories"
INSTALL_DIR="/opt/mediastack"
MEDIA_DIR="/mnt/media"

mkdir -p "$INSTALL_DIR"
mkdir -p "$MEDIA_DIR/Videos"
mkdir -p "$MEDIA_DIR/Music"
mkdir -p "$MEDIA_DIR/LiveTV"
mkdir -p "$MEDIA_DIR/Pictures"

# 5. Extract backup
print_status "5" "Extracting configuration to $INSTALL_DIR"
unzip -q -o "$BACKUP_ZIP" -d "$INSTALL_DIR"
cd "$INSTALL_DIR"

if [ -f ".env.linux" ]; then
  cp .env.linux .env
fi

REAL_UID=${SUDO_UID:-1000}
REAL_GID=${SUDO_GID:-1000}

# Ensure permissions are correct
chown -R $REAL_UID:$REAL_GID "$INSTALL_DIR"
chown -R $REAL_UID:$REAL_GID "$MEDIA_DIR"

# 6. Start Stack & Pull Images Robustly
print_status "6" "Pulling Docker images (x64 architecture)"
COMPOSE_FILES="-f docker-compose.yml -f docker-compose.x64.yml"

# Add retries for image pulls in case of registry timeouts
for i in {1..3}; do
    if docker compose $COMPOSE_FILES pull -q; then
        echo -e "${GREEN}Docker images pulled successfully.${NC}"
        break
    else
        echo -e "${YELLOW}Warning: Docker pull failed (attempt $i/3). Retrying in 5 seconds...${NC}"
        sleep 5
        if [ "$i" -eq 3 ]; then
            echo -e "${RED}Error: Failed to pull Docker images after 3 attempts.${NC}"
            exit 1
        fi
    fi
done

print_status "7" "Starting containers"
docker compose $COMPOSE_FILES up -d

# 7. Validate Jellyfin users
print_status "8" "Validating restored users and databases"
JELLYFIN_DB="$INSTALL_DIR/config/jellyfin/data/jellyfin.db"

# Wait slightly to ensure any initial mounting logic is done
sleep 5

if [ -f "$JELLYFIN_DB" ]; then
    echo "Querying Jellyfin database directly..."
    # Query via docker to avoid needing local sqlite3 installed
    FOUND_USERS=$(docker run --rm -v "$JELLYFIN_DB:/db.sqlite" nouchka/sqlite3 /db.sqlite "SELECT Username FROM Users;" | tr '[:upper:]' '[:lower:]' || echo "")
    
    REQUIRED_USERS=("moops" "walter" "bobby" "dingos" "waltdakind")
    ALL_PRESENT=true
    for user in "${REQUIRED_USERS[@]}"; do
        # Use grep -q to see if the user exists in the returned list
        if echo "$FOUND_USERS" | grep -qw "$user"; then
            echo -e "  -> User [$user] is ${GREEN}PRESENT${NC}."
        else
            echo -e "  -> User [$user] is ${RED}MISSING${NC}!"
            ALL_PRESENT=false
        fi
    done
    
    if [ "$ALL_PRESENT" = false ]; then
        echo -e "${RED}CRITICAL: One or more required users are missing. The restore may have failed.${NC}"
    else
        echo -e "${GREEN}All 5 required users are validated and present! DB restore was successful.${NC}"
    fi
else
    echo -e "${YELLOW}Warning: Jellyfin database not found at $JELLYFIN_DB. Cannot validate users.${NC}"
fi

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
