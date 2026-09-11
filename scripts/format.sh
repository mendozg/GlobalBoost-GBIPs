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

GBIP_CLI_SCRIPT_NAME="format.sh"
GBIP_CLI_DESCRIPTION="Format GBIP sources."
gbip_cli_init "$@"

if [[ "${GBIP_CI:-0}" == "1" && "${GBIP_FORCE}" != "1" ]]; then
    gbip_die_usage "Formatting is disabled in CI unless --force is supplied."
fi

python_require_version

if python_exec -m black --version >/dev/null 2>&1; then
    python_black "${GBIP_TOOLS_DIR}" "${GBIP_TESTS_DIR}"
else
    warning "black is not installed; skipping Python formatting."
fi

if python_exec -m isort --version-number >/dev/null 2>&1; then
    python_isort "${GBIP_TOOLS_DIR}" "${GBIP_TESTS_DIR}"
else
    warning "isort is not installed; skipping import formatting."
fi

if command_exists shfmt; then
    find "${GBIP_SCRIPTS_DIR}" -type f -name "*.sh" -print0 | xargs -0 shfmt -w
else
    warning "shfmt is not installed; skipping shell formatting."
fi

success "Format completed."
