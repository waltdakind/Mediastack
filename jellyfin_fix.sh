#!/usr/bin/env bash
# ==============================================================================
# Jellyfin Resiliency & Self-Healing Diagnostic Toolkit
#
# PURPOSE:
#   Diagnoses and automatically resolves hangs, socket deadlocks, transcode locks,
#   permission mismatches, and networking/firewall issues for Jellyfin servers
#   running natively (systemd) or in containerized environments (Docker/Podman).
#
# USAGE:
#   sudo ./jellyfin_fix.sh         # Runs full diagnostic and interactive fix
#   sudo ./jellyfin_fix.sh --fix   # Runs diagnostics and auto-applies repairs
#   sudo ./jellyfin_fix.sh --diag  # Runs diagnostics in dry-run mode (read-only)
# ==============================================================================

set -Eeuo pipefail

# -----------------------------------------------------------------------------
# Global Styling & Constants
# -----------------------------------------------------------------------------
readonly COLOR_RESET="\033[0m"
readonly COLOR_RED="\033[1;31m"
readonly COLOR_GREEN="\033[1;32m"
readonly COLOR_YELLOW="\033[1;33m"
readonly COLOR_BLUE="\033[1;34m"
readonly COLOR_CYAN="\033[1;36m"
readonly COLOR_GRAY="\033[0;90m"

readonly JELLYFIN_PORT_HTTP=8096
readonly JELLYFIN_PORT_HTTPS=8920
readonly JELLYFIN_PORT_DLNA=1900
readonly JELLYFIN_PORT_DISCOVERY=7359

readonly HEALTH_ENDPOINT_LOCAL="http://127.0.0.1:${JELLYFIN_PORT_HTTP}/health"
readonly SYSTEM_INFO_ENDPOINT="http://127.0.0.1:${JELLYFIN_PORT_HTTP}/System/Info/Public"

AUTO_FIX=false
DIAG_ONLY=false
RUNTIME_MODE="unknown" # "systemd", "docker", "podman", "standalone"
CONTAINER_ID=""
ISSUES_FOUND=0

# -----------------------------------------------------------------------------
# Logging Helpers
# -----------------------------------------------------------------------------
log_header() {
    printf "\n${COLOR_CYAN}=== %s ===${COLOR_RESET}\n" "$1"
}

log_info() {
    printf "${COLOR_BLUE}[INFO]${COLOR_RESET} %s\n" "$1"
}

log_success() {
    printf "${COLOR_GREEN}[  OK  ]${COLOR_RESET} %s\n" "$1"
}

log_warn() {
    printf "${COLOR_YELLOW}[ WARN ]${COLOR_RESET} %s\n" "$1"
    ((ISSUES_FOUND++)) || true
}

log_error() {
    printf "${COLOR_RED}[ FAIL ]${COLOR_RESET} %s\n" "$1"
    ((ISSUES_FOUND++)) || true
}

# -----------------------------------------------------------------------------
# Pre-flight Checks
# -----------------------------------------------------------------------------
check_privileges() {
    if [[ "${EUID}" -ne 0 ]]; then
        printf "${COLOR_RED}Error: This diagnostic and repair script must be run as root (sudo).${COLOR_RESET}\n" >&2
        exit 1
    fi
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--fix)
                AUTO_FIX=true
                shift
                ;;
            -d|--diag|--dry-run)
                DIAG_ONLY=true
                shift
                ;;
            -h|--help)
                cat <<EOF
Usage: sudo $0 [OPTIONS]

Options:
  -f, --fix      Automatically execute remediation steps without prompt.
  -d, --diag     Run diagnostic checks only (read-only mode).
  -h, --help     Display this help menu and exit.
