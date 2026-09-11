#!/usr/bin/env bash
GBIP_DRY_RUN="${GBIP_DRY_RUN:-0}"
GBIP_FORCE="${GBIP_FORCE:-0}"
GBIP_YES="${GBIP_YES:-0}"
gbip_die() { error "$*"; exit "${GBIP_EXIT_GENERAL:-1}"; }
gbip_die_usage() { error "$*"; exit "${GBIP_EXIT_USAGE:-2}"; }
gbip_die_dependency() { error "$*"; exit "${GBIP_EXIT_DEPENDENCY:-3}"; }
gbip_die_validation() { error "$*"; exit "${GBIP_EXIT_VALIDATION:-4}"; }
gbip_die_build() { error "$*"; exit "${GBIP_EXIT_BUILD:-5}"; }
gbip_die_release() { error "$*"; exit "${GBIP_EXIT_RELEASE:-6}"; }
command_exists() { command -v "$1" >/dev/null 2>&1; }
require_command() { command_exists "$1" || gbip_die_dependency "Required command not found: $1"; }
require_commands() { local c; for c in "$@"; do require_command "$c"; done; }
is_dry_run() { [[ "${GBIP_DRY_RUN}" == "1" ]]; }
run() { debug "Running: $*"; if is_dry_run; then info "[dry-run] $*"; return 0; fi; "$@"; }
ensure_dir() { mkdir -p "$1"; }
ensure_dirs() { local d; for d in "$@"; do ensure_dir "$d"; done; }
require_file() { [[ -f "$1" ]] || gbip_die "Required file not found: $1"; }
require_dir() { [[ -d "$1" ]] || gbip_die "Required directory not found: $1"; }
safe_remove() {
    local target="$1"
    [[ -z "${target}" || "${target}" == "/" || "${target}" == "${GBIP_ROOT_DIR}" ]] && gbip_die "Refusing unsafe removal: ${target}"
    rm -rf -- "${target}"
}
gbip_mktemp() { mktemp "${TMPDIR:-/tmp}/gbip.XXXXXX"; }
trim() { local v="$*"; v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"; printf '%s' "$v"; }
is_semver() { [[ "${1:-}" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; }
require_semver() { is_semver "$1" || gbip_die_usage "Invalid semantic version: $1"; }
is_gbip_id() { [[ "${1:-}" =~ ^GBIP-[0-9]{4}$ ]]; }
require_gbip_id() { is_gbip_id "$1" || gbip_die_usage "Invalid GBIP identifier: $1"; }
gbip_read_version() { require_file "${GBIP_VERSION_FILE}"; tr -d '[:space:]' < "${GBIP_VERSION_FILE}"; }
gbip_require_version() { local v; v="$(gbip_read_version)"; require_semver "$v"; printf '%s\n' "$v"; }
gbip_repository_check() { [[ -d "${GBIP_ROOT_DIR}" ]] || exit "${GBIP_EXIT_GENERAL:-1}"; }
gbip_init_runtime() { ensure_dirs "${GBIP_BUILD_DIR}" "${GBIP_DIST_DIR}" "${GBIP_CACHE_DIR}" "${GBIP_LOG_DIR}" "${GBIP_TMP_DIR}"; }
confirm() { [[ "${GBIP_YES}" == "1" || "${GBIP_FORCE}" == "1" ]] && return 0; local a; read -r -p "${1:-Continue?} [y/N] " a; [[ "$a" =~ ^[Yy]([Ee][Ss])?$ ]]; }
require_confirmation() { confirm "$1" || gbip_die_usage "Operation cancelled."; }
gbip_success() { success "$@"; }
