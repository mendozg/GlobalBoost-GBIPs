#!/usr/bin/env bash
#
# common.sh
#
# Shared utility functions for the GBIP shell framework.
#
# This module provides:
#   - Common error handling
#   - Command execution
#   - Dependency checks
#   - Dry-run support
#   - Confirmation prompts
#   - Path utilities
#   - Temporary file handling
#   - Exit helpers
#

[[ -n "${GBIP_COMMON_LOADED:-}" ]] && return
readonly GBIP_COMMON_LOADED=1

# ---------------------------------------------------------------------------
# Load framework modules
# ---------------------------------------------------------------------------

GBIP_COMMON_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${GBIP_COMMON_LIB_DIR}/config.sh"
source "${GBIP_COMMON_LIB_DIR}/logging.sh"

# ---------------------------------------------------------------------------
# Shell safety
# ---------------------------------------------------------------------------

# These options are intentionally NOT enabled globally here.
#
# Individual executable scripts should normally use:
#
#   set -Eeuo pipefail
#
# before sourcing this module.
#
# Library files must not change the caller's shell behavior unexpectedly.

# ---------------------------------------------------------------------------
# Error handling
# ---------------------------------------------------------------------------

gbip_error_handler() {
    local exit_code="$?"
    local line_number="${1:-unknown}"

    if [[ "${exit_code}" -ne 0 ]]; then
        error "Command failed at line ${line_number} with exit code ${exit_code}."
    fi

    return "${exit_code}"
}

gbip_die() {
    local message="$1"
    local exit_code="${2:-${GBIP_EXIT_GENERAL}}"

    error "${message}"
    exit "${exit_code}"
}

gbip_die_usage() {
    gbip_die "$1" "${GBIP_EXIT_USAGE}"
}

gbip_die_dependency() {
    gbip_die "$1" "${GBIP_EXIT_MISSING_DEPENDENCY}"
}

gbip_die_validation() {
    gbip_die "$1" "${GBIP_EXIT_VALIDATION}"
}

gbip_die_build() {
    gbip_die "$1" "${GBIP_EXIT_BUILD}"
}

gbip_die_release() {
    gbip_die "$1" "${GBIP_EXIT_RELEASE}"
}

# ---------------------------------------------------------------------------
# Command existence
# ---------------------------------------------------------------------------

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_command() {
    local command_name="$1"

    if ! command_exists "${command_name}"; then
        gbip_die_dependency \
            "Required command not found: ${command_name}"
    fi
}

require_commands() {
    local command_name

    for command_name in "$@"; do
        require_command "${command_name}"
    done
}

# ---------------------------------------------------------------------------
# Optional command checks
# ---------------------------------------------------------------------------

optional_command() {
    command_exists "$1"
}

check_optional_command() {
    local command_name="$1"

    if command_exists "${command_name}"; then
        debug "Optional dependency available: ${command_name}"
        return 0
    fi

    debug "Optional dependency not available: ${command_name}"
    return 1
}

# ---------------------------------------------------------------------------
# Dry-run support
# ---------------------------------------------------------------------------

is_dry_run() {
    [[ "${GBIP_DRY_RUN:-0}" -eq 1 ]]
}

run() {
    if [[ "$#" -eq 0 ]]; then
        error "run() requires a command."
        return 1
    fi

    debug "Executing: $*"

    if is_dry_run; then
        info "[dry-run] $*"
        return 0
    fi

    "$@"
}

run_shell() {
    if [[ "$#" -eq 0 ]]; then
        error "run_shell() requires a command string."
        return 1
    fi

    debug "Executing shell command: $*"

    if is_dry_run; then
        info "[dry-run] $*"
        return 0
    fi

    bash -c "$*"
}

# ---------------------------------------------------------------------------
# Command with logging
# ---------------------------------------------------------------------------

run_step() {
    local description="$1"
    shift

    info "${description}"

    if run "$@"; then
        success "${description}"
        return 0
    fi

    error "${description}"
    return 1
}

run_optional() {
    local description="$1"
    local command_name="$2"
    shift 2

    if ! command_exists "${command_name}"; then
        warning "Skipping ${description}: ${command_name} is not installed."
        return 0
    fi

    run_step "${description}" "${command_name}" "$@"
}