EOF
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Phase 1: Environment & Runtime Detection
# -----------------------------------------------------------------------------
detect_runtime() {
    log_header "Detecting Jellyfin Deployment Environment"

    # 1. Check Docker Containers
    if command -v docker &>/dev/null; then
        local c_id
        c_id=$(docker ps -a --filter "ancestor=jellyfin/jellyfin" --format "{{.ID}}" | head -n 1)
        if [[ -z "$c_id" ]]; then
            c_id=$(docker ps -a --filter "name=jellyfin" --format "{{.ID}}" | head -n 1)
        fi

        if [[ -n "$c_id" ]]; then
            RUNTIME_MODE="docker"
            CONTAINER_ID="$c_id"
            local status
            status=$(docker inspect --format '{{.State.Status}}' "$CONTAINER_ID" 2>/dev/null || echo "unknown")
            log_info "Found Docker container: ${CONTAINER_ID} (Status: ${status})"
            return 0
        fi
    fi

    # 2. Check Podman Containers
    if command -v podman &>/dev/null; then
        local p_id
        p_id=$(podman ps -a --filter "name=jellyfin" --format "{{.ID}}" | head -n 1)
        if [[ -n "$p_id" ]]; then
            RUNTIME_MODE="podman"
            CONTAINER_ID="$p_id"
            log_info "Found Podman container: ${CONTAINER_ID}"
            return 0
        fi
    fi

    # 3. Check Systemd Service
    if command -v systemctl &>/dev/null; then
        if systemctl list-unit-files | grep -q "jellyfin.service"; then
            RUNTIME_MODE="systemd"
            local is_active
            is_active=$(systemctl is-active jellyfin || true)
            log_info "Found native systemd service: jellyfin.service (State: ${is_active})"
            return 0
        fi
    fi

    # 4. Check Standalone Process
    if pgrep -f "jellyfin" &>/dev/null; then
        RUNTIME_MODE="standalone"
        log_info "Detected standalone running Jellyfin PID(s): $(pgrep -f "jellyfin" | tr '\n' ' ')"
        return 0
    fi

    log_warn "Could not automatically pinpoint an active Jellyfin runtime. Will run systemic inspection."
    RUNTIME_MODE="standalone"
}

# -----------------------------------------------------------------------------
# Phase 2: Host Resource, Storage & Inode Health
# -----------------------------------------------------------------------------
check_host_resources() {
    log_header "Inspecting Host Resources & Filesystem Integrity"

    local root_avail
    root_avail=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    if [[ "$root_avail" -gt 95 ]]; then
        log_error "Root filesystem space is critically low (${root_avail}% used). Database write locks likely failing."
    else
        log_success "Root disk utilization is healthy (${root_avail}% used)."
    fi

    local inode_avail
    inode_avail=$(df -i / | awk 'NR==2 {print $5}' | tr -d '%')
    if [[ "$inode_avail" -gt 95 ]]; then
        log_error "Root filesystem inode exhaustion (${inode_avail}% used). Transcoder cannot write temporary fragments."
    else
        log_success "Inode utilization is normal (${inode_avail}% used)."
    fi

    local free_ram_mb
    free_ram_mb=$(free -m | awk '/^Mem:/ {print $7}')
    if [[ "$free_ram_mb" -lt 150 ]]; then
        log_warn "Host has critically low available RAM (${free_ram_mb} MB free). OOM-killer may be freezing .NET runtime."
    else
        log_success "Available memory is sufficient (${free_ram_mb} MB available)."
    fi

    if dmesg -T 2>/dev/null | grep -iE "(out of memory|killed process.*jellyfin)" | tail -n 2 | grep -q .; then
        log_warn "Recent Out-Of-Memory (OOM) killer events detected in kernel ring buffer!"
    fi
}

# -----------------------------------------------------------------------------
# Phase 3: Port, Network Binding & Socket Inspection
# -----------------------------------------------------------------------------
check_network_and_ports() {
    log_header "Analyzing Network Sockets & Port Bindings"

    local port_busy=false
    local bound_pid=""
    local bound_proc=""

    if command -v ss &>/dev/null; then
        local ss_out
        ss_out=$(ss -tulpn "sport = :${JELLYFIN_PORT_HTTP}" 2>/dev/null || true)
        if echo "$ss_out" | grep -q ":${JELLYFIN_PORT_HTTP}"; then
            port_busy=true
            bound_pid=$(echo "$ss_out" | grep -o 'pid=[0-9]*' | cut -d= -f2 | head -n 1 || true)
        fi
    elif command -v lsof &>/dev/null; then
        bound_pid=$(lsof -t -i TCP:${JELLYFIN_PORT_HTTP} -s TCP:LISTEN 2>/dev/null | head -n 1 || true)
        if [[ -n "$bound_pid" ]]; then
            port_busy=true
        fi
    fi

    if [[ "$port_busy" == true ]]; then
        if [[ -n "$bound_pid" ]]; then
            bound_proc=$(ps -p "$bound_pid" -o comm= 2>/dev/null || echo "unknown")
            log_success "Port ${JELLYFIN_PORT_HTTP} is bound by PID ${bound_pid} (${bound_proc})."
        else
            log_success "Port ${JELLYFIN_PORT_HTTP} is actively listening."
        fi
    else
        log_error "Port ${JELLYFIN_PORT_HTTP} is NOT bound or listening! Jellyfin web server is offline or hung prior to socket bind."
    fi

    if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
        if ufw status | grep -E "(${JELLYFIN_PORT_HTTP}|Jellyfin)" &>/dev/null; then
            log_success "UFW firewall is active and has rules referencing Jellyfin/8096."
        else
            log_warn "UFW firewall is active, but port ${JELLYFIN_PORT_HTTP}/tcp is NOT explicitly permitted."
        fi
    fi
}

