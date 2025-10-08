#!/usr/bin/env bash
# Utility helpers: logging, OS detection, retries, JSON helpers

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

log() {
    local level="$1"; shift
    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "[$ts] [$level] $*"
}

log_info() { log "INFO" "$*"; }
log_warn() { log "WARN" "$*"; }
log_error() { log "ERROR" "$*"; }

# Safe run wrapper honoring dry-run
safe_run() {
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY-RUN: $*"
    else
        eval "$@"
    fi
}

# Simple retry helper
retry() {
    local tries=${1:-$RETRY_COUNT}
    local wait_sec=${2:-$RETRY_SLEEP}
    shift 2 || true
    local cmd="$*"
    local i=0
    until $cmd; do
        i=$((i+1))
        if [ $i -ge $tries ]; then
            log_error "Command failed after $i attempts: $cmd"
            return 1
        fi
        log_warn "Attempt $i/$tries failed. Retrying in $wait_sec seconds..."
        sleep $wait_sec
    done
}

# Check if program exists
have_cmd() {
    command -v "$1" &> /dev/null
}

# Run AWS CLI with MSYS_NO_PATHCONV when appropriate (prevents path mangling in Git Bash)
run_aws_cli() {
    local args=()
    local arg
    local UNAME_S
    UNAME_S=$(uname -s 2>/dev/null || echo "")
    local IS_MSYS=0
    if printf '%s' "$UNAME_S" | grep -qiE "msys|mingw|cygwin"; then
        IS_MSYS=1
    fi

    for arg in "$@"; do
        args+=("$arg")
    done

    if [ "$IS_MSYS" -eq 1 ]; then
        MSYS_NO_PATHCONV=1 aws "${args[@]}"
    else
        aws "${args[@]}"
    fi
    return $?
}