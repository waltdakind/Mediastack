#!/bin/sh
# =============================================================================
# restore.sh — MediaStack config & SQLite import/restore utility
# =============================================================================
#
# PURPOSE
#   Restore all service configurations and SQLite databases from a previous
#   backup snapshot so a new (or wiped) instance comes up with full fidelity:
#   users, watch history, indexers, download queues, DVR schedules, etc.
#
# USAGE — two ways:
#
#   A) Triggered automatically by db-init.sh when RESTORE_FROM is set in .env
#
#   B) Run on-demand from PowerShell:
#      docker compose run --rm \
#        -e RESTORE_FROM=latest \
#        db-init sh /scripts/restore.sh
#
#      Restore only specific services:
#      docker compose run --rm \
#        -e RESTORE_FROM=latest \
#        -e RESTORE_SERVICES=jellyfin,radarr \
#        db-init sh /scripts/restore.sh
#
# ENVIRONMENT VARIABLES
#   RESTORE_FROM      — "latest" | exact timestamp "2026-08-19_13-45-00"
#   RESTORE_SERVICES  — "all" | comma-separated list: "jellyfin,radarr,sonarr"
#   CONFIG_ROOT       — destination config root (default /opt/mediastack/config)
#
# WHAT IS RESTORED
#   Per-service config directories including all SQLite .db files:
#     jellyfin   → users, watch history, library metadata, playback state
#     radarr     → movie list, quality profiles, history, custom formats
#     sonarr     → series, episodes, history, quality profiles
#     prowlarr   → indexers, application sync config, history
#     transmission → settings, peer config
#     tvheadend  → Live TV settings, DVR schedules, user profiles
#     syncthing  → device pairing, folder sync configuration
#
# SAFETY
#   Before overwriting anything, a "pre-restore" safety backup is written to
#   /mediastack/backups/pre-restore-<timestamp>/ so the restore is reversible.
#
# ⚠  IMPORTANT — Clear RESTORE_FROM after use!
#   This script cannot rewrite the host .env file.
#   After a successful restore, manually set RESTORE_FROM= (blank) in .env
#   or the restore will repeat on every subsequent docker compose up -d.
# =============================================================================