# -----------------------------------------------------------------------------
# Phase 4: Application Endpoint & HTTP Probe
# -----------------------------------------------------------------------------
probe_http_service() {
    log_header "Probing Internal Jellyfin HTTP Endpoints"

    if ! command -v curl &>/dev/null; then
        log_warn "'curl' binary missing. Skipping granular HTTP payload probing."
        return 0
    fi

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 6 "${HEALTH_ENDPOINT_LOCAL}" 2>/dev/null || echo "000")

    case "$http_code" in
        "200")
            log_success "Health probe endpoint returned HTTP 200 OK."
            ;;
        "302"|"301")
            log_success "Health probe returned redirection (HTTP ${http_code}), application layer is alive."
            ;;
        "000")
            log_error "Health probe timed out or connection refused (HTTP 000). The process may be in an asynchronous deadlock."
            ;;
        *)
            log_warn "Health probe returned unexpected status: HTTP ${http_code}"
            ;;
    esac

    local info_json
    info_json=$(curl -s --max-time 5 "${SYSTEM_INFO_ENDPOINT}" 2>/dev/null || true)
    if [[ -n "$info_json" ]] && echo "$info_json" | grep -q "ServerName"; then
        local s_name s_ver
        s_name=$(echo "$info_json" | grep -o '"ServerName":"[^"]*' | cut -d'"' -f4 || echo "Unknown")
        s_ver=$(echo "$info_json" | grep -o '"Version":"[^"]*' | cut -d'"' -f4 || echo "Unknown")
        log_success "Jellyfin API responding: Server Name: '${s_name}', Version: ${s_ver}"
    else
        log_error "Failed to query Jellyfin public system info API."
    fi
}

# -----------------------------------------------------------------------------
# Phase 5: Log & Error Analysis
# -----------------------------------------------------------------------------
inspect_logs() {
    log_header "Scanning Recent Logs for Critical Errors & Panics"

    if [[ "$RUNTIME_MODE" == "docker" ]]; then
        log_info "Fetching trailing 25 lines from Docker logs..."
        docker logs --tail 25 "$CONTAINER_ID" 2>&1 | sed 's/^/  [docker] /' || true
    elif [[ "$RUNTIME_MODE" == "systemd" ]]; then
        log_info "Fetching trailing 25 lines from journalctl..."
        journalctl -u jellyfin.service -n 25 --no-pager -o short-iso 2>/dev/null | sed 's/^/  [journal] /' || true
    elif [[ -d "/var/log/jellyfin" ]]; then
        local latest_log
        latest_log=$(find /var/log/jellyfin/ -type f -name "jellyfin*.log" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | awk '{print $2}')
        if [[ -n "$latest_log" && -f "$latest_log" ]]; then
            log_info "Latest log file: ${latest_log}"
            tail -n 25 "$latest_log" | sed 's/^/  [file] /'
        fi
    fi
}

