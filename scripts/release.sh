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
source "${LIB_DIR}/git.sh"
source "${LIB_DIR}/release.sh"

GBIP_CLI_SCRIPT_NAME="release.sh"
GBIP_CLI_DESCRIPTION="Build and verify a GBIP release archive."
gbip_cli_init "$@"

version="$(gbip_read_version)"
if [[ "${#GBIP_CLI_REMAINING_ARGS[@]}" -gt 0 ]]; then
    version="${GBIP_CLI_REMAINING_ARGS[0]}"
fi
require_semver "${version}"
GBIP_RELEASE_VERSION="${version}"

release_build
release_verify
release_summary
success "Release build completed."
