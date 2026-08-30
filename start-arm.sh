#!/bin/sh
# =============================================================================
# start-arm.sh — MediaStack ARM Satellite Launcher (Raspberry Pi / Linux ARM)
# =============================================================================
# Usage:
#   ./start-arm.sh            # start
#   ./start-arm.sh down       # stop
#   ./start-arm.sh restart    # stop → start
#   ./start-arm.sh logs       # tail all logs
#   ./start-arm.sh ps         # status table
#   ./start-arm.sh pull       # pull latest images
# =============================================================================

set -e

COMPOSE_FILES="-f docker-compose.yml -f docker-compose.arm.yml"
export ARCH_PROFILE="arm"

# ── ANSI colours ──────────────────────────────────────────────────────────────
BLK='\033[0;30m'  ;  BBLK='\033[1;30m'
RED='\033[0;31m'  ;  BRED='\033[1;31m'
GRN='\033[0;32m'  ;  BGRN='\033[1;32m'
YEL='\033[0;33m'  ;  BYEL='\033[1;33m'
BLU='\033[0;34m'  ;  BBLU='\033[1;34m'
MAG='\033[0;35m'  ;  BMAG='\033[1;35m'
CYN='\033[0;36m'  ;  BCYN='\033[1;36m'
WHT='\033[0;37m'  ;  BWHT='\033[1;37m'
RST='\033[0m'

# Bold + colour combos used in the banner gradient
G1="${BMAG}" ; G2="${MAG}" ; G3="${BWHT}" ; G4="${CYN}" ; G5="${MAG}"

ok()    { printf "${BGRN}  ✔  %s${RST}\n" "$*"; }
warn()  { printf "${BYEL}  ⚠  %s${RST}\n" "$*"; }
info()  { printf "${BWHT}  ➜  %s${RST}\n" "$*"; }
err()   { printf "${BRED}  ✖  %s${RST}\n" "$*" >&2; }
dim()   { printf "${BBLK}%s${RST}" "$*"; }
NL()    { printf "\n"; }

# ── Banner ────────────────────────────────────────────────────────────────────
show_banner() {
  COLS=$(tput cols 2>/dev/null || echo 82)
  BAR_W=$((COLS - 6))
  INNER_W=$((COLS - 4))

  NL
  # Top border
  printf "${MAG}  ╔"; printf "${MAG}═%.0s" $(seq 1 $INNER_W); printf "╗${RST}\n"
  printf "${MAG}  ║${RST}"; printf " %.0s" $(seq 1 $INNER_W); printf "${MAG}║${RST}\n"

  # Title line with gradient
  printf "${MAG}  ║  "
  printf "${G1}░▒▓${RST} "
  printf "${G3}MEDIASTACK${RST} "
  printf "${G1}▓▒░${RST}   "
  printf "${BMAG}ARM Satellite Edition${RST}"
  TITLE_LEN=45
  PAD=$((INNER_W - TITLE_LEN))
  printf "%${PAD}s" ""
  printf "${MAG}║${RST}\n"

  # Tagline
  printf "${MAG}  ║  ${BBLK}Raspberry Pi · ARM Laptop  ·  Music · Theming  ·  LAN-only${RST}"
  TLEN=60
  PAD=$((INNER_W - TLEN - 2))
  printf "%${PAD}s" ""
  printf "${MAG}║${RST}\n"

  # Colour bar
  printf "${MAG}  ║  "
  COLORS="${MAG} ${BMAG} ${MAG} ${BWHT} ${MAG} ${BMAG} ${BWHT} ${MAG} ${BMAG} ${MAG} "
  i=0
  printf "${MAG}▓▓${BMAG}▒▒${MAG}░░  ${BMAG}▓▓${MAG}▒▒${BWHT}░░  ${MAG}A${BMAG}R${BWHT}M${MAG}  ${BWHT}░░${MAG}▒▒${BMAG}▓▓  ${MAG}░░${BMAG}▒▒${MAG}▓▓"
  BAR_TEXT="▓▓▒▒░░  ▓▓▒▒░░  ARM  ░░▒▒▓▓  ░░▒▒▓▓"
  BAR_LEN=$(printf "%s" "${BAR_TEXT}" | wc -c)
  PAD=$((INNER_W - BAR_LEN - 2))
  printf "${RST}%${PAD}s" ""
  printf "${MAG}║${RST}\n"

  printf "${MAG}  ║${RST}"; printf " %.0s" $(seq 1 $INNER_W); printf "${MAG}║${RST}\n"
  printf "${MAG}  ╚"; printf "${MAG}═%.0s" $(seq 1 $INNER_W); printf "╝${RST}\n"
  NL
}

