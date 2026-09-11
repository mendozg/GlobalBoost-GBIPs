#!/usr/bin/env bash
#
# cli.sh
#
# Common command-line interface framework for GBIP shell scripts.
#
# Global options:
#   --help
#   --version
#   --verbose
#   --quiet
#   --debug
#   --dry-run
#   --force
#   --yes
#   --ci
#   --color
#   --no-color
#
# This module is intended to be sourced by executable GBIP scripts.
#

[[ -n "${GBIP_CLI_LOADED:-}" ]] && return
readonly GBIP_CLI_LOADED=1

# ---------------------------------------------------------------------------
# Load framework modules
# ---------------------------------------------------------------------------

GBIP_CLI_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${GBIP_CLI_LIB_DIR}/common.sh"

# ---------------------------------------------------------------------------
# CLI state
# ---------------------------------------------------------------------------

GBIP_CLI_SCRIPT_NAME="${GBIP_CLI_SCRIPT_NAME:-$(basename "${0}")}"
GBIP_CLI_DESCRIPTION="${GBIP_CLI_DESCRIPTION:-GBIP repository utility}"

GBIP_CLI_SHOW_HELP=0
GBIP_CLI_SHOW_VERSION=0

GBIP_CLI_REMAINING_ARGS=()

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

gbip_cli_usage() {
    local script_name="${GBIP_CLI_SCRIPT_NAME}"
    local description="${GBIP_CLI_DESCRIPTION}"

    cat <<EOF
${GBIP_PROJECT_NAME} — ${description}

Usage:
  ${script_name} [OPTIONS] [ARGUMENTS]

Global options:
  -h, --help          Show this help message
  -V, --version       Show GBIP version
  -v, --verbose       Enable verbose output
  -q, --quiet         Suppress informational output
  -d, --debug         Enable debug output
      --dry-run       Show what would be executed without changing files
  -f, --force         Force operations where supported
  -y, --yes           Assume yes for confirmation prompts
      --ci            Enable CI/GitHub Actions mode
      --color         Force colored output
      --no-color      Disable colored output

Environment:
  GBIP_ROOT_DIR       Override repository root
  GBIP_CI             Enable CI mode
  GBIP_DRY_RUN        Enable dry-run mode
  GBIP_FORCE          Enable force mode
  GBIP_YES            Automatically confirm prompts
  GBIP_VERBOSE        Enable verbose output
  GBIP_DEBUG          Enable debug output
  NO_COLOR            Disable color output
  FORCE_COLOR         Force color output

Examples:
  ${script_name} --help
  ${script_name} --verbose
  ${script_name} --dry-run
  ${script_name} --ci
  ${script_name} --force --yes

EOF
}

# ---------------------------------------------------------------------------
# Version output
# ---------------------------------------------------------------------------

gbip_cli_version() {
    printf '%s %s\n' \
        "${GBIP_PROJECT_FULL_NAME}" \
        "${GBIP_VERSION}"
}

# ---------------------------------------------------------------------------
# Option handlers
# ---------------------------------------------------------------------------

gbip_cli_enable_verbose() {
    set_verbose
    GBIP_VERBOSE=1
}

gbip_cli_enable_quiet() {
    set_quiet
    GBIP_QUIET=1
}

gbip_cli_enable_debug() {
    set_debug
    GBIP_DEBUG=1
}

gbip_cli_enable_dry_run() {
    GBIP_DRY_RUN=1
}

gbip_cli_enable_force() {
    GBIP_FORCE=1
}

gbip_cli_enable_yes() {
    GBIP_YES=1
}

gbip_cli_enable_ci() {
    GBIP_CI=1
    set_ci

    # CI output should normally be deterministic and free of ANSI
    # escape sequences.
    disable_colors
}

gbip_cli_enable_color() {
    GBIP_COLOR_MODE="always"
    enable_colors
}

gbip_cli_disable_color() {
    GBIP_COLOR_MODE="never"
    disable_colors
}

# ---------------------------------------------------------------------------
# Global argument parser
# ---------------------------------------------------------------------------

