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
GBIP_CLI_SCRIPT_NAME="clean.sh"
GBIP_CLI_DESCRIPTION="Clean generated GBIP files."
gbip_cli_init "$@"

if [[ "${GBIP_FORCE}" != "1" && "${GBIP_YES}" != "1" ]]; then
    require_confirmation "Remove generated build, distribution, cache, log, and temporary files?"
fi

fs_clean_build
fs_clean_distribution
fs_clean_runtime
success "Clean completed."
