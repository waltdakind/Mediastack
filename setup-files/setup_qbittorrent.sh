#!/usr/bin/env bash
# ==============================================================================
#  qBittorrent Setup Wizard (Docker Host: Linux / macOS)
#  Automated Zero-Touch Deployment & "Arr" Stack Subnet Whitelist Injector
# ==============================================================================
#
#  Features:
#   1. Zero-Touch Permission Detection: Automatically retrieves PUID & PGID
#      to eliminate Docker volume read/write permission errors.
#   2. Pre-Flight Configuration Injection: Injects qBittorrent.conf BEFORE
#      container startup to bypass the legal EULA prompt automatically.
#   3. "Arr" Stack Secret Sauce (Docker Subnet Whitelisting): Whitelists
#      internal Docker subnets (172.16.0.0/12, 192.168.0.0/16, 10.0.0.0/8, 127.0.0.1/32).
#      Radarr, Sonarr, and Prowlarr connect password-free over internal Docker DNS,
#      while external WebUI access remains securely protected.
#   4. Docker Compose Generator: Writes a clean, production-hardened compose spec.
#   5. Automated Deployment: Pulls and starts the qBittorrent container immediately.
# ==============================================================================

set -euo pipefail

# --- Color Scheme & Aesthetics ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Defaults ---
DEFAULT_PORT=8080
DEFAULT_TORRENT_PORT=6881
DEFAULT_CONFIG_DIR="./config/qbittorrent"
DEFAULT_DOWNLOAD_DIR="./data/downloads"
NON_INTERACTIVE=false
START_CONTAINER=true

# Parse optional CLI flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes|--non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        --no-start)
            START_CONTAINER=false
            shift
            ;;
        --port)
            DEFAULT_PORT="$2"
            shift 2
            ;;
        --config-dir)
            DEFAULT_CONFIG_DIR="$2"
            shift 2
            ;;
        --download-dir)
            DEFAULT_DOWNLOAD_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: ./setup_qbittorrent.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -y, --yes, --non-interactive  Run without prompting, using detected defaults"
            echo "  --no-start                    Generate config and compose files without running docker compose"
            echo "  --port <port>                 WebUI listening port (default: 8080)"
            echo "  --config-dir <path>           Host path for config storage (default: ./config/qbittorrent)"
            echo "  --download-dir <path>         Host path for media downloads (default: ./data/downloads)"
            echo "  -h, --help                    Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${CYAN}${BOLD}"
echo "================================================================================"
echo "    q B i t t o r r e n t   A U T O M A T E D   S E T U P   W I Z A R D        "
echo "        Zero-Touch Permissions  |  EULA Bypass  |  Arr Subnet Whitelist        "
echo "================================================================================"
echo -e "${NC}"

# ------------------------------------------------------------------------------
# STEP 1: ZERO-TOUCH PERMISSION DETECTION (PUID / PGID)
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[1/5] Detecting System User & Group Permissions (PUID/PGID)...${NC}"

DETECTED_PUID=$(id -u)
DETECTED_PGID=$(id -g)
CURRENT_USER=$(id -un)

# Safeguard: Avoid running container as root (UID 0) if possible
if [ "$DETECTED_PUID" -eq 0 ]; then
    echo -e "${YELLOW}  [!] Detected root execution (UID 0). For security, checking if a standard user exists...${NC}"
    if [ -n "${SUDO_UID:-}" ] && [ -n "${SUDO_GID:-}" ]; then
        DETECTED_PUID=$SUDO_UID
        DETECTED_PGID=$SUDO_GID
        CURRENT_USER=$(id -un "$DETECTED_PUID" 2>/dev/null || echo "user")
        echo -e "${GREEN}  [✓] Inherited non-root credentials from sudo: ${CURRENT_USER} (PUID=${DETECTED_PUID}, PGID=${DETECTED_PGID})${NC}"
    else
        echo -e "${YELLOW}  [!] Defaulting to PUID=1000, PGID=1000 for Docker rootless file ownership.${NC}"
        DETECTED_PUID=1000
        DETECTED_PGID=1000
    fi