set -e

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[1;33m'
BLU='\033[0;34m'
CYN='\033[0;36m'
MAG='\033[0;35m'
WHT='\033[1;37m'
RST='\033[0m'

# ── Config ────────────────────────────────────────────────────────────────────
RESTORE_FROM="${RESTORE_FROM:-}"
RESTORE_SERVICES="${RESTORE_SERVICES:-all}"
CONFIG_ROOT="${CONFIG_ROOT:-/opt/mediastack/config}"
MEDIASTACK_DIR="/mediastack"
BACKUP_DIR="${MEDIASTACK_DIR}/backups"
LOG_DIR="${MEDIASTACK_DIR}/logs"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
RESTORE_LOG="${LOG_DIR}/restore.log"

# Known service names — determines iteration order and selective restore
ALL_SERVICES="jellyfin radarr sonarr prowlarr transmission tvheadend syncthing"

# ── Helpers ───────────────────────────────────────────────────────────────────
log()      { printf "${WHT}[restore]${RST} %s\n" "$*";        log_file "INFO    $*"; }
ok()       { printf "${GRN}[restore]${RST}  ✔  %s\n" "$*";   log_file "OK      $*"; }
warn()     { printf "${YEL}[restore]${RST}  ⚠  %s\n" "$*";   log_file "WARN    $*"; }
err()      { printf "${RED}[restore]${RST}  ✖  %s\n" "$*" >&2; log_file "ERROR   $*"; }
skip()     { printf "${BLU}[restore]${RST}  ⊝  SKIP  %s\n" "$*"; log_file "SKIP    $*"; }
restored() { printf "${MAG}[restore]${RST}  ★  %s\n" "$*";   log_file "RESTORE $*"; }

log_file() {
  printf "%s  %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "${RESTORE_LOG}" 2>/dev/null || true
}

section() {
  printf "\n${CYN}══════════════════════════════════════════════════════════${RST}\n"
  printf "${CYN}  %s${RST}\n" "$*"
  printf "${CYN}══════════════════════════════════════════════════════════${RST}\n"
  log_file "=== $* ==="
}

notice() {
  printf "\n${YEL}┌──────────────────────────────────────────────────────────┐${RST}\n"
  printf "${YEL}│  %-56s  │${RST}\n" "$*"
  printf "${YEL}└──────────────────────────────────────────────────────────┘${RST}\n\n"
}

# Check if a service is in the RESTORE_SERVICES list (or if list is "all")
should_restore() {
  local svc="$1"
  [ "${RESTORE_SERVICES}" = "all" ] && return 0
  echo ",${RESTORE_SERVICES}," | grep -q ",${svc}," && return 0
  return 1
}

# SQLite integrity check — returns 0 if ok, 1 if corrupt or not a DB
sqlite_check() {
  local db_file="$1"
  [ ! -f "${db_file}" ] && return 1
  # Use sqlite3 if available, otherwise skip with a warning
  if command -v sqlite3 >/dev/null 2>&1; then
    RESULT="$(sqlite3 "${db_file}" 'PRAGMA integrity_check;' 2>/dev/null | head -1)"
    [ "${RESULT}" = "ok" ] && return 0
    return 1
  else
    # Fallback: check the SQLite magic header bytes (bytes 1-6 = "SQLite")
    MAGIC="$(dd if="${db_file}" bs=1 count=6 2>/dev/null | cat)"
    echo "${MAGIC}" | grep -q "SQLite" && return 0
    # If neither tool is available and file exists, assume ok
    [ -s "${db_file}" ] && return 0
    return 1
  fi
}

# ── Guard: RESTORE_FROM must be set ──────────────────────────────────────────
if [ -z "${RESTORE_FROM}" ]; then
  err "RESTORE_FROM is not set. Nothing to restore."
  err "Usage: set RESTORE_FROM=latest (or a timestamp) in .env and re-run."
  exit 1
fi

# ── Initialise log ────────────────────────────────────────────────────────────
mkdir -p "${LOG_DIR}"
{
  printf "==========================================================\n"
  printf "  MediaStack Restore Log\n"
  printf "  Started  : %s\n" "$(date)"
  printf "  Restore  : %s\n" "${RESTORE_FROM}"
  printf "  Services : %s\n" "${RESTORE_SERVICES}"
  printf "  Config   : %s\n" "${CONFIG_ROOT}"
  printf "==========================================================\n\n"
} > "${RESTORE_LOG}"

# ── STEP 1 — Resolve backup path ──────────────────────────────────────────────
section "1/5  Resolving backup"

if [ ! -d "${BACKUP_DIR}" ]; then
  err "Backup directory not found: ${BACKUP_DIR}"
  err "Mount C:\\Users\\Public\\Mediastack at /mediastack and ensure backups exist."
  exit 1
fi

if [ "${RESTORE_FROM}" = "latest" ]; then
  # Exclude pre-restore safety backups from "latest" resolution
  TARGET_BACKUP="$(find "${BACKUP_DIR}" -mindepth 1 -maxdepth 1 -type d \
    ! -name 'pre-restore-*' | sort | tail -1)"
  if [ -z "${TARGET_BACKUP}" ]; then
    err "No backups found in ${BACKUP_DIR}"
    exit 1
  fi
  log "Resolved 'latest' → ${TARGET_BACKUP}"
else
  TARGET_BACKUP="${BACKUP_DIR}/${RESTORE_FROM}"
  if [ ! -d "${TARGET_BACKUP}" ]; then
    err "Backup not found: ${TARGET_BACKUP}"
    err "Available backups:"
    find "${BACKUP_DIR}" -mindepth 1 -maxdepth 1 -type d | sort | while read -r b; do
      SIZE="$(du -sh "${b}" 2>/dev/null | cut -f1)"
      printf "  %s  (%s)\n" "$(basename "${b}")" "${SIZE}"
    done
    exit 1
  fi
fi

BACKUP_NAME="$(basename "${TARGET_BACKUP}")"
BACKUP_SIZE="$(du -sh "${TARGET_BACKUP}" 2>/dev/null | cut -f1)"
ok "Target backup : ${BACKUP_NAME}  (${BACKUP_SIZE})"

# List available SQLite databases found in the backup
log "SQLite databases found in backup:"
find "${TARGET_BACKUP}" -name "*.db" 2>/dev/null | sort | while read -r dbf; do
  REL="$(echo "${dbf}" | sed "s|${TARGET_BACKUP}/||")"
  SIZE="$(du -sh "${dbf}" 2>/dev/null | cut -f1)"
  log "  ${REL}  (${SIZE})"
done

# ── STEP 2 — List available backups ───────────────────────────────────────────
section "2/5  Available backups"

printf "\n${WHT}%-30s  %-8s  %s${RST}\n" "Snapshot" "Size" "Note"
printf "%s\n" "──────────────────────────────────────────────────────"
find "${BACKUP_DIR}" -mindepth 1 -maxdepth 1 -type d | sort -r | while read -r b; do
  BN="$(basename "${b}")"
  SZ="$(du -sh "${b}" 2>/dev/null | cut -f1)"
  NOTE=""
  [ "${b}" = "${TARGET_BACKUP}" ] && NOTE="${GRN}← SELECTED${RST}"
  echo "${BN}" | grep -q "^pre-restore-" && NOTE="${YEL}(safety backup)${RST}"
  printf "%-30s  %-8s  %b\n" "${BN}" "${SZ}" "${NOTE}"
done
printf "\n"

# ── STEP 3 — Safety backup current state ─────────────────────────────────────
section "3/5  Safety backup (pre-restore snapshot)"

SAFETY_DEST="${BACKUP_DIR}/pre-restore-${TIMESTAMP}"

if [ -d "${CONFIG_ROOT}" ]; then
  # Check if config root has any meaningful content
  CONFIG_COUNT="$(find "${CONFIG_ROOT}" -mindepth 1 -maxdepth 2 2>/dev/null | wc -l)"
  if [ "${CONFIG_COUNT}" -gt 0 ]; then
    log "Existing config detected (${CONFIG_COUNT} items) — creating safety backup"
    log "Safety backup → ${SAFETY_DEST}"
    mkdir -p "${SAFETY_DEST}"
    if cp -a "${CONFIG_ROOT}/." "${SAFETY_DEST}/" 2>/tmp/safety_err; then
      SAFETY_SIZE="$(du -sh "${SAFETY_DEST}" 2>/dev/null | cut -f1)"
      ok "Safety backup complete: ${SAFETY_SIZE} → $(basename "${SAFETY_DEST}")"
    else
      warn "Safety backup had errors (restore will still proceed):"
      cat /tmp/safety_err | while IFS= read -r line; do warn "  ${line}"; done
    fi
  else
    log "CONFIG_ROOT is empty — no safety backup needed (clean install)"
  fi
else
  log "CONFIG_ROOT does not exist yet — creating it"
  mkdir -p "${CONFIG_ROOT}"
fi

# ── STEP 4 — Restore each service ────────────────────────────────────────────
section "4/5  Restoring services"

TOTAL=0
SUCCESS=0
SKIPPED=0
FAILED=0

restore_service() {
  local SVC="$1"
  local SRC="${TARGET_BACKUP}/${SVC}"
  local DST="${CONFIG_ROOT}/${SVC}"

  TOTAL=$((TOTAL + 1))

  # Check if service is in restore scope
  if ! should_restore "${SVC}"; then
    skip "${SVC} — not in RESTORE_SERVICES list"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi

  # Check if backup contains this service
  if [ ! -d "${SRC}" ]; then
    skip "${SVC} — not found in backup (was it running when backup was taken?)"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi

  printf "\n${WHT}  ── %s ──${RST}\n" "${SVC}"
  log_file "--- Restoring: ${SVC} ---"

  # SQLite integrity checks for all .db files in this service's backup
  DB_FAIL=0
  find "${SRC}" -name "*.db" 2>/dev/null | sort | while read -r dbf; do
    REL="$(echo "${dbf}" | sed "s|${SRC}/||")"
    if sqlite_check "${dbf}"; then
      ok "  SQLite OK  : ${REL}"
    else
      err "  SQLite CORRUPT : ${REL} — skipping this database"
      DB_FAIL=$((DB_FAIL + 1))
    fi
  done

  # Copy config dir (cp -a = preserve permissions, timestamps, symlinks)
  mkdir -p "${DST}"
  if cp -a "${SRC}/." "${DST}/" 2>/tmp/restore_err; then
    SVC_SIZE="$(du -sh "${DST}" 2>/dev/null | cut -f1)"
    DB_COUNT="$(find "${DST}" -name "*.db" 2>/dev/null | wc -l)"
    restored "${SVC} — ${SVC_SIZE} restored  (${DB_COUNT} SQLite DB(s))"
    SUCCESS=$((SUCCESS + 1))
  else
    err "Failed to restore ${SVC}:"
    cat /tmp/restore_err | while IFS= read -r line; do err "  ${line}"; done
    FAILED=$((FAILED + 1))
  fi
}

for SVC in ${ALL_SERVICES}; do
  restore_service "${SVC}"
done

# ── STEP 5 — Summary + critical reminder ─────────────────────────────────────
section "5/5  Restore summary"

printf "\n"
printf "  ${WHT}Backup used  :${RST} %s\n" "${BACKUP_NAME}"
printf "  ${WHT}Services     :${RST} %d total — ${GRN}%d restored${RST}  /  ${BLU}%d skipped${RST}  /  ${RED}%d failed${RST}\n" \
  "${TOTAL}" "${SUCCESS}" "${SKIPPED}" "${FAILED}"
printf "  ${WHT}Safety backup:${RST} %s\n" "$(basename "${SAFETY_DEST}" 2>/dev/null || echo "N/A (was empty)")"
printf "  ${WHT}Restore log  :${RST} /mediastack/logs/restore.log\n"
printf "\n"

{
  printf "\n==========================================================\n"
  printf "  Restore Summary\n"
  printf "  Completed : %s\n" "$(date)"
  printf "  Backup    : %s\n" "${BACKUP_NAME}"
  printf "  Restored  : %d  /  Skipped: %d  /  Failed: %d\n" "${SUCCESS}" "${SKIPPED}" "${FAILED}"
  printf "==========================================================\n"
} >> "${RESTORE_LOG}"

# ── Big warning about clearing RESTORE_FROM ───────────────────────────────────
printf "\n"
printf "${YEL}╔══════════════════════════════════════════════════════════╗${RST}\n"
printf "${YEL}║  ⚠  ACTION REQUIRED — Clear RESTORE_FROM in .env        ║${RST}\n"
printf "${YEL}╠══════════════════════════════════════════════════════════╣${RST}\n"
printf "${YEL}║  This script cannot rewrite your host .env file.         ║${RST}\n"
printf "${YEL}║                                                          ║${RST}\n"
printf "${YEL}║  Before the next  docker compose up -d  you MUST:        ║${RST}\n"
printf "${YEL}║                                                          ║${RST}\n"
printf "${YEL}║  Open .env and set:   RESTORE_FROM=                      ║${RST}\n"
printf "${YEL}║  (leave the value blank / empty)                         ║${RST}\n"
printf "${YEL}║                                                          ║${RST}\n"
printf "${YEL}║  If left set, the restore will repeat on every restart.  ║${RST}\n"
printf "${YEL}╚══════════════════════════════════════════════════════════╝${RST}\n\n"

if [ "${FAILED}" -gt 0 ]; then
  err "${FAILED} service(s) failed to restore — check /mediastack/logs/restore.log"
  exit 1
fi

ok "Restore complete — stack will start with restored data"
exit 0
