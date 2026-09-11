#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

source "${LIB_DIR}/config.sh"
source "${LIB_DIR}/colors.sh"
source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/cli.sh"
source "${LIB_DIR}/filesystem.sh"
source "${LIB_DIR}/platform.sh"
GBIP_CLI_SCRIPT_NAME="version.sh"
GBIP_CLI_DESCRIPTION="Display the GBIP project version."
gbip_cli_init "$@"

gbip_cli_require_no_arguments "${GBIP_CLI_REMAINING_ARGS[@]}"
gbip_require_version