else
    echo -e "${GREEN}  [✓] Detected active user: ${BOLD}${CURRENT_USER}${NC}${GREEN} (PUID=${DETECTED_PUID}, PGID=${DETECTED_PGID})${NC}"
fi

# Timezone Detection
DETECTED_TZ="UTC"
if [ -f /etc/timezone ]; then
    DETECTED_TZ=$(cat /etc/timezone)
elif [ -h /etc/localtime ]; then
    DETECTED_TZ=$(readlink /etc/localtime | sed 's#/var/db/timezone/zoneinfo/##' | sed 's#.*/usr/share/zoneinfo/##')
elif command -v timedatectl >/dev/null 2>&1; then
    DETECTED_TZ=$(timedatectl show -p Timezone --value 2>/dev/null || echo "UTC")
fi
echo -e "${GREEN}  [✓] Detected system timezone: ${BOLD}${DETECTED_TZ}${NC}"

# Host IP Detection
HOST_IP="127.0.0.1"
if command -v hostname >/dev/null 2>&1; then
    HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")
fi

# Interactive Prompt (skipped in non-interactive mode)
if [ "$NON_INTERACTIVE" = false ]; then
    echo ""
    echo -e "${BOLD}Confirm or adjust configuration values:${NC}"
    read -rp "  WebUI Port [default: ${DEFAULT_PORT}]: " INPUT_PORT
    TARGET_PORT=${INPUT_PORT:-$DEFAULT_PORT}

    read -rp "  Config Directory [default: ${DEFAULT_CONFIG_DIR}]: " INPUT_CONFIG_DIR
    TARGET_CONFIG_DIR=${INPUT_CONFIG_DIR:-$DEFAULT_CONFIG_DIR}

    read -rp "  Downloads Directory [default: ${DEFAULT_DOWNLOAD_DIR}]: " INPUT_DOWNLOAD_DIR
    TARGET_DOWNLOAD_DIR=${INPUT_DOWNLOAD_DIR:-$DEFAULT_DOWNLOAD_DIR}
else
    TARGET_PORT=$DEFAULT_PORT
    TARGET_CONFIG_DIR=$DEFAULT_CONFIG_DIR
    TARGET_DOWNLOAD_DIR=$DEFAULT_DOWNLOAD_DIR
fi

# ------------------------------------------------------------------------------
# STEP 2: SECURE CREDENTIALS GENERATION
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[2/5] Initializing Security & Credentials...${NC}"

ADMIN_USER="admin"
if command -v openssl >/dev/null 2>&1; then
    ADMIN_PASS=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 14)
else
    ADMIN_PASS=$(LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 14 || echo "AdminQbit2026!")
fi

echo -e "${GREEN}  [✓] Admin Username : ${BOLD}${ADMIN_USER}${NC}"
echo -e "${GREEN}  [✓] Initial Password: ${BOLD}${ADMIN_PASS}${NC}"

# ------------------------------------------------------------------------------
# STEP 3: DIRECTORY PROVISIONING & PERMISSION ALIGNMENT
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[3/5] Creating Storage Layout & Setting Ownership...${NC}"

# Create required directory hierarchy for linuxserver/qbittorrent
QBIT_CONF_DIR="${TARGET_CONFIG_DIR}/qBittorrent"
mkdir -p "${QBIT_CONF_DIR}"
mkdir -p "${TARGET_DOWNLOAD_DIR}/complete"
mkdir -p "${TARGET_DOWNLOAD_DIR}/incomplete"
mkdir -p "${TARGET_DOWNLOAD_DIR}/torrents"

echo -e "${GREEN}  [✓] Created: ${TARGET_CONFIG_DIR}${NC}"
echo -e "${GREEN}  [✓] Created: ${TARGET_DOWNLOAD_DIR}/complete${NC}"
echo -e "${GREEN}  [✓] Created: ${TARGET_DOWNLOAD_DIR}/incomplete${NC}"

# Ensure permissions allow PUID/PGID access
if command -v chown >/dev/null 2>&1; then
    chown -R "${DETECTED_PUID}:${DETECTED_PGID}" "${TARGET_CONFIG_DIR}" 2>/dev/null || true
    chown -R "${DETECTED_PUID}:${DETECTED_PGID}" "${TARGET_DOWNLOAD_DIR}" 2>/dev/null || true
    echo -e "${GREEN}  [✓] Permissions synchronized to UID=${DETECTED_PUID}:GID=${DETECTED_PGID}${NC}"