# -----------------------------------------------------------------------------
# Phase 6: Automated Remediation Engine
# -----------------------------------------------------------------------------
apply_remediation() {
    log_header "Starting Self-Healing & Remediation Engine"

    if [[ "$DIAG_ONLY" == true ]]; then
        log_info "Dry-run mode selected. Skipping active repairs."
        return 0
    fi

    if [[ "$AUTO_FIX" == false ]]; then
        printf "\n${COLOR_YELLOW}Execute automated recovery and remediation steps now? [Y/n]: ${COLOR_RESET}"
        read -r choice
        if [[ "$choice" =~ ^[Nn]$ ]]; then
            log_info "Remediation aborted by operator."
            return 0
        fi
    fi

    # 1. Clean Transcoding Locks and Temp Buffers
    log_info "Cleaning dangling transcode chunks and temporary lock files..."
    local transcode_dirs=(
        "/var/cache/jellyfin/transcodes"
        "/tmp/jellyfin"
        "/var/lib/jellyfin/transcodes"
    )

    for dir in "${transcode_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            find "$dir" -type f -mmin +360 -delete 2>/dev/null || true
            log_success "Cleaned stale artifacts in ${dir}"
        fi
    done

    # 2. Kill Zombie or Hung .NET / FFmpeg processes
    log_info "Terminating orphaned ffmpeg transcode processes..."
    pkill -9 -f "ffmpeg.*jellyfin" 2>/dev/null || true

    # 3. Fix Ownership & Permissions (Native systemd)
    if [[ "$RUNTIME_MODE" == "systemd" ]]; then
        if id "jellyfin" &>/dev/null; then
            log_info "Restoring standard directory permissions for 'jellyfin:jellyfin'..."
            [[ -d "/var/lib/jellyfin" ]] && chown -R jellyfin:jellyfin /var/lib/jellyfin
            [[ -d "/var/cache/jellyfin" ]] && chown -R jellyfin:jellyfin /var/cache/jellyfin
            [[ -d "/etc/jellyfin" ]] && chown -R jellyfin:jellyfin /etc/jellyfin
            chmod -R 750 /var/lib/jellyfin /var/cache/jellyfin 2>/dev/null || true
            log_success "Directory permissions restored."
        fi
    fi

    # 4. Service Restart Workflow
    log_info "Executing graceful service cycle..."

    if [[ "$RUNTIME_MODE" == "docker" ]]; then
        log_info "Restarting Docker container ${CONTAINER_ID}..."
        docker restart -t 15 "$CONTAINER_ID" >/dev/null
        log_success "Docker container rebooted."
    elif [[ "$RUNTIME_MODE" == "podman" ]]; then
        log_info "Restarting Podman container ${CONTAINER_ID}..."
        podman restart -t 15 "$CONTAINER_ID" >/dev/null
        log_success "Podman container rebooted."
    elif [[ "$RUNTIME_MODE" == "systemd" ]]; then
        log_info "Restarting systemd service: jellyfin.service..."
        systemctl stop jellyfin.service 2>/dev/null || true
        sleep 2
        fuser -k "${JELLYFIN_PORT_HTTP}/tcp" 2>/dev/null || true
        systemctl start jellyfin.service
        log_success "Systemd service signaled to start."
    fi

    # 5. Post-Restart Verification Loop
    log_header "Verifying Post-Recovery Health"
    log_info "Waiting up to 30 seconds for ASP.NET Kestrel web server initialization..."

    local attempts=0
    local max_attempts=15
    local recovered=false

    while [[ $attempts -lt $max_attempts ]]; do
        ((attempts++))
        sleep 2

        local test_code
        test_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "${HEALTH_ENDPOINT_LOCAL}" 2>/dev/null || echo "000")

        if [[ "$test_code" == "200" || "$test_code" == "302" ]]; then
            recovered=true
            break
        fi
        printf "${COLOR_GRAY}.${COLOR_RESET}"
    done
    printf "\n"

    if [[ "$recovered" == true ]]; then
        log_success "Jellyfin is operational and responding to local requests!"
        local primary_ip
        primary_ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -n 1 || echo "localhost")
        printf "\n${COLOR_GREEN}====================================================${COLOR_RESET}\n"
        printf "${COLOR_GREEN}✓ Jellyfin has been successfully revived!${COLOR_RESET}\n"
        printf "Access Web UI at: ${COLOR_CYAN}http://%s:%s${COLOR_RESET}\n" "${primary_ip}" "${JELLYFIN_PORT_HTTP}"
        printf "${COLOR_GREEN}====================================================${COLOR_RESET}\n\n"
    else
        log_error "Jellyfin failed to respond within 30 seconds. Please inspect logs above."
    fi
}

main() {
    check_privileges
    parse_arguments "$@"

    printf "${COLOR_CYAN}╔═══════════════════════════════════════════════════════════════════════╗${COLOR_RESET}\n"
    printf "${COLOR_CYAN}║           Jellyfin Automated Server Diagnostic & Fix Toolkit          ║${COLOR_RESET}\n"
    printf "${COLOR_CYAN}╚═══════════════════════════════════════════════════════════════════════╝${COLOR_RESET}\n"

    detect_runtime
    check_host_resources
    check_network_and_ports
    probe_http_service
    inspect_logs
    apply_remediation
}

main "$@"
