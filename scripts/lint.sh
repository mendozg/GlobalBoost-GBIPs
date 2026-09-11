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
source "${LIB_DIR}/git.sh"

GBIP_CLI_SCRIPT_NAME="lint.sh"
GBIP_CLI_DESCRIPTION="Run GBIP linters."
gbip_cli_init "$@"

python_require_version

if python_exec -m ruff --version >/dev/null 2>&1; then
    python_ruff check "${GBIP_TOOLS_DIR}" "${GBIP_TESTS_DIR}"
else
    warning "ruff is not installed; skipping Python lint."
fi

if command_exists shellcheck; then
    shellcheck "${GBIP_SCRIPTS_DIR}"/*.sh "${GBIP_SCRIPTS_DIR}"/lib/*.sh
else
    warning "shellcheck is not installed; skipping shell lint."
fi

git_diff_check
success "Lint completed."
