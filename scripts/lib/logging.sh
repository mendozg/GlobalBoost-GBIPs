#!/usr/bin/env bash
GBIP_LOG_LEVEL="${GBIP_LOG_LEVEL:-info}"
GBIP_VERBOSE="${GBIP_VERBOSE:-0}"
GBIP_QUIET="${GBIP_QUIET:-0}"
_log_allowed() {
    case "${GBIP_LOG_LEVEL}" in
        debug) return 0 ;;
        info) [[ "$1" != "debug" ]] ;;
        warning) [[ "$1" == "warning" || "$1" == "error" ]] ;;
        error) [[ "$1" == "error" ]] ;;
        *) return 0 ;;
    esac
}
_log() {
    local level="$1" label="$2" color="$3"; shift 3
    [[ "${GBIP_QUIET}" == "1" && "${level}" != "error" ]] && return 0
    _log_allowed "${level}" || return 0
    printf '%b[%s]%b %s\n' "${color}" "${label}" "${COLOR_RESET:-}" "$*"
}
info() { _log info INFO "${COLOR_BLUE:-}" "$@"; }
success() { _log info OK "${COLOR_GREEN:-}" "$@"; }
warning() { _log warning WARN "${COLOR_YELLOW:-}" "$@"; }
error() { _log error ERROR "${COLOR_RED:-}" "$@" >&2; }
debug() { _log debug DEBUG "${COLOR_MAGENTA:-}" "$@"; }
header() { printf '\n%b%s%b\n' "${COLOR_BOLD:-}" "$*" "${COLOR_RESET:-}"; }
fatal() { error "$@"; exit "${GBIP_EXIT_GENERAL:-1}"; }
step() { info "==> $*"; }
run_command() { debug "Running: $*"; "$@"; }
ci_group_start() { [[ "${GBIP_CI:-0}" == "1" ]] && printf '::group::%s\n' "$*"; }
ci_group_end() { [[ "${GBIP_CI:-0}" == "1" ]] && printf '::endgroup::\n'; }
ci_error() { [[ "${GBIP_CI:-0}" == "1" ]] && printf '::error::%s\n' "$*"; }
ci_warning() { [[ "${GBIP_CI:-0}" == "1" ]] && printf '::warning::%s\n' "$*"; }