# ── Read .env value ───────────────────────────────────────────────────────────
get_env() {
  KEY="$1"; DEFAULT="${2:-}"
  if [ -f ".env" ]; then
    VALUE="$(grep "^${KEY}=" .env 2>/dev/null | head -1 | cut -d= -f2-)"
    [ -n "${VALUE}" ] && { printf "%s" "${VALUE}"; return; }
  fi
  printf "%s" "${DEFAULT}"
}

# ── Get LAN IP ────────────────────────────────────────────────────────────────
get_lan_ip() {
  hostname -I 2>/dev/null | awk '{print $1}'
}

# ── Service table ─────────────────────────────────────────────────────────────
show_services() {
  LAN_IP="$1"
  IP="${LAN_IP:-<pi-ip>}"
  COLS=$(tput cols 2>/dev/null || echo 82)
  LINE_W=$((COLS - 4))

  NL
  printf "${BMAG}  SATELLITE SERVICES  "
  printf "${MAG}─%.0s" $(seq 1 $((LINE_W - 22))); printf "${RST}\n"
  NL
  printf "${BBLK}  %-4s %-16s %-25s %s${RST}\n" " " "SERVICE" "ROLE" "ACCESS URL"
  printf "${BBLK}  "
  printf "─%.0s" $(seq 1 $LINE_W)
  printf "${RST}\n"

  # Services
  svc_line() {
    ICON="$1"; NAME="$2"; ROLE="$3"; URL="$4"; URL_COLOR="$5"
    printf "  ${BWHT}%s  %-16s${RST}" "${ICON}" "${NAME}"
    printf "${BBLK}%-25s${RST}" "${ROLE}"
    printf "${URL_COLOR}%s${RST}\n" "${URL}"
  }

  svc_line "🎵" "Jellyfin"     "Music Server"          "http://${IP}   (or :8096)"     "${BMAG}"
  svc_line "🌐" "Caddy"        "LAN Reverse Proxy"     "http://${IP}   (port 80)"       "${BMAG}"
  svc_line "🔄" "Syncthing"    "Theme Sync Receiver"   "http://${IP}:8384"              "${BMAG}"
  svc_line "🛡️ " "healthguard"  "Self-Healing"          "(background daemon)"           "${BBLK}"
  svc_line "🔁" "Watchtower"   "Auto Image Updates"    "(daily 04:00 cron)"            "${BBLK}"
  svc_line "⚙️ " "db-init"      "Startup Init"          "(one-shot, exits 0)"           "${BBLK}"

  printf "${BBLK}  "
  printf "─%.0s" $(seq 1 $LINE_W)
  printf "${RST}\n"
  NL

  MAIN_HOST="$(get_env MAIN_SERVER_HOST)"
  if [ -n "${MAIN_HOST}" ]; then
    printf "  🖥️  ${BWHT}%-25s${RST}${BCYN}http://%s${RST}\n" "Main Server (x64)" "${MAIN_HOST}"
    printf "${BBLK}  "
    printf "─%.0s" $(seq 1 $LINE_W)
    printf "${RST}\n"
    NL
  fi
}

