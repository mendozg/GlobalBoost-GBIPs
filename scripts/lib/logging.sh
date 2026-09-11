#!/usr/bin/env bash
#
# logging.sh
#
# Standard logging functions for the GBIP shell framework.
#

# Prevent multiple inclusion
[[ -n "${GBIP_LOGGING_LOADED:-}" ]] && return
readonly GBIP_LOGGING_LOADED=1

###############################################################################
# Load Colors
###############################################################################

SCRIPT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=colors.sh
source "${SCRIPT_LIB_DIR}/colors.sh"

###############################################################################
# Logging Configuration
###############################################################################

GBIP_LOG_LEVEL="${GBIP_LOG_LEVEL:-info}"

GBIP_QUIET="${GBIP_QUIET:-0}"

GBIP_VERBOSE="${GBIP_VERBOSE:-0}"

GBIP_DEBUG="${GBIP_DEBUG:-0}"

GBIP_CI="${GBIP_CI:-0}"

GBIP_LOG_TIMESTAMP="${GBIP_LOG_TIMESTAMP:-0}"

###############################################################################
# Semantic Colors
###############################################################################

readonly COLOR_INFO="${BLUE}"
readonly COLOR_SUCCESS="${GREEN}"
readonly COLOR_WARNING="${YELLOW}"
readonly COLOR_ERROR="${RED}"
readonly COLOR_DEBUG="${MAGENTA}"
readonly COLOR_HEADER="${CYAN}"

###############################################################################
# Internal Helpers
###############################################################################

_timestamp() {

    if [[ "${GBIP_LOG_TIMESTAMP}" -eq 1 ]]; then
        date -u +"%Y-%m-%dT%H:%M:%SZ"
    fi

}

_log_prefix() {

    local timestamp

    timestamp="$(_timestamp)"

    if [[ -n "${timestamp}" ]]; then
        printf "[%s] " "${timestamp}"
    fi

}

###############################################################################
# Logging Functions
###############################################################################

info() {

    [[ "${GBIP_QUIET}" -eq 1 ]] && return 0

    printf "%b[INFO]%b %s%s\n" \
        "${COLOR_INFO}" \
        "${RESET}" \
        "$(_log_prefix)" \
        "$*"
}

success() {

    [[ "${GBIP_QUIET}" -eq 1 ]] && return 0

    printf "%b[SUCCESS]%b %s%s\n" \
        "${COLOR_SUCCESS}" \
        "${RESET}" \
        "$(_log_prefix)" \
        "$*"
}

warning() {

    [[ "${GBIP_QUIET}" -eq 1 ]] && return 0

    printf "%b[WARNING]%b %s%s\n" \
        "${COLOR_WARNING}" \
        "${RESET}" \
        "$(_log_prefix)" \
        "$*" >&2
}

error() {

    printf "%b[ERROR]%b %s%s\n" \
        "${COLOR_ERROR}" \
        "${RESET}" \
        "$(_log_prefix)" \
        "$*" >&2
}

debug() {

    [[ "${GBIP_DEBUG}" -eq 1 ]] || return 0

    printf "%b[DEBUG]%b %s%s\n" \
        "${COLOR_DEBUG}" \
        "${RESET}" \
        "$(_log_prefix)" \
        "$*"
}

header() {

    [[ "${GBIP_QUIET}" -eq 1 ]] && return 0

    printf "\n%b%s%b\n" \
        "${COLOR_HEADER}${BOLD}" \
        "$*" \
        "${RESET}"
}

fatal() {

    error "$*"
    exit 1

}

###############################################################################
# CI Logging
###############################################################################

ci_group_start() {

    local title="$1"

    if [[ "${GBIP_CI}" -eq 1 ]]; then
        printf "::group::%s\n" "${title}"
    else
        header "${title}"
    fi

}

ci_group_end() {

    if [[ "${GBIP_CI}" -eq 1 ]]; then
        printf "::endgroup::\n"
    fi

}

ci_error() {

    local message="$1"

    if [[ "${GBIP_CI}" -eq 1 ]]; then
        printf "::error::%s\n" "${message}"
    fi

    error "${message}"

}

ci_warning() {

    local message="$1"

    if [[ "${GBIP_CI}" -eq 1 ]]; then
        printf "::warning::%s\n" "${message}"
    fi

    warning "${message}"

}

###############################################################################
# Logging Configuration
###############################################################################

set_quiet() {

    GBIP_QUIET=1

}

set_verbose() {

    GBIP_VERBOSE=1
    GBIP_LOG_LEVEL="verbose"

}

set_debug() {

    GBIP_DEBUG=1
    GBIP_VERBOSE=1
    GBIP_LOG_LEVEL="debug"

}

set_ci() {

    GBIP_CI=1
    GBIP_LOG_TIMESTAMP=1

}

set_log_level() {

    case "$1" in

        quiet)
            GBIP_LOG_LEVEL="quiet"
            GBIP_QUIET=1
            ;;

        info)
            GBIP_LOG_LEVEL="info"
            ;;

        verbose)
            GBIP_LOG_LEVEL="verbose"
            GBIP_VERBOSE=1
            ;;

        debug)
            GBIP_LOG_LEVEL="debug"
            GBIP_VERBOSE=1
            GBIP_DEBUG=1
            ;;

        *)
            error "Unknown log level: $1"
            return 1
            ;;

    esac

}

###############################################################################
# Progress Helpers
###############################################################################

step() {

    local number="$1"
    local total="$2"
    local description="$3"

    [[ "${GBIP_QUIET}" -eq 1 ]] && return 0

    printf "%b[%s/%s]%b %s\n" \
        "${COLOR_INFO}" \
        "${number}" \
        "${total}" \
        "${RESET}" \
        "${description}"

}

###############################################################################
# Command Execution
###############################################################################

run_command() {

    debug "Executing: $*"

    "$@"

}

###############################################################################
# Completion
###############################################################################

log_success() {

    success "$*"

}

log_failure() {

    error "$*"

}