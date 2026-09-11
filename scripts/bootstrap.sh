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
source "${LIB_DIR}/python.sh"

GBIP_CLI_SCRIPT_NAME="bootstrap.sh"
GBIP_CLI_DESCRIPTION="Initialize the GBIP development environment."
gbip_cli_init "$@"

gbip_repository_check
gbip_init_runtime
fs_initialize_repository
python_require_version
python_ensure_venv

[[ -f "${GBIP_REQUIREMENTS_FILE}" ]] && python_install_requirements "${GBIP_REQUIREMENTS_FILE}"
[[ -f "${GBIP_DEV_REQUIREMENTS_FILE}" ]] && python_install_requirements "${GBIP_DEV_REQUIREMENTS_FILE}"

[[ -d "${GBIP_GITHOOKS_DIR}" ]] && find "${GBIP_GITHOOKS_DIR}" -type f -exec chmod +x {} \;
success "GBIP bootstrap complete."
