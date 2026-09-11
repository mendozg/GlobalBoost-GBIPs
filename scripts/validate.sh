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

GBIP_CLI_SCRIPT_NAME="validate.sh"
GBIP_CLI_DESCRIPTION="Validate the GBIP repository."
gbip_cli_init "$@"

gbip_repository_check
python_require_version
version="$(gbip_require_version)"
info "Version: ${version}"

if [[ -d "${GBIP_SCHEMAS_DIR}" ]]; then
    while IFS= read -r -d "" file; do
        python_validate_json "${file}" || gbip_die_validation "Invalid JSON schema: ${file}"
    done < <(find "${GBIP_SCHEMAS_DIR}" -type f -name "*.json" -print0)
fi

success "Basic repository validation passed."
