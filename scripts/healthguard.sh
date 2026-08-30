#!/bin/sh
# =============================================================================
# healthguard.sh — MediaStack self-healing health monitor
# =============================================================================
# Runs continuously as a long-lived sidecar container.
# Requires the Docker socket mounted at /var/run/docker.sock.
#
# Behaviour:
#   • Polls all stack containers every 30 s via the Docker CLI
#   • Detects: unhealthy | exited | dead | OOM-killed states
#   • Attempts docker restart up to MAX_RESTARTS times within WINDOW_SECS
#   • After MAX_RESTARTS failures: logs CRITICAL and backs off BACKOFF_SECS
#   • All events written to /mediastack/logs/healthguard.log (append)
#     AND echoed to stdout (visible via `docker compose logs healthguard`)
#
# Environment variables:
#   POLL_INTERVAL_SECS — how often to check (default 30)
#   MAX_RESTARTS       — max restart attempts per window (default 3)
#   WINDOW_SECS        — restart-count reset window in seconds (default 600)
#   BACKOFF_SECS       — cooldown after giving up (default 3600 = 1 h)
#   COMPOSE_PROJECT    — Docker Compose project name (default "mediastack")
# =============================================================================

set -e

# ── Config ────────────────────────────────────────────────────────────────────
POLL_INTERVAL="${POLL_INTERVAL_SECS:-30}"
MAX_RESTARTS="${MAX_RESTARTS:-3}"
WINDOW_SECS="${WINDOW_SECS:-600}"
BACKOFF_SECS="${BACKOFF_SECS:-3600}"
COMPOSE_PROJECT="${COMPOSE_PROJECT:-mediastack}"

