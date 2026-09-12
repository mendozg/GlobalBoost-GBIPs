#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

source "${LIB_DIR}/config.sh"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/cli.sh"
source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/filesystem.sh"
source "${LIB_DIR}/platform.sh"
source "${LIB_DIR}/python.sh"
source "${LIB_DIR}/validation.sh"

GBIP_CLI_SCRIPT_NAME="validate.sh"
GBIP_CLI_DESCRIPTION="Validate the GBIP repository."
gbip_cli_init "$@"

gbip_init_runtime
gbip_repository_check

if validate_repository; then
    success "GBIP repository validation passed."
else
    gbip_die_validation "GBIP repository validation failed."
fi
