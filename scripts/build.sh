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

GBIP_CLI_SCRIPT_NAME="build.sh"
GBIP_CLI_DESCRIPTION="Build the GBIP distribution tree."
gbip_cli_init "$@"

gbip_repository_check
python_require_version
fs_clean_build

for dir in gbips registry schemas docs templates; do
    src="${GBIP_ROOT_DIR}/${dir}"
    [[ -d "${src}" ]] && cp -a "${src}" "${GBIP_BUILD_DIR}/${dir}"
done

for file in README.md LICENSE CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md CHANGELOG.md ROADMAP.md VERSION; do
    [[ -f "${GBIP_ROOT_DIR}/${file}" ]] && cp -a "${GBIP_ROOT_DIR}/${file}" "${GBIP_BUILD_DIR}/${file}"
done

success "Build completed: ${GBIP_BUILD_DIR}"