# ── Live status ───────────────────────────────────────────────────────────────
show_status() {
  WAIT="${1:-6}"
  NL
  printf "${BMAG}  CONTAINER STATUS${RST}${BBLK}  (checking in ${WAIT}s…)${RST}\n"
  sleep "${WAIT}"

  COLS=$(tput cols 2>/dev/null || echo 82)
  LINE_W=$((COLS - 4))

  NL
  printf "${BBLK}  "; printf "─%.0s" $(seq 1 $LINE_W); printf "${RST}\n"
  printf "${BBLK}  %-24s %-32s %s${RST}\n" "CONTAINER" "STATUS" "HEALTH"
  printf "${BBLK}  "; printf "─%.0s" $(seq 1 $LINE_W); printf "${RST}\n"

  # shellcheck disable=SC2086
  docker compose ${COMPOSE_FILES} ps --format "{{.Name}}\t{{.Status}}\t{{.Health}}" 2>/dev/null | \
  while IFS="	" read -r name status health; do
    [ -z "${name}" ] && continue
    # Status colour
    case "${status}" in
      Up*)     SC="${BGRN}" ;;
      Exited*) SC="${BBLK}" ;;
      *)       SC="${BYEL}" ;;
    esac
    # Health icon
    case "${health}" in
      healthy)   HI="💚 healthy"  ; HC="${BGRN}" ;;
      unhealthy) HI="🔴 unhealthy" ; HC="${BRED}" ;;
      starting)  HI="🟡 starting"  ; HC="${BYEL}" ;;
      *)
        if echo "${name}" | grep -q "db-init"; then
          HI="✔  exited (normal)"; HC="${BBLK}"
        else
          HI="─"; HC="${BBLK}"
        fi ;;
    esac
    printf "  ${BWHT}%-24s${RST}${SC}%-32s${RST}${HC}%s${RST}\n" "${name}" "${status}" "${HI}"
  done

  printf "${BBLK}  "; printf "─%.0s" $(seq 1 $LINE_W); printf "${RST}\n"
}

# ── Connectivity Report ───────────────────────────────────────────────────────
show_connectivity_report() {
  MAIN_HOST="$1"
  COLS=$(tput cols 2>/dev/null || echo 82)
  LINE_W=$((COLS - 4))
  NL
  printf "${BMAG}  CONNECTIVITY DIAGNOSTICS${RST}\n"
  printf "${BBLK}  "; printf "─%.0s" $(seq 1 $LINE_W); printf "${RST}\n"

  test_ping() {
    NAME="$1"; HOST="$2"
    [ -z "${HOST}" ] && return
    printf "  ${BWHT}[*] Pinging %-17s (%-18s) ... ${RST}" "${NAME}" "${HOST}"
    if ping -c 1 -W 2 "${HOST}" >/dev/null 2>&1; then
      printf "${BGRN}[OK] ONLINE${RST}\n"
    else
      printf "${BRED}[X] UNREACHABLE${RST}\n"
    fi
  }

  test_ping "Internet (DNS)" "8.8.8.8"
  test_ping "Main Server" "${MAIN_HOST}"
  test_ping "Media NAS" "Ordinateurdevol"

  printf "${BBLK}  "; printf "═%.0s" $(seq 1 $LINE_W); printf "${RST}\n"
  NL
}

# ── Commands ──────────────────────────────────────────────────────────────────
show_commands() {
  COLS=$(tput cols 2>/dev/null || echo 82)
  LINE_W=$((COLS - 4))
  NL
  printf "${BMAG}  QUICK COMMANDS  "
  printf "${MAG}─%.0s" $(seq 1 $((LINE_W - 17))); printf "${RST}\n"
  NL

  cmd_line() {
    printf "  ${MAG}%-62s${RST}${BBLK}%s${RST}\n" "$1" "$2"
  }
  cmd_line "./start-arm.sh ps"         "Live container status"
  cmd_line "./start-arm.sh logs"       "Tail all service logs"
  cmd_line "./start-arm.sh down"       "Stop the satellite stack"
  cmd_line "./start-arm.sh restart"    "Restart all services"
  cmd_line "./start-arm.sh pull"       "Pull latest ARM images"
  # shellcheck disable=SC2016
  cmd_line 'docker compose -f docker-compose.yml -f docker-compose.arm.yml logs -f healthguard' \
           "Self-heal event stream"

  NL
  printf "${MAG}  "; printf "═%.0s" $(seq 1 $LINE_W); printf "${RST}\n"
  NL
}