# ---------------------------------------------------------------------------
# User confirmation
# ---------------------------------------------------------------------------

confirm() {
    local prompt="${1:-Continue?}"

    if [[ "${GBIP_YES:-0}" -eq 1 ]]; then
        return 0
    fi

    if [[ ! -t 0 ]]; then
        warning "Non-interactive environment detected."
        warning "Use --yes to automatically confirm this operation."
        return 1
    fi

    printf "%s [y/N] " "${prompt}"

    local answer
    read -r answer

    case "${answer}" in
        y|Y|yes|YES|Yes)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

require_confirmation() {
    local prompt="$1"

    if confirm "${prompt}"; then
        return 0
    fi

    warning "Operation cancelled."
    return 1
}

# ---------------------------------------------------------------------------
# File and directory utilities
# ---------------------------------------------------------------------------

ensure_dir() {
    local directory="$1"

    if [[ -d "${directory}" ]]; then
        return 0
    fi

    debug "Creating directory: ${directory}"

    run mkdir -p "${directory}"
}

ensure_dirs() {
    local directory

    for directory in "$@"; do
        ensure_dir "${directory}" || return 1
    done
}

require_file() {
    local file="$1"

    if [[ ! -f "${file}" ]]; then
        error "Required file not found: ${file}"
        return 1
    fi
}

require_dir() {
    local directory="$1"

    if [[ ! -d "${directory}" ]]; then
        error "Required directory not found: ${directory}"
        return 1
    fi
}

file_exists() {
    [[ -f "$1" ]]
}

dir_exists() {
    [[ -d "$1" ]]
}

path_exists() {
    [[ -e "$1" ]]
}

# ---------------------------------------------------------------------------
# Safe removal
# ---------------------------------------------------------------------------

safe_remove() {
    local target="$1"

    if [[ -z "${target}" ]]; then
        error "Refusing to remove an empty path."
        return 1
    fi

    if [[ "${target}" == "/" ]]; then
        error "Refusing to remove root directory."
        return 1
    fi

    if [[ "${target}" == "${GBIP_ROOT_DIR}" ]]; then
        error "Refusing to remove GBIP repository root."
        return 1
    fi

    if [[ ! -e "${target}" ]]; then
        debug "Nothing to remove: ${target}"
        return 0
    fi

    if is_dry_run; then
        info "[dry-run] rm -rf ${target}"
        return 0
    fi

    rm -rf -- "${target}"
}

# ---------------------------------------------------------------------------
# Temporary files
# ---------------------------------------------------------------------------

GBIP_TEMP_FILES=()

gbip_mktemp() {
    local prefix="${1:-gbip}"

    local temp_file

    if command_exists mktemp; then
        temp_file="$(mktemp "${GBIP_TMP_DIR}/${prefix}.XXXXXX")"
    else
        temp_file="${GBIP_TMP_DIR}/${prefix}.$$.tmp"
        : > "${temp_file}"
    fi

    GBIP_TEMP_FILES+=("${temp_file}")

    printf '%s\n' "${temp_file}"
}

gbip_cleanup_temp() {
    local temp_file

    for temp_file in "${GBIP_TEMP_FILES[@]:-}"; do
        if [[ -n "${temp_file}" && -e "${temp_file}" ]]; then
            rm -f -- "${temp_file}"
        fi
    done

    GBIP_TEMP_FILES=()
}

# ---------------------------------------------------------------------------
# String utilities
# ---------------------------------------------------------------------------