LOG_FILE="/mediastack/logs/healthguard.log"
LOG_DIR="/mediastack/logs"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[1;33m'
BLU='\033[0;34m'
CYN='\033[0;36m'
MAG='\033[0;35m'
WHT='\033[1;37m'
RST='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
ts()      { date '+%Y-%m-%d %H:%M:%S'; }
log_raw() { printf "%s  %s\n" "$(ts)" "$*"; }

# Log to both stdout and the log file
log_info()     { MSG="[INFO]     $*";     log_raw "${MSG}"; printf "${GRN}%s  %s${RST}\n" "$(ts)" "${MSG}" >> "${LOG_FILE}"; }
log_warn()     { MSG="[WARN]     $*";     log_raw "${MSG}"; printf "${YEL}%s  %s${RST}\n" "$(ts)" "${MSG}" >> "${LOG_FILE}"; }
log_error()    { MSG="[ERROR]    $*";     log_raw "${MSG}"; printf "${RED}%s  %s${RST}\n" "$(ts)" "${MSG}" >> "${LOG_FILE}"; }
log_critical() { MSG="[CRITICAL] $*";     log_raw "${MSG}"; printf "${RED}${WHT}%s  %s${RST}\n" "$(ts)" "${MSG}" >> "${LOG_FILE}"; }
log_action()   { MSG="[ACTION]   $*";     log_raw "${MSG}"; printf "${CYN}%s  %s${RST}\n" "$(ts)" "${MSG}" >> "${LOG_FILE}"; }
log_recover()  { MSG="[RECOVER]  $*";     log_raw "${MSG}"; printf "${MAG}%s  %s${RST}\n" "$(ts)" "${MSG}" >> "${LOG_FILE}"; }

separator() {
  printf "%s\n" "────────────────────────────────────────────────────────────" \
    | tee -a "${LOG_FILE}"
}

# ── Startup ───────────────────────────────────────────────────────────────────
mkdir -p "${LOG_DIR}"

log_info "════════════════════════════════════════════════════════════"
log_info "  healthguard started — MediaStack self-healing monitor"
log_info "  Project   : ${COMPOSE_PROJECT}"
log_info "  Poll      : every ${POLL_INTERVAL}s"
log_info "  Restart   : up to ${MAX_RESTARTS}x per ${WINDOW_SECS}s window"
log_info "  Backoff   : ${BACKOFF_SECS}s after giving up"
log_info "  Log file  : ${LOG_FILE}"
log_info "════════════════════════════════════════════════════════════"

# ── State tracking (in-memory, per-container associative-style) ───────────────
# We store state in temp files keyed by container name to avoid needing bash 4+
STATE_DIR="/tmp/healthguard"
mkdir -p "${STATE_DIR}"

restart_count() { cat "${STATE_DIR}/${1}.count" 2>/dev/null || echo 0; }
window_start()  { cat "${STATE_DIR}/${1}.window" 2>/dev/null || echo 0; }
backoff_until() { cat "${STATE_DIR}/${1}.backoff" 2>/dev/null || echo 0; }

set_restart_count() { printf "%d" "$2" > "${STATE_DIR}/${1}.count"; }
set_window_start()  { printf "%d" "$2" > "${STATE_DIR}/${1}.window"; }
set_backoff_until() { printf "%d" "$2" > "${STATE_DIR}/${1}.backoff"; }
reset_state()       {
  rm -f "${STATE_DIR}/${1}.count" "${STATE_DIR}/${1}.window" "${STATE_DIR}/${1}.backoff"
}

# ── Health check loop ─────────────────────────────────────────────────────────
LAST_SUMMARY_TS=0

while true; do
  NOW="$(date +%s)"

  # ── Periodic "all healthy" summary (every 5 minutes) ──
  if [ $((NOW - LAST_SUMMARY_TS)) -ge 300 ]; then
    separator
    log_info "Status sweep — checking all ${COMPOSE_PROJECT} containers"
    LAST_SUMMARY_TS="${NOW}"
  fi

  # Format: "name|status"
  CONTAINER_LIST="$(docker ps -a \
    --filter "label=com.docker.compose.project=${COMPOSE_PROJECT}" \
    --format "{{.Names}}|{{.Status}}" 2>/dev/null || true)"

  if [ -z "${CONTAINER_LIST}" ]; then
    log_warn "No containers found for project '${COMPOSE_PROJECT}'. Is the stack running?"
    sleep "${POLL_INTERVAL}"
    continue
  fi

  ALL_HEALTHY=true

  echo "${CONTAINER_LIST}" | while IFS='|' read -r CNAME CSTATUS; do
    [ -z "${CNAME}" ] && continue

    # ── Determine problem state ──
    PROBLEM=""

    # Parse health from status string e.g., "Up 2 days (healthy)"
    case "${CSTATUS}" in
      *"(unhealthy)"*) PROBLEM="unhealthy (healthcheck failing)" ;;
    esac

    # Also catch exited/dead containers that are not just the init container
    if [ -z "${PROBLEM}" ]; then
      case "${CSTATUS}" in
        Exited*|Dead*|OOM*)
          # Skip one-shot init containers that are supposed to exit
          case "${CNAME}" in
            *db-init*) ;;  # expected exit — ignore
            *) PROBLEM="container stopped unexpectedly (${CSTATUS})" ;;
          esac
          ;;
      esac
    fi

    # ── If healthy/running with no issue, reset state and continue ──
    if [ -z "${PROBLEM}" ]; then
      # If it was previously in error state, log recovery
      if [ "$(restart_count "${CNAME}")" -gt 0 ]; then
        log_recover "Container '${CNAME}' is now healthy — resetting error state"
        reset_state "${CNAME}"
      fi
      continue
    fi

    ALL_HEALTHY=false
    log_error "Container '${CNAME}': ${PROBLEM}"

    # ── Check backoff ──
    BOFF="$(backoff_until "${CNAME}")"
    if [ "${NOW}" -lt "${BOFF}" ]; then
      REMAINING=$((BOFF - NOW))
      log_warn "Container '${CNAME}': in backoff — skipping restart (${REMAINING}s remaining)"
      continue
    fi

    # ── Check restart window; reset count if window has expired ──
    WIN_START="$(window_start "${CNAME}")"
    COUNT="$(restart_count "${CNAME}")"

    if [ $((NOW - WIN_START)) -ge "${WINDOW_SECS}" ]; then
      # Window expired — reset counters
      COUNT=0
      set_window_start "${CNAME}" "${NOW}"
      set_restart_count "${CNAME}" 0
    fi

    # ── Decide: restart or give up ──
    if [ "${COUNT}" -ge "${MAX_RESTARTS}" ]; then
      BOFF_UNTIL=$((NOW + BACKOFF_SECS))
      log_critical "Container '${CNAME}': ${MAX_RESTARTS} restarts already attempted in ${WINDOW_SECS}s — GIVING UP"
      log_critical "Container '${CNAME}': backing off until $(date -d "@${BOFF_UNTIL}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "${BOFF_UNTIL}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "${BOFF_UNTIL}")"
      log_critical "Manual intervention required. Check logs: docker compose logs ${CNAME}"
      set_backoff_until "${CNAME}" "${BOFF_UNTIL}"
    else
      NEW_COUNT=$((COUNT + 1))
      log_action "Restarting '${CNAME}' (attempt ${NEW_COUNT}/${MAX_RESTARTS}) — reason: ${PROBLEM}"
      set_restart_count "${CNAME}" "${NEW_COUNT}"

      if docker restart "${CNAME}" >/dev/null 2>&1; then
        log_action "Restart command issued for '${CNAME}' — waiting for it to come back..."
      else
        log_error "Failed to issue restart for '${CNAME}' — check Docker socket permissions"
      fi
    fi
  done

  sleep "${POLL_INTERVAL}"
done
