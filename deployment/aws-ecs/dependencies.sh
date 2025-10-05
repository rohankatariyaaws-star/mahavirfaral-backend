#!/usr/bin/env bash
# Dependency checks for the modules. Each module can call specific checks as needed.

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

check_common_deps() {
    log_info "Checking common dependencies: aws, docker..."
    local missing=0
    if ! have_cmd aws; then
        log_error "AWS CLI not found"
        missing=1
    fi
    if ! have_cmd docker; then
        log_error "Docker not found"
        missing=1
    fi
    if ! have_cmd mvn; then
        log_warn "Maven (mvn) not found. Backend build will fail without it."
    fi
    if [ $missing -ne 0 ]; then
        return 1
    fi
}

check_frontend_deps() {
    if ! have_cmd npm; then
        log_error "npm not found. Frontend builds require npm."
        return 1
    fi
}

check_zip_cmd() {
    if have_cmd zip; then
        return 0
    fi
    detect_os | grep -q windows && have_cmd powershell && return 0
    log_warn "zip not found. On Linux/Mac install zip for fallback zip packaging."
}