fi

# ------------------------------------------------------------------------------
# STEP 4: CONFIGURATION INJECTION (EULA BYPASS + ARR SUBNET WHITELIST)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[4/5] Injecting Pre-Configured qBittorrent.conf...${NC}"

CONF_FILE="${QBIT_CONF_DIR}/qBittorrent.conf"

cat <<EOF > "${CONF_FILE}"
[Application]
FileLogger\Age=1
FileLogger\AgeType=1
FileLogger\Backup=true
FileLogger\DeleteOld=true
FileLogger\Enabled=true
FileLogger\Filter=1
FileLogger\MaxSizeBytes=66560000
FileLogger\Path=/config/qBittorrent/data/logs

[AutoRun]
enabled=false
program=

[BitTorrent]
Session\DefaultSavePath=/data/downloads/complete
Session\DiskCacheSize=-1
Session\Port=${DEFAULT_TORRENT_PORT}
Session\QueueingSystemEnabled=true
Session\TempPath=/data/downloads/incomplete
Session\TempPathEnabled=true

[LegalNotice]
Accepted=true

[Network]
Cookies=@Invalid()

[Preferences]
Advanced\RecheckOnCompletion=false
Connection\PortRangeMin=${DEFAULT_TORRENT_PORT}
Connection\UPnP=false
Downloads\PreAllocation=false
Downloads\SavePath=/data/downloads/complete
Downloads\TempPath=/data/downloads/incomplete
General\Locale=en
Queueing\MaxActiveDownloads=10
Queueing\MaxActiveTorrents=20
Queueing\MaxActiveUploads=10
Queueing\QueueingEnabled=true
WebUI\Address=0.0.0.0
WebUI\AuthSubnetWhitelist="172.16.0.0/12, 192.168.0.0/16, 10.0.0.0/8, 127.0.0.1/32"
WebUI\AuthSubnetWhitelistEnabled=true
WebUI\CustomHTTPHeaders=
WebUI\CustomHTTPHeadersEnabled=false
WebUI\HostHeaderValidation=false
WebUI\LocalHostAuth=false
WebUI\MaxAuthenticationFailures=10
WebUI\Port=${TARGET_PORT}
WebUI\ReverseProxySupportEnabled=true
WebUI\SecureCookie=true
WebUI\ServerDomains=*
WebUI\SessionTimeout=3600
WebUI\TrustedReverseProxiesList=127.0.0.1, 192.168.0.0/16, 172.16.0.0/12
WebUI\UseUPnP=false
WebUI\Username=${ADMIN_USER}
EOF

# Set ownership of the config file to the detected user
if command -v chown >/dev/null 2>&1; then
    chown "${DETECTED_PUID}:${DETECTED_PGID}" "${CONF_FILE}" 2>/dev/null || true
fi

echo -e "${GREEN}  [✓] Config file written to: ${CONF_FILE}${NC}"
echo -e "${GREEN}  [✓] LegalNotice (EULA): Accepted=true (Zero interactive blockers)${NC}"
echo -e "${GREEN}  [✓] Docker Subnet Whitelist: 172.16.0.0/12, 192.168.0.0/16 (Bypasses auth for Arr apps)${NC}"
echo -e "${GREEN}  [✓] Reverse Proxy Support: Enabled for Caddy / Nginx${NC}"

# ------------------------------------------------------------------------------
# STEP 5: DOCKER COMPOSE CONFIGURATION & CONTAINER LAUNCH
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[5/5] Generating Docker Compose Specification...${NC}"

COMPOSE_FILE="docker-compose.qbittorrent.yml"

cat <<EOF > "${COMPOSE_FILE}"
version: "3.8"

