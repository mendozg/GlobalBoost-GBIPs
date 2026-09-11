#!/usr/bin/env bash
#
# filesystem.sh
#
# Filesystem utilities for the GBIP shell framework.
#
# Provides:
#   - Directory creation
#   - Safe file operations
#   - Atomic writes
#   - Copy / move helpers
#   - Recursive cleanup
#   - Permission handling
#   - Temporary directories
#   - Build / distribution helpers
#

[[ -n "${GBIP_FILESYSTEM_LOADED:-}" ]] && return
readonly GBIP_FILESYSTEM_LOADED=1

# ---------------------------------------------------------------------------
# Load framework modules
# ---------------------------------------------------------------------------

GBIP_FILESYSTEM_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${GBIP_FILESYSTEM_LIB_DIR}/common.sh"

# ---------------------------------------------------------------------------
# Filesystem constants
# ---------------------------------------------------------------------------

readonly GBIP_FILE_MODE="${GBIP_FILE_MODE:-0644}"
readonly GBIP_EXECUTABLE_MODE="${GBIP_EXECUTABLE_MODE:-0755}"
readonly GBIP_DIRECTORY_MODE="${GBIP_DIRECTORY_MODE:-0755}"

# ---------------------------------------------------------------------------
# Path normalization
# ---------------------------------------------------------------------------

