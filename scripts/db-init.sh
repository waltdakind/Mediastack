#!/bin/sh
# =============================================================================
# db-init.sh — MediaStack startup initialiser
# =============================================================================
# Runs once at "docker compose up" before any application service starts.
#
# Responsibilities:
#   1. Create required directories under /mediastack
#   2. Backup CONFIG_ROOT → /mediastack/backups/<timestamp>/
#   3. Purge backups older than BACKUP_RETAIN_DAYS (default 7)
#   4. Print Windows ↔ Linux path-mapping table
#   5. Health-probe all services and write startup-health.log
#
# Environment variables (injected by docker-compose):
#   CONFIG_ROOT          — path to app config root inside container
#   BACKUP_RETAIN_DAYS   — days to keep old backups (default 7)
#   TZ                   — timezone (for timestamps)
#
# Restore variables (set in .env to trigger import on next startup):
#   RESTORE_FROM         — "latest" | "2026-08-19_13-45-00" | empty = skip
#   RESTORE_SERVICES     — "all" | "jellyfin,radarr" (default: all)
#   AUTO_RESTORE_NEW     — "true" = auto-restore when CONFIG_ROOT is empty
# =============================================================================

set -e

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[1;33m'
BLU='\033[0;34m'
CYN='\033[0;36m'
WHT='\033[1;37m'
RST='\033[0m'

# ── Config ────────────────────────────────────────────────────────────────────
CONFIG_ROOT="${CONFIG_ROOT:-/opt/mediastack/config}"
BACKUP_RETAIN_DAYS="${BACKUP_RETAIN_DAYS:-7}"
RESTORE_FROM="${RESTORE_FROM:-}"
RESTORE_SERVICES="${RESTORE_SERVICES:-all}"
AUTO_RESTORE_NEW="${AUTO_RESTORE_NEW:-false}"
MEDIASTACK_DIR="/mediastack"
BACKUP_DIR="${MEDIASTACK_DIR}/backups"
LOG_DIR="${MEDIASTACK_DIR}/logs"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
HEALTH_LOG="${LOG_DIR}/startup-health.log"

# ── Helpers ───────────────────────────────────────────────────────────────────
log()  { printf "${WHT}[db-init]${RST} %s\n" "$*"; }
ok()   { printf "${GRN}[db-init]${RST}  ✔  %s\n" "$*"; }
warn() { printf "${YEL}[db-init]${RST}  ⚠  %s\n" "$*"; }
err()  { printf "${RED}[db-init]${RST}  ✖  %s\n" "$*" >&2; }
section() {
  printf "\n${CYN}══════════════════════════════════════════════════════════${RST}\n"
  printf "${CYN}  %s${RST}\n" "$*"
  printf "${CYN}══════════════════════════════════════════════════════════${RST}\n"
}

# ── 0. Restore (Phase 0 — runs before everything else) ──────────────────────

RUN_RESTORE=false
RESTORE_REASON=""

# Explicit restore requested via RESTORE_FROM env var
if [ -n "${RESTORE_FROM}" ]; then
  RUN_RESTORE=true
  RESTORE_REASON="RESTORE_FROM=${RESTORE_FROM} is set"
fi

# Auto-restore if CONFIG_ROOT is empty and AUTO_RESTORE_NEW=true
if [ "${AUTO_RESTORE_NEW}" = "true" ] && [ "${RUN_RESTORE}" = "false" ]; then
  CONFIG_ITEM_COUNT="$(find "${CONFIG_ROOT}" -mindepth 2 -maxdepth 2 2>/dev/null | wc -l)"
  if [ "${CONFIG_ITEM_COUNT}" -eq 0 ]; then
    # CONFIG_ROOT is empty — check if any backups exist
    if find "${BACKUP_DIR}" -mindepth 1 -maxdepth 1 -type d ! -name 'pre-restore-*' \
         2>/dev/null | grep -q .; then
      RUN_RESTORE=true
      RESTORE_FROM="latest"
      RESTORE_REASON="AUTO_RESTORE_NEW=true and CONFIG_ROOT is empty"
    fi
  fi
fi

if [ "${RUN_RESTORE}" = "true" ]; then
  printf "\n${YEL}╔══════════════════════════════════════════════════════════╗${RST}\n"
  printf "${YEL}║  RESTORE MODE — importing from backup                    ║${RST}\n"
  printf "${YEL}║  Reason: %-48s║${RST}\n" "${RESTORE_REASON}"
  printf "${YEL}╚══════════════════════════════════════════════════════════╝${RST}\n\n"

  if [ -f "/scripts/restore.sh" ]; then
    # Export vars so restore.sh picks them up
    export RESTORE_FROM RESTORE_SERVICES CONFIG_ROOT
    sh /scripts/restore.sh
    RESTORE_EXIT=$?
    if [ "${RESTORE_EXIT}" -ne 0 ]; then
      warn "Restore script exited with code ${RESTORE_EXIT} — check /mediastack/logs/restore.log"
      warn "Continuing with normal startup phases..."
    fi
  else
    warn "restore.sh not found at /scripts/restore.sh — skipping restore"
    warn "Mount the scripts directory and try again."
  fi
fi

# ── 1. Create directory structure ─────────────────────────────────────────────
section "1/5  Creating directory structure"

for dir in "${BACKUP_DIR}" "${LOG_DIR}"; do
  if [ ! -d "${dir}" ]; then
    mkdir -p "${dir}"
    ok "Created ${dir}"
  else
    log "Exists: ${dir}"
  fi
done

# ── 2. Config backup ──────────────────────────────────────────────────────────
section "2/5  Backing up configuration"

DEST="${BACKUP_DIR}/${TIMESTAMP}"

if [ -d "${CONFIG_ROOT}" ]; then
  log "Source : ${CONFIG_ROOT}"
  log "Dest   : ${DEST}"
  mkdir -p "${DEST}"
  # cp -a preserves permissions/timestamps; 2>&1 captures any errors
  if cp -a "${CONFIG_ROOT}/." "${DEST}/" 2>/tmp/backup_err; then
    SIZE="$(du -sh "${DEST}" 2>/dev/null | cut -f1)"
    ok "Backup complete — ${SIZE} written to ${DEST}"
  else
    warn "Backup encountered errors (non-fatal):"
    cat /tmp/backup_err | while IFS= read -r line; do warn "  ${line}"; done
  fi
else
  warn "CONFIG_ROOT '${CONFIG_ROOT}' does not exist yet — skipping backup"
  warn "This is normal on first-run before services have written config files."
fi

# ── 3. Prune old backups ──────────────────────────────────────────────────────
section "3/5  Pruning backups older than ${BACKUP_RETAIN_DAYS} days"

if command -v find >/dev/null 2>&1; then
  PRUNED=0
  # find directories exactly 1 level deep (backup snapshots) older than N days
  find "${BACKUP_DIR}" -mindepth 1 -maxdepth 1 -type d \
    -mtime "+${BACKUP_RETAIN_DAYS}" | while IFS= read -r old_bk; do
      warn "Removing old backup: ${old_bk}"
      rm -rf "${old_bk}"
      PRUNED=$((PRUNED + 1))
  done
  ok "Pruning complete"
else
  warn "'find' not available — skipping prune"
fi

# ── 4. Windows ↔ Linux path mapping table ─────────────────────────────────────
section "4/5  Path Mapping Table"

printf "\n"
printf "${WHT}%-45s  %-35s  %s${RST}\n" "Windows Host Path" "Container Linux Path" "Access"
printf "%s\n" "─────────────────────────────────────────────────────────────────────────────────────────────"
printf "%-45s  %-35s  %s\n" "C:\\Users\\Public\\Mediastack"                  "/mediastack"                 "Read-Write"
printf "%-45s  %-35s  %s\n" "C:\\Users\\Public\\Mediastack\\backups"          "/mediastack/backups"         "Read-Write"
printf "%-45s  %-35s  %s\n" "C:\\Users\\Public\\Mediastack\\logs"             "/mediastack/logs"            "Read-Write"
printf "%-45s  %-35s  %s\n" "C:\\Users\\Public\\Mediastack\\scripts"          "/mediastack/scripts"         "Read-Only"
printf "%-45s  %-35s  %s\n" "C:\Users\Public\Music"                            "/data/music  (jellyfin)"     "Read-Only"
printf "%-45s  %-35s  %s\n" "\\\\Ordinateurdevol\\Users\\Public\\Movies"        "/data/movies (jellyfin)"     "Read-Only"
printf "%-45s  %-35s  %s\n" "                                              " "/movies       (radarr)"      "Read-Write"
printf "%-45s  %-35s  %s\n" "\\\\Ordinateurdevol\\Users\\Public\\Videos"        "/data/tv      (jellyfin)"    "Read-Only"
printf "%-45s  %-35s  %s\n" "                                              " "/tv           (sonarr)"      "Read-Write"
printf "%-45s  %-35s  %s\n" "\\\\Ordinateurdevol\\Users\\Public\\Pictures"      "/data/photos  (jellyfin)"    "Read-Only"
printf "%-45s  %-35s  %s\n" "\\\\Ordinateurdevol\\Users\\Public\\Videos\\Record" "/recordings (tvheadend)"     "Read-Write"
printf "%-45s  %-35s  %s\n" "\$CONFIG_ROOT  (e.g. /opt/mediastack/config)"   "/config       (per-service)" "Read-Write"
printf "%-45s  %-35s  %s\n" "\$DOWNLOAD_ROOT (e.g. /mnt/media/downloads)"    "/downloads    (transmission)" "Read-Write"
printf "\n"

ok "Path mapping table displayed"

# ── 5. Startup health probes ──────────────────────────────────────────────────
section "5/5  Startup health probes (ARCH_PROFILE=${ARCH_PROFILE:-x64})"

log "Waiting 10 s for services to begin initialising..."
sleep 10

HEADER="[${TIMESTAMP}] MediaStack Startup Health Report [${ARCH_PROFILE:-x64}]"
printf "%s\n%s\n" "${HEADER}" "$(printf '=%.0s' $(seq 1 ${#HEADER}))" > "${HEALTH_LOG}"
printf "Generated : %s\n" "$(date)" >> "${HEALTH_LOG}"
printf "Profile   : %s\n\n" "${ARCH_PROFILE:-x64}" >> "${HEALTH_LOG}"

PASS=0
FAIL=0

# Probe via container-name DNS (available on medianet bridge).
probe() {
  local name="$1"
  local url="$2"

  if wget --no-verbose --tries=1 --timeout=5 --spider "${url}" 2>/dev/null; then
    ok "PASS  ${name}  (${url})"
    printf "PASS  %-18s  %s\n" "${name}" "${url}" >> "${HEALTH_LOG}"
    PASS=$((PASS + 1))
  else
    err "FAIL  ${name}  (${url})"
    printf "FAIL  %-18s  %s\n" "${name}" "${url}" >> "${HEALTH_LOG}"
    FAIL=$((FAIL + 1))
  fi
}

# ── Services common to ALL profiles ─────────────────────────────────────────
probe "caddy"     "http://caddy:80"
probe "jellyfin"  "http://jellyfin:8096/health"
probe "syncthing" "http://syncthing:8384/rest/noauth/health"

# ── x64-only services ─────────────────────────────────────────────────────
if [ "${ARCH_PROFILE:-x64}" = "x64" ]; then
  probe "prowlarr"    "http://prowlarr:9696/ping"
  probe "radarr"      "http://radarr:7878/ping"
  probe "sonarr"      "http://sonarr:8989/ping"
  probe "transmission" "http://transmission:9091/transmission/web/"
  probe "tvheadend"   "http://tvheadend:9981/"
fi

printf "\nSummary: %d PASS  /  %d FAIL  (many may not be ready yet — check healthguard.log)\n" \
  "${PASS}" "${FAIL}" >> "${HEALTH_LOG}"

printf "\n"
log "Health log: ${HEALTH_LOG}"
printf "\n${WHT}Summary [%s]: ${GRN}%d PASS${RST}  /  ${RED}%d FAIL${RST}\n" "${ARCH_PROFILE:-x64}" "${PASS}" "${FAIL}"
printf "${YEL}NOTE: Failures at cold-start are normal — services take time to initialise.${RST}\n"
printf "${YEL}      Monitor live: docker compose logs -f healthguard${RST}\n\n"

ok "db-init complete — stack is starting"
exit 0
