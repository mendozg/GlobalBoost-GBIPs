#!/usr/bin/env bash
GBIP_CLI_SCRIPT_NAME="${GBIP_CLI_SCRIPT_NAME:-GBIP}"
GBIP_CLI_DESCRIPTION="${GBIP_CLI_DESCRIPTION:-GlobalBoost Improvement Proposal tooling}"
GBIP_CLI_REMAINING_ARGS=()
gbip_cli_usage() {
    cat <<EOF
Usage: ${GBIP_CLI_SCRIPT_NAME} [options] [arguments]

${GBIP_CLI_DESCRIPTION}

Options:
  -h, --help       Show help
  -V, --version    Show project version
  -v, --verbose    Enable verbose output
  -q, --quiet      Reduce output
  -d, --debug      Enable debug output
      --dry-run    Show commands without executing them
  -f, --force      Skip safety confirmations
  -y, --yes        Assume yes
      --ci         CI-friendly behavior
      --color      Enable colors
      --no-color   Disable colors
      --            End global options
EOF
}
gbip_cli_version() { printf '%s %s\n' "${GBIP_PROJECT_NAME}" "$(gbip_read_version)"; }
gbip_cli_parse() {
    GBIP_CLI_REMAINING_ARGS=()
    while (($#)); do
        case "$1" in
            -h|--help) GBIP_CLI_REQUEST_HELP=1 ;;
            -V|--version) GBIP_CLI_REQUEST_VERSION=1 ;;
            -v|--verbose) GBIP_VERBOSE=1; GBIP_LOG_LEVEL=debug ;;
            -q|--quiet) GBIP_QUIET=1 ;;
            -d|--debug) GBIP_DEBUG=1; GBIP_LOG_LEVEL=debug ;;
            --dry-run) GBIP_DRY_RUN=1 ;;
            -f|--force) GBIP_FORCE=1 ;;
            -y|--yes) GBIP_YES=1 ;;
            --ci) GBIP_CI=1; disable_colors ;;
            --color) enable_colors ;;
            --no-color) disable_colors ;;
            --) shift; GBIP_CLI_REMAINING_ARGS+=("$@"); break ;;
            -*) gbip_cli_unknown_option "$1" ;;
            *) GBIP_CLI_REMAINING_ARGS+=("$1") ;;
        esac
        shift
    done
}
gbip_cli_handle_standard_requests() {
    [[ "${GBIP_CLI_REQUEST_HELP:-0}" == "1" ]] && { gbip_cli_usage; exit 0; }
    [[ "${GBIP_CLI_REQUEST_VERSION:-0}" == "1" ]] && { gbip_cli_version; exit 0; }
}
gbip_cli_unknown_option() { gbip_die_usage "Unknown option: $1"; }
gbip_cli_require_no_arguments() { (($# == 0)) || gbip_die_usage "Unexpected argument: $1"; }
gbip_cli_init() { gbip_cli_parse "$@"; gbip_cli_handle_standard_requests; }