gbip_cli_parse() {
    GBIP_CLI_REMAINING_ARGS=()

    while [[ "$#" -gt 0 ]]; do
        case "$1" in

            # ---------------------------------------------------------------
            # Help / version
            # ---------------------------------------------------------------

            -h|--help)
                GBIP_CLI_SHOW_HELP=1
                shift
                ;;

            -V|--version)
                GBIP_CLI_SHOW_VERSION=1
                shift
                ;;

            # ---------------------------------------------------------------
            # Logging
            # ---------------------------------------------------------------

            -v|--verbose)
                gbip_cli_enable_verbose
                shift
                ;;

            -q|--quiet)
                gbip_cli_enable_quiet
                shift
                ;;

            -d|--debug)
                gbip_cli_enable_debug
                shift
                ;;

            # ---------------------------------------------------------------
            # Execution behavior
            # ---------------------------------------------------------------

            --dry-run)
                gbip_cli_enable_dry_run
                shift
                ;;

            -f|--force)
                gbip_cli_enable_force
                shift
                ;;

            -y|--yes)
                gbip_cli_enable_yes
                shift
                ;;

            # ---------------------------------------------------------------
            # CI
            # ---------------------------------------------------------------

            --ci)
                gbip_cli_enable_ci
                shift
                ;;

            # ---------------------------------------------------------------
            # Color
            # ---------------------------------------------------------------

            --color)
                gbip_cli_enable_color
                shift
                ;;

            --no-color)
                gbip_cli_disable_color
                shift
                ;;

            # ---------------------------------------------------------------
            # End of global options
            # ---------------------------------------------------------------

            --)
                shift

                while [[ "$#" -gt 0 ]]; do
                    GBIP_CLI_REMAINING_ARGS+=("$1")
                    shift
                done

                break
                ;;

            # ---------------------------------------------------------------
            # Unknown option
            #
            # Script-specific parsers can receive unknown options from
            # GBIP_CLI_REMAINING_ARGS.
            # ---------------------------------------------------------------

            -*)
                GBIP_CLI_REMAINING_ARGS+=("$1")
                shift
                ;;

            # ---------------------------------------------------------------
            # Positional argument
            # ---------------------------------------------------------------

            *)
                GBIP_CLI_REMAINING_ARGS+=("$1")
                shift
                ;;

        esac
    done

    export GBIP_VERBOSE
    export GBIP_QUIET
    export GBIP_DEBUG
    export GBIP_DRY_RUN
    export GBIP_FORCE
    export GBIP_YES
    export GBIP_CI
}

# ---------------------------------------------------------------------------
# Process help/version requests
# ---------------------------------------------------------------------------

gbip_cli_handle_standard_requests() {

    if [[ "${GBIP_CLI_SHOW_VERSION}" -eq 1 ]]; then
        gbip_cli_version
        return 0
    fi

    if [[ "${GBIP_CLI_SHOW_HELP}" -eq 1 ]]; then
        gbip_cli_usage
        return 0
    fi

    return 2
}

# ---------------------------------------------------------------------------
# Remaining argument access
# ---------------------------------------------------------------------------

gbip_cli_remaining_count() {
    printf '%s\n' "${#GBIP_CLI_REMAINING_ARGS[@]}"
}

gbip_cli_remaining() {
    printf '%s\n' "${GBIP_CLI_REMAINING_ARGS[@]}"
}

gbip_cli_get() {
    local index="$1"

    if [[ "${index}" -lt 0 ||
          "${index}" -ge "${#GBIP_CLI_REMAINING_ARGS[@]}" ]]; then
        return 1
    fi

    printf '%s\n' "${GBIP_CLI_REMAINING_ARGS[${index}]}"
}

# ---------------------------------------------------------------------------
# Script-specific option parser helpers
# ---------------------------------------------------------------------------

gbip_cli_require_argument() {
    local option="$1"
    local value="${2:-}"

    if [[ -z "${value}" ]]; then
        error "Option ${option} requires an argument."
        return "${GBIP_EXIT_USAGE}"
    fi

    return 0
}

gbip_cli_unknown_option() {
    local option="$1"

    error "Unknown option: ${option}"
    error "Use --help for usage information."

    return "${GBIP_EXIT_USAGE}"
}

# ---------------------------------------------------------------------------
# Positional argument helpers
# ---------------------------------------------------------------------------

gbip_cli_require_no_arguments() {
    if [[ "${#GBIP_CLI_REMAINING_ARGS[@]}" -ne 0 ]]; then
        error "Unexpected argument(s): ${GBIP_CLI_REMAINING_ARGS[*]}"
        error "Use --help for usage information."
        return "${GBIP_EXIT_USAGE}"
    fi

    return 0
}

gbip_cli_require_one_argument() {
    if [[ "${#GBIP_CLI_REMAINING_ARGS[@]}" -ne 1 ]]; then
        error "Exactly one argument is required."
        error "Use --help for usage information."
        return "${GBIP_EXIT_USAGE}"
    fi

    return 0
}

gbip_cli_require_min_arguments() {
    local minimum="$1"

    if [[ "${#GBIP_CLI_REMAINING_ARGS[@]}" -lt "${minimum}" ]]; then
        error "At least ${minimum} argument(s) required."
        error "Use --help for usage information."
        return "${GBIP_EXIT_USAGE}"
    fi

    return 0
}

# ---------------------------------------------------------------------------
# Common command-line summary
# ---------------------------------------------------------------------------

gbip_cli_debug() {
    debug "CLI script: ${GBIP_CLI_SCRIPT_NAME}"
    debug "CLI description: ${GBIP_CLI_DESCRIPTION}"
    debug "Version: ${GBIP_VERSION}"
    debug "Verbose: ${GBIP_VERBOSE}"
    debug "Quiet: ${GBIP_QUIET}"
    debug "Debug: ${GBIP_DEBUG}"
    debug "Dry run: ${GBIP_DRY_RUN}"
    debug "Force: ${GBIP_FORCE}"
    debug "Yes: ${GBIP_YES}"
    debug "CI: ${GBIP_CI}"
    debug "Color mode: ${GBIP_COLOR_MODE}"
    debug "Remaining arguments: ${GBIP_CLI_REMAINING_ARGS[*]:-none}"
}

# ---------------------------------------------------------------------------
# CLI initialization
# ---------------------------------------------------------------------------

gbip_cli_init() {
    gbip_cli_parse "$@"
    gbip_cli_debug
}