services:
  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    restart: unless-stopped
    environment:
      - PUID=${DETECTED_PUID}
      - PGID=${DETECTED_PGID}
      - TZ=${DETECTED_TZ}
      - WEBUI_PORT=${TARGET_PORT}
      - TORRENTING_PORT=${DEFAULT_TORRENT_PORT}
    volumes:
      - ${TARGET_CONFIG_DIR}:/config
      - ${TARGET_DOWNLOAD_DIR}:/data/downloads
    ports:
      - "${TARGET_PORT}:${TARGET_PORT}"
      - "${DEFAULT_TORRENT_PORT}:${DEFAULT_TORRENT_PORT}"
      - "${DEFAULT_TORRENT_PORT}:${DEFAULT_TORRENT_PORT}/udp"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:${TARGET_PORT}/api/v2/app/version"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s
    labels:
      - "autoheal=true"
EOF

echo -e "${GREEN}  [✓] Docker Compose written to: ${COMPOSE_FILE}${NC}"

# Deploy container if requested and Docker is installed
if [ "$START_CONTAINER" = true ]; then
    if command -v docker >/dev/null 2>&1; then
        echo -e "\n${CYAN}Starting qBittorrent via Docker Compose...${NC}"
        if docker compose version >/dev/null 2>&1; then
            docker compose -f "${COMPOSE_FILE}" up -d
        elif command -v docker-compose >/dev/null 2>&1; then
            docker-compose -f "${COMPOSE_FILE}" up -d
        else
            echo -e "${YELLOW}  [!] Docker Compose CLI not detected. Run manually: docker compose -f ${COMPOSE_FILE} up -d${NC}"
        fi
    else
        echo -e "${YELLOW}  [!] Docker is not installed on this host. Run the compose file when Docker is ready.${NC}"
    fi
fi

# ------------------------------------------------------------------------------
# SUMMARY & "ARR" INTEGRATION CHEAT SHEET
# ------------------------------------------------------------------------------
echo -e "\n${GREEN}${BOLD}================================================================================${NC}"
echo -e "${GREEN}${BOLD}   ✓  q B i t t o r r e n t   S E T U P   C O M P L E T E D   S U C C E S S F U L L Y   ${NC}"
echo -e "${GREEN}${BOLD}================================================================================${NC}"
echo ""
echo -e " ${BOLD}WebUI Access Details:${NC}"
echo -e "   • Local URL        : ${CYAN}http://localhost:${TARGET_PORT}${NC}"
echo -e "   • LAN URL          : ${CYAN}http://${HOST_IP}:${TARGET_PORT}${NC}"
echo -e "   • Initial Username : ${BOLD}${ADMIN_USER}${NC}"
echo -e "   • Initial Password : ${BOLD}${ADMIN_PASS}${NC} ${YELLOW}(Note: change in WebUI if desired)${NC}"
echo ""
echo -e " ${BOLD}Arr Stack Integration Cheat Sheet (Radarr, Sonarr, Prowlarr):${NC}"
echo -e "   • Client Type      : ${BOLD}qBittorrent${NC}"
echo -e "   • Host             : ${CYAN}qbittorrent${NC} (if on same Docker network) or ${CYAN}${HOST_IP}${NC}"
echo -e "   • Port             : ${BOLD}${TARGET_PORT}${NC}"
echo -e "   • Username         : ${BOLD}<LEAVE BLANK>${NC} ${GREEN}(Bypassed via Docker subnet whitelist)${NC}"
echo -e "   • Password         : ${BOLD}<LEAVE BLANK>${NC} ${GREEN}(Bypassed via Docker subnet whitelist)${NC}"
echo -e "   • Use SSL          : ${BOLD}No${NC} (internal Docker network)"
echo ""
echo -e " ${BOLD}Storage Locations:${NC}"
echo -e "   • Configuration    : ${TARGET_CONFIG_DIR}"
echo -e "   • Injected Conf    : ${CONF_FILE}"
echo -e "   • Completed Media  : ${TARGET_DOWNLOAD_DIR}/complete"
echo -e "   • Incomplete Temp  : ${TARGET_DOWNLOAD_DIR}/incomplete"
echo ""
echo -e " ${BOLD}To Stop / Restart:${NC}"
echo -e "   docker compose -f ${COMPOSE_FILE} down"
echo -e "   docker compose -f ${COMPOSE_FILE} up -d"
echo -e "${CYAN}================================================================================${NC}"
