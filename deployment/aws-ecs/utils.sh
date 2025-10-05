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

# Platform detection
detect_os() {
    local ost
    ost=$(uname -s 2>/dev/null || echo "windows")
    case "$ost" in
        Linux*) echo "linux" ;;
        Darwin*) echo "mac" ;;
        CYGWIN*|MINGW*|MSYS*|Windows*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

# Compute directory hash (stable across platforms)
compute_hash_for_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo ""
        return 0
    fi
    if have_cmd md5sum; then
        find "$dir" -type f -print0 | sort -z | xargs -0 md5sum 2>/dev/null | md5sum | awk '{print $1}'
    else
        # Fallback: use sha1sum or powershell on Windows
        if have_cmd sha1sum; then
            find "$dir" -type f -print0 | sort -z | xargs -0 sha1sum 2>/dev/null | sha1sum | awk '{print $1}'
        else
            detect_os | grep -q windows && powershell -Command "Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue | Get-FileHash -Algorithm SHA1 | Sort-Object -Property Path | ForEach-Object { \$_.Hash } | Out-String" || echo "nohash"
        fi
    fi
}

# JSON parsing helper that prefers jq
parse_json() {
    local query="$1"; shift
    if have_cmd jq; then
        jq -r "$query" "$@"
    else
        # Not used heavily; prefer aws --query when possible
        cat "$@"
    fi
}

# Clean temp files list
TMP_FILES=()
register_tmp() { TMP_FILES+=("$1"); }
cleanup_tmp() {
    for f in "${TMP_FILES[@]}"; do
        [ -e "$f" ] && rm -f "$f"
    done
}

# Ensure cleanup on exit
trap 'cleanup_tmp' EXIT

# Create a temporary file in a cross-platform way and echo its path.
# Usage: create_tmp_file <template-or-suffix>
create_tmp_file() {
    local template="$1"
    local tmpf=""
    if have_cmd mktemp; then
        # POSIX mktemp: use template if provided
        if [ -n "$template" ]; then
            tmpf=$(mktemp -t "$template" 2>/dev/null || mktemp)
        else
            tmpf=$(mktemp 2>/dev/null || mktemp)
        fi
    else
        # Try PowerShell on Windows to create a temp file
        if have_cmd powershell; then
            # PowerShell returns a Windows path, ensure we use it as-is
            tmpf=$(powershell -NoProfile -Command "[System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), ([System.Guid]::NewGuid().ToString() + '-$template'))" 2>/dev/null | tr -d '\r')
            # Actually create the file
            powershell -NoProfile -Command "New-Item -Path \"$tmpf\" -ItemType File -Force" >/dev/null 2>&1 || true
        else
            # Last resort: create in current directory
            tmpf="./$template-$$.tmp"
            : > "$tmpf"
        fi
    fi
    # Register for cleanup
    register_tmp "$tmpf"
    printf '%s' "$tmpf"
}

# Run AWS CLI with MSYS_NO_PATHCONV when appropriate (prevents path mangling in Git Bash)
run_aws_cli() {
    # This function expects the full aws command as arguments
    local args=()
    local arg
    # Detect MSYS/Git Bash/Cygwin via uname once
    local UNAME_S
    UNAME_S=$(uname -s 2>/dev/null || echo "")
    local IS_MSYS=0
    if printf '%s' "$UNAME_S" | grep -qiE "msys|mingw|cygwin"; then
        IS_MSYS=1
    fi

    for arg in "$@"; do
        # If argument is file://something or fileb://something convert to Windows path when running under MSYS so aws.exe can read it
        case "$arg" in
            file://*|fileb://*)
                # extract prefix (file:// or fileb://) and the path
                local prefix
                prefix=${arg%%://*}
                prefix="$prefix://"
                local path
                path=${arg#${prefix}}
                if [ "$IS_MSYS" -eq 1 ]; then
                    if have_cmd cygpath; then
                        local winpath
                        winpath=$(cygpath -w "$path" 2>/dev/null || echo "$path")
                        args+=("${prefix}${winpath}")
                    elif have_cmd powershell; then
                        local winpath
                        winpath=$(powershell -NoProfile -Command "[System.IO.Path]::GetFullPath(\"$path\")" 2>/dev/null | tr -d '\r' || echo "$path")
                        args+=("${prefix}${winpath}")
                    else
                        args+=("$arg")
                    fi
                else
                    args+=("$arg")
                fi
                ;;
            *)
                    # If running under MSYS and the argument is a path that exists on the POSIX filesystem
                    # convert it to a Windows path so aws.exe can read/write it. This fixes cases like
                    # mktemp-created files under /tmp when invoking aws.exe from Git Bash.
                    if [ "$IS_MSYS" -eq 1 ]; then
                        if [ -e "$arg" ]; then
                            if have_cmd cygpath; then
                                local winpath
                                winpath=$(cygpath -w "$arg" 2>/dev/null || echo "$arg")
                                args+=("$winpath")
                            elif have_cmd powershell; then
                                local winpath
                                winpath=$(powershell -NoProfile -Command "[System.IO.Path]::GetFullPath(\"$arg\")" 2>/dev/null | tr -d '\r' || echo "$arg")
                                args+=("$winpath")
                            else
                                args+=("$arg")
                            fi
                        else
                            args+=("$arg")
                        fi
                    else
                        args+=("$arg")
                    fi
                    ;;
        esac
    done

    if [ "${AWS_CLI_WRAPPER_DEBUG:-0}" = "1" ]; then
        log_info "run_aws_cli: invoking aws with args: ${args[*]}"
    fi

    if [ "$IS_MSYS" -eq 1 ]; then
        MSYS_NO_PATHCONV=1 aws "${args[@]}"
    else
        aws "${args[@]}"
    fi
    return $?
}