# ══════════════════════════════════════════════════════════════════════════════
# Main dispatch
# ══════════════════════════════════════════════════════════════════════════════
show_banner

ARCH="$(uname -m)"
LAN_IP="$(get_lan_ip)"
MAIN_HOST="$(get_env MAIN_SERVER_HOST)"
DEVICE_NAME="$(get_env ARM_DEVICE_NAME "mediastack-arm")"

# Architecture info
case "${ARCH}" in
  aarch64|arm64) ok "Architecture : arm64  (Pi 4/5, Snapdragon X, Apple Silicon)" ;;
  armv7l|armhf)  ok "Architecture : arm/v7 (Pi 3, Zero 2 W)" ;;
  x86_64)        warn "Architecture : x86_64 — x64 profile recommended (.\start-x64.ps1)" ;;
  *)             ok "Architecture : ${ARCH}" ;;
esac

ok "Device name  : ${DEVICE_NAME}"
[ -n "${LAN_IP}" ] && ok "LAN IP       : ${LAN_IP}"
[ -n "${MAIN_HOST}" ] && ok "Main server  : http://${MAIN_HOST}" || \
  warn "MAIN_SERVER_HOST not set in .env"
NL

CMD="${1:-up}"

case "${CMD}" in
  up)
    show_services "${LAN_IP}"

    if [ "${1}" = "--build" ] || [ "${2}" = "--build" ]; then
      info "Pulling latest ARM images…"
      # shellcheck disable=SC2086
      docker compose ${COMPOSE_FILES} pull
      NL
    fi

    info "Launching ARM satellite stack…"
    NL
    # shellcheck disable=SC2086
    docker compose ${COMPOSE_FILES} up -d
    NL

    ok "Satellite is up!"
    show_status 6

    NL
    IP="${LAN_IP:-<pi-ip>}"
    COLS=$(tput cols 2>/dev/null || echo 82)
    LINE_W=$((COLS - 4))

    printf "${BMAG}  ACCESS SERVICES  "
    printf "${MAG}─%.0s" $(seq 1 $((LINE_W - 18))); printf "${RST}\n"
    NL
    printf "  🎵  ${BWHT}%-22s${RST}${BMAG}http://%s${RST}${BBLK}   (or http://%s:8096)${RST}\n" \
      "Jellyfin (music)" "${IP}" "${IP}"
    printf "  🔄  ${BWHT}%-22s${RST}${BMAG}http://%s:8384${RST}\n" "Syncthing" "${IP}"
    if [ -n "${MAIN_HOST}" ]; then
      printf "  🖥️   ${BWHT}%-22s${RST}${BCYN}http://%s${RST}\n" "Main server (x64)" "${MAIN_HOST}"
    fi

    show_connectivity_report "${MAIN_HOST}"
    show_commands
    ;;

  down)
    info "Stopping ARM satellite stack…"
    # shellcheck disable=SC2086
    docker compose ${COMPOSE_FILES} down
    ok "Stack stopped."
    NL
    ;;

  restart)
    info "Restarting ARM satellite…"
    # shellcheck disable=SC2086
    docker compose ${COMPOSE_FILES} down
    # shellcheck disable=SC2086
    docker compose ${COMPOSE_FILES} up -d
    show_status 6
    ok "Restart complete."
    NL
    ;;

  logs)
    # shellcheck disable=SC2086
    docker compose ${COMPOSE_FILES} logs -f
    ;;

  ps)
    show_status 0
    show_commands
    ;;

  pull)
    info "Pulling latest ARM images…"
    # shellcheck disable=SC2086
    docker compose ${COMPOSE_FILES} pull
    ok "Done. Run ./start-arm.sh restart to apply."
    NL
    ;;

  *)
    info "Running: docker compose ${COMPOSE_FILES} $*"
    # shellcheck disable=SC2086
    docker compose ${COMPOSE_FILES} "$@"
    ;;
esac