trim() {
    local value="$*"

    # Remove leading whitespace.
    value="${value#"${value%%[![:space:]]*}"}"

    # Remove trailing whitespace.
    value="${value%"${value##*[![:space:]]}"}"

    printf '%s\n' "${value}"
}

is_empty() {
    [[ -z "${1:-}" ]]
}

is_not_empty() {
    [[ -n "${1:-}" ]]
}

# ---------------------------------------------------------------------------
# Boolean utilities
# ---------------------------------------------------------------------------

is_true() {
    case "${1:-}" in
        1|true|TRUE|True|yes|YES|Yes|on|ON|On)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_false() {
    ! is_true "${1:-}"
}

# ---------------------------------------------------------------------------
# Numeric utilities
# ---------------------------------------------------------------------------

is_integer() {
    [[ "${1:-}" =~ ^-?[0-9]+$ ]]
}

is_positive_integer() {
    [[ "${1:-}" =~ ^[1-9][0-9]*$ ]]
}

# ---------------------------------------------------------------------------
# Semantic version validation
# ---------------------------------------------------------------------------

is_semver() {
    local version="${1:-}"

    [[ "${version}" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]
}

require_semver() {
    local version="$1"

    if ! is_semver "${version}"; then
        error "Invalid semantic version: ${version}"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# GBIP identifier validation
# ---------------------------------------------------------------------------

is_gbip_id() {
    local id="${1:-}"

    [[ "${id}" =~ ^GBIP-[0-9]{4}$ ]]
}

require_gbip_id() {
    local id="$1"

    if ! is_gbip_id "${id}"; then
        error "Invalid GBIP identifier: ${id}"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Version helpers
# ---------------------------------------------------------------------------

refresh_version() {
    load_version
}

require_version_file() {
    require_file "${GBIP_VERSION_FILE}"
}

# ---------------------------------------------------------------------------
# Repository validation
# ---------------------------------------------------------------------------

gbip_repository_check() {
    if [[ ! -d "${GBIP_ROOT_DIR}" ]]; then
        error "GBIP repository root does not exist:"
        error "  ${GBIP_ROOT_DIR}"
        return 1
    fi

    if [[ ! -d "${GBIP_SCRIPTS_DIR}" ]]; then
        error "Scripts directory does not exist:"
        error "  ${GBIP_SCRIPTS_DIR}"
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# Runtime directory initialization
# ---------------------------------------------------------------------------

gbip_init_runtime() {
    gbip_repository_check || return 1

    ensure_dirs \
        "${GBIP_BUILD_DIR}" \
        "${GBIP_DIST_DIR}" \
        "${GBIP_CACHE_DIR}" \
        "${GBIP_LOG_DIR}" \
        "${GBIP_TMP_DIR}"
}

# ---------------------------------------------------------------------------
# Trap installation
# ---------------------------------------------------------------------------

gbip_install_cleanup_trap() {
    trap gbip_cleanup_temp EXIT
}

# ---------------------------------------------------------------------------
# Debugging
# ---------------------------------------------------------------------------

gbip_debug_environment() {
    debug "GBIP_ROOT_DIR=${GBIP_ROOT_DIR}"
    debug "GBIP_VERSION=${GBIP_VERSION}"
    debug "GBIP_SCRIPTS_DIR=${GBIP_SCRIPTS_DIR}"
    debug "GBIP_GBIPS_DIR=${GBIP_GBIPS_DIR}"
    debug "GBIP_REGISTRY_DIR=${GBIP_REGISTRY_DIR}"
    debug "GBIP_SCHEMAS_DIR=${GBIP_SCHEMAS_DIR}"
    debug "GBIP_TOOLS_DIR=${GBIP_TOOLS_DIR}"
    debug "GBIP_TESTS_DIR=${GBIP_TESTS_DIR}"
    debug "GBIP_BUILD_DIR=${GBIP_BUILD_DIR}"
    debug "GBIP_DIST_DIR=${GBIP_DIST_DIR}"
    debug "GBIP_DRY_RUN=${GBIP_DRY_RUN}"
    debug "GBIP_CI=${GBIP_CI}"
    debug "GBIP_QUIET=${GBIP_QUIET}"
    debug "GBIP_VERBOSE=${GBIP_VERBOSE}"
    debug "GBIP_DEBUG=${GBIP_DEBUG}"
}

# ---------------------------------------------------------------------------
# Script execution helper
# ---------------------------------------------------------------------------

gbip_script() {
    local script="$1"
    shift

    if [[ ! -f "${script}" ]]; then
        error "Script not found: ${script}"
        return 1
    fi

    if [[ ! -x "${script}" ]]; then
        debug "Script is not executable; invoking through bash: ${script}"
        run bash "${script}" "$@"
    else
        run "${script}" "$@"
    fi
}

# ---------------------------------------------------------------------------
# Exit status helpers
# ---------------------------------------------------------------------------

gbip_success() {
    success "$*"
    return "${GBIP_EXIT_SUCCESS}"
}

gbip_failure() {
    error "$*"
    return "${GBIP_EXIT_GENERAL}"
}

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

gbip_install_cleanup_trap