fs_abs_path() {
    local path="$1"

    if [[ -z "${path}" ]]; then
        return 1
    fi

    if [[ "${path}" = /* ]]; then
        printf '%s\n' "${path}"
        return 0
    fi

    (
        cd "$(dirname "${path}")" 2>/dev/null || exit 1
        printf '%s/%s\n' "$(pwd -P)" "$(basename "${path}")"
    )
}

# ---------------------------------------------------------------------------
# Directory operations
# ---------------------------------------------------------------------------

fs_mkdir() {
    local directory="$1"

    if [[ -z "${directory}" ]]; then
        error "fs_mkdir requires a directory."
        return 1
    fi

    if [[ -d "${directory}" ]]; then
        debug "Directory already exists: ${directory}"
        return 0
    fi

    if is_dry_run; then
        info "[dry-run] mkdir -p ${directory}"
        return 0
    fi

    mkdir -p -- "${directory}"
    chmod "${GBIP_DIRECTORY_MODE}" "${directory}" 2>/dev/null || true
}

fs_mkdir_many() {
    local directory

    for directory in "$@"; do
        fs_mkdir "${directory}" || return 1
    done
}

fs_require_dir() {
    local directory="$1"

    if [[ ! -d "${directory}" ]]; then
        error "Directory does not exist: ${directory}"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# File operations
# ---------------------------------------------------------------------------

fs_require_file() {
    local file="$1"

    if [[ ! -f "${file}" ]]; then
        error "File does not exist: ${file}"
        return 1
    fi
}

fs_touch() {
    local file="$1"

    if [[ -z "${file}" ]]; then
        error "fs_touch requires a file path."
        return 1
    fi

    fs_mkdir "$(dirname "${file}")" || return 1

    if is_dry_run; then
        info "[dry-run] touch ${file}"
        return 0
    fi

    touch -- "${file}"
    chmod "${GBIP_FILE_MODE}" "${file}" 2>/dev/null || true
}

fs_remove_file() {
    local file="$1"

    if [[ -z "${file}" ]]; then
        error "Refusing to remove an empty file path."
        return 1
    fi

    if [[ ! -e "${file}" ]]; then
        debug "File does not exist: ${file}"
        return 0
    fi

    if [[ ! -f "${file}" && ! -L "${file}" ]]; then
        error "Not a regular file or symlink: ${file}"
        return 1
    fi

    if is_dry_run; then
        info "[dry-run] rm -f ${file}"
        return 0
    fi

    rm -f -- "${file}"
}

# ---------------------------------------------------------------------------
# Safe recursive removal
# ---------------------------------------------------------------------------

fs_remove_dir() {
    local directory="$1"

    if [[ -z "${directory}" ]]; then
        error "Refusing to remove an empty directory path."
        return 1
    fi

    if [[ ! -d "${directory}" ]]; then
        debug "Directory does not exist: ${directory}"
        return 0
    fi

    # Never allow this helper to remove the repository root.
    local absolute_target
    absolute_target="$(fs_abs_path "${directory}")" || return 1

    if [[ "${absolute_target}" == "/" ]]; then
        error "Refusing to remove filesystem root."
        return 1
    fi

    if [[ "${absolute_target}" == "${GBIP_ROOT_DIR}" ]]; then
        error "Refusing to remove GBIP repository root."
        return 1
    fi

    if is_dry_run; then
        info "[dry-run] rm -rf ${absolute_target}"
        return 0
    fi

    rm -rf -- "${absolute_target}"
}

# ---------------------------------------------------------------------------
# Copy
# ---------------------------------------------------------------------------

fs_copy() {
    local source="$1"
    local destination="$2"

    fs_require_file "${source}" || return 1

    fs_mkdir "$(dirname "${destination}")" || return 1

    if is_dry_run; then
        info "[dry-run] cp ${source} ${destination}"
        return 0
    fi

    cp -f -- "${source}" "${destination}"
    chmod "${GBIP_FILE_MODE}" "${destination}" 2>/dev/null || true
}

fs_copy_dir() {
    local source="$1"
    local destination="$2"

    fs_require_dir "${source}" || return 1
    fs_mkdir "${destination}" || return 1

    if is_dry_run; then
        info "[dry-run] cp -R ${source}/. ${destination}/"
        return 0
    fi

    cp -R -- "${source}/." "${destination}/"
}

# ---------------------------------------------------------------------------
# Move
# ---------------------------------------------------------------------------

fs_move() {
    local source="$1"
    local destination="$2"

    if [[ ! -e "${source}" ]]; then
        error "Source does not exist: ${source}"
        return 1
    fi

    fs_mkdir "$(dirname "${destination}")" || return 1

    if is_dry_run; then
        info "[dry-run] mv ${source} ${destination}"
        return 0
    fi

    mv -f -- "${source}" "${destination}"
}

# ---------------------------------------------------------------------------
# Atomic file writes
# ---------------------------------------------------------------------------

fs_write_atomic() {
    local destination="$1"
    local content="$2"

    if [[ -z "${destination}" ]]; then
        error "fs_write_atomic requires a destination."
        return 1
    fi

    fs_mkdir "$(dirname "${destination}")" || return 1

    if is_dry_run; then
        info "[dry-run] write ${destination}"
        return 0
    fi

    local temporary_file

    temporary_file="$(gbip_mktemp "atomic")" || return 1

    if ! printf '%s\n' "${content}" > "${temporary_file}"; then
        rm -f -- "${temporary_file}"
        return 1
    fi

    chmod "${GBIP_FILE_MODE}" "${temporary_file}" 2>/dev/null || true

    if ! mv -f -- "${temporary_file}" "${destination}"; then
        rm -f -- "${temporary_file}"
        return 1
    fi

    debug "Atomically wrote: ${destination}"
}

fs_write_atomic_from_stdin() {
    local destination="$1"

    if [[ -z "${destination}" ]]; then
        error "fs_write_atomic_from_stdin requires a destination."
        return 1
    fi

    fs_mkdir "$(dirname "${destination}")" || return 1

    if is_dry_run; then
        info "[dry-run] write ${destination} from stdin"
        cat >/dev/null
        return 0
    fi

    local temporary_file

    temporary_file="$(gbip_mktemp "atomic")" || return 1

    if ! cat > "${temporary_file}"; then
        rm -f -- "${temporary_file}"
        return 1
    fi

    chmod "${GBIP_FILE_MODE}" "${temporary_file}" 2>/dev/null || true

    mv -f -- "${temporary_file}" "${destination}"
}

# ---------------------------------------------------------------------------
# File comparison
# ---------------------------------------------------------------------------

fs_files_equal() {
    local first="$1"
    local second="$2"

    fs_require_file "${first}" || return 1
    fs_require_file "${second}" || return 1

    cmp -s -- "${first}" "${second}"
}

# ---------------------------------------------------------------------------
# File checksum
# ---------------------------------------------------------------------------

fs_sha256() {
    local file="$1"

    fs_require_file "${file}" || return 1

    if command_exists sha256sum; then
        sha256sum "${file}" | awk '{print $1}'
        return 0
    fi

    if command_exists shasum; then
        shasum -a 256 "${file}" | awk '{print $1}'
        return 0
    fi

    if command_exists openssl; then
        openssl dgst -sha256 "${file}" | awk '{print $NF}'
        return 0
    fi

    error "No SHA-256 utility available."
    return 1
}

# ---------------------------------------------------------------------------
# Permissions
# ---------------------------------------------------------------------------

fs_make_executable() {
    local file="$1"

    fs_require_file "${file}" || return 1

    if is_dry_run; then
        info "[dry-run] chmod ${GBIP_EXECUTABLE_MODE} ${file}"
        return 0
    fi

    chmod "${GBIP_EXECUTABLE_MODE}" "${file}"
}

fs_make_readonly() {
    local file="$1"

    fs_require_file "${file}" || return 1

    if is_dry_run; then
        info "[dry-run] chmod a-w ${file}"
        return 0
    fi

    chmod a-w -- "${file}"
}

# ---------------------------------------------------------------------------
# Directory synchronization helpers
# ---------------------------------------------------------------------------

fs_sync_dir() {
    local source="$1"
    local destination="$2"

    fs_require_dir "${source}" || return 1
    fs_mkdir "${destination}" || return 1

    if command_exists rsync; then

        if is_dry_run; then
            info "[dry-run] rsync -a ${source}/ ${destination}/"
            return 0
        fi

        rsync -a -- "${source}/" "${destination}/"
        return $?
    fi

    # Portable fallback.
    fs_copy_dir "${source}" "${destination}"
}

# ---------------------------------------------------------------------------
# Empty directory check
# ---------------------------------------------------------------------------

fs_is_empty_dir() {
    local directory="$1"

    fs_require_dir "${directory}" || return 1

    [[ -z "$(find "${directory}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]
}

# ---------------------------------------------------------------------------
# File count
# ---------------------------------------------------------------------------

fs_count_files() {
    local directory="$1"

    fs_require_dir "${directory}" || return 1

    find "${directory}" \
        -type f \
        -not -path '*/.git/*' \
        -not -path '*/.venv/*' \
        | wc -l \
        | tr -d '[:space:]'
}

# ---------------------------------------------------------------------------
# Directory size
# ---------------------------------------------------------------------------

fs_directory_size() {
    local directory="$1"

    fs_require_dir "${directory}" || return 1

    if command_exists du; then
        du -sh "${directory}" 2>/dev/null | awk '{print $1}'
    else
        printf '%s\n' "unknown"
    fi
}

# ---------------------------------------------------------------------------
# Build directory helpers
# ---------------------------------------------------------------------------

fs_clean_build() {
    info "Cleaning build directory..."

    fs_remove_dir "${GBIP_BUILD_DIR}" || return 1
    fs_mkdir "${GBIP_BUILD_DIR}"
}

fs_clean_distribution() {
    info "Cleaning distribution directory..."

    fs_remove_dir "${GBIP_DIST_DIR}" || return 1
    fs_mkdir "${GBIP_DIST_DIR}"
}

fs_clean_runtime() {
    info "Cleaning runtime directories..."

    fs_remove_dir "${GBIP_BUILD_DIR}" || return 1
    fs_remove_dir "${GBIP_DIST_DIR}" || return 1
    fs_remove_dir "${GBIP_CACHE_DIR}" || return 1
    fs_remove_dir "${GBIP_LOG_DIR}" || return 1
    fs_remove_dir "${GBIP_TMP_DIR}" || return 1

    fs_mkdir_many \
        "${GBIP_BUILD_DIR}" \
        "${GBIP_DIST_DIR}" \
        "${GBIP_CACHE_DIR}" \
        "${GBIP_LOG_DIR}" \
        "${GBIP_TMP_DIR}"
}

# ---------------------------------------------------------------------------
# Repository filesystem initialization
# ---------------------------------------------------------------------------

fs_initialize_repository() {
    fs_mkdir_many \
        "${GBIP_GBIPS_DIR}" \
        "${GBIP_REGISTRY_DIR}" \
        "${GBIP_SCHEMAS_DIR}" \
        "${GBIP_TEMPLATES_DIR}" \
        "${GBIP_DOCS_DIR}" \
        "${GBIP_TOOLS_DIR}" \
        "${GBIP_TESTS_DIR}" \
        "${GBIP_BUILD_DIR}" \
        "${GBIP_DIST_DIR}" \
        "${GBIP_CACHE_DIR}" \
        "${GBIP_LOG_DIR}" \
        "${GBIP_TMP_DIR}"
}

# ---------------------------------------------------------------------------
# Protected path check
# ---------------------------------------------------------------------------

fs_is_protected_path() {
    local target="$1"

    local absolute_target
    absolute_target="$(fs_abs_path "${target}")" || return 1

    case "${absolute_target}" in
        "/"|"${GBIP_ROOT_DIR}")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

fs_require_safe_path() {
    local target="$1"

    if fs_is_protected_path "${target}"; then
        error "Protected path: ${target}"
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# Temporary directory
# ---------------------------------------------------------------------------

fs_mktemp_dir() {
    local prefix="${1:-gbip}"

    fs_mkdir "${GBIP_TMP_DIR}" || return 1

    local directory

    if command_exists mktemp; then
        directory="$(mktemp -d "${GBIP_TMP_DIR}/${prefix}.XXXXXX")"
    else
        directory="${GBIP_TMP_DIR}/${prefix}.$$"
        mkdir -p "${directory}"
    fi

    GBIP_TEMP_FILES+=("${directory}")

    printf '%s\n' "${directory}"
}

# ---------------------------------------------------------------------------
# File listing
# ---------------------------------------------------------------------------

fs_list_files() {
    local directory="$1"

    fs_require_dir "${directory}" || return 1

    find "${directory}" \
        -type f \
        -not -path '*/.git/*' \
        -not -path '*/.venv/*' \
        -print
}

# ---------------------------------------------------------------------------
# Git-clean style temporary artifact detection
# ---------------------------------------------------------------------------

fs_is_generated_artifact() {
    local path="$1"

    case "${path}" in
        "${GBIP_BUILD_DIR}"/*)
            return 0
            ;;
        "${GBIP_DIST_DIR}"/*)
            return 0
            ;;
        "${GBIP_CACHE_DIR}"/*)
            return 0
            ;;
        "${GBIP_LOG_DIR}"/*)
            return 0
            ;;
        "${GBIP_TMP_DIR}"/*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Framework initialization
# ---------------------------------------------------------------------------

fs_initialize_repository