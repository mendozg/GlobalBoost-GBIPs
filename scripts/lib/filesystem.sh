#!/usr/bin/env bash
fs_abs_path() { local p="$1"; [[ "$p" = /* ]] && printf '%s\n' "$p" || printf '%s\n' "$(cd "$(dirname "$p")" 2>/dev/null && pwd)/$(basename "$p")"; }
fs_mkdir() { mkdir -p -- "$1"; }
fs_require_dir() { [[ -d "$1" ]] || gbip_die "Directory not found: $1"; }
fs_require_file() { [[ -f "$1" ]] || gbip_die "File not found: $1"; }
fs_touch() { mkdir -p "$(dirname "$1")"; touch "$1"; }
fs_remove_file() { [[ -f "$1" ]] && rm -f -- "$1"; }
fs_remove_dir() { [[ -d "$1" ]] && safe_remove "$1"; }
fs_copy() { cp -f -- "$1" "$2"; }
fs_copy_dir() { cp -a -- "$1" "$2"; }
fs_move() { mv -f -- "$1" "$2"; }
fs_clean_build() { [[ -d "${GBIP_BUILD_DIR}" ]] && safe_remove "${GBIP_BUILD_DIR}"; ensure_dir "${GBIP_BUILD_DIR}"; }
fs_clean_distribution() { [[ -d "${GBIP_DIST_DIR}" ]] && safe_remove "${GBIP_DIST_DIR}"; ensure_dir "${GBIP_DIST_DIR}"; }
fs_clean_runtime() { [[ -d "${GBIP_CACHE_DIR}" ]] && safe_remove "${GBIP_CACHE_DIR}"; [[ -d "${GBIP_LOG_DIR}" ]] && safe_remove "${GBIP_LOG_DIR}"; [[ -d "${GBIP_TMP_DIR}" ]] && safe_remove "${GBIP_TMP_DIR}"; ensure_dirs "${GBIP_CACHE_DIR}" "${GBIP_LOG_DIR}" "${GBIP_TMP_DIR}"; }
fs_initialize_repository() { ensure_dirs "${GBIP_BUILD_DIR}" "${GBIP_DIST_DIR}" "${GBIP_CACHE_DIR}" "${GBIP_LOG_DIR}" "${GBIP_TMP_DIR}" "${GBIP_GITHOOKS_DIR}"; }
