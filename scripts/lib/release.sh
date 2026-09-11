#!/usr/bin/env bash
GBIP_RELEASE_VERSION="${GBIP_RELEASE_VERSION:-}"
GBIP_RELEASE_CHANNEL="${GBIP_RELEASE_CHANNEL:-stable}"
GBIP_RELEASE_CLASSIFICATION="${GBIP_RELEASE_CLASSIFICATION:-stable}"
GBIP_RELEASE_ARCHIVE="${GBIP_RELEASE_ARCHIVE:-}"
release_version() { [[ -n "${GBIP_RELEASE_VERSION}" ]] && printf '%s\n' "${GBIP_RELEASE_VERSION}" || gbip_require_version; }
release_archive_path() {
    local version
    version="$(release_version)"
    if [[ -n "${GBIP_RELEASE_ARCHIVE:-}" ]]; then
        printf '%s\n' "${GBIP_RELEASE_ARCHIVE}"
    else
        printf '%s\n' "${GBIP_DIST_DIR}/${GBIP_ARCHIVE_PREFIX}-${version}.zip"
    fi
}
release_validate_channel() { case "$1" in development|preview|release-candidate|stable|maintenance|archived) return 0;; *) gbip_die_release "Invalid release channel: $1";; esac; }
release_validate_classification() { case "$1" in draft|preview|release-candidate|stable|maintenance|deprecated|archived) return 0;; *) gbip_die_release "Invalid release classification: $1";; esac; }
release_prepare() { local v; v="$(release_version)"; release_validate_channel "${GBIP_RELEASE_CHANNEL}"; release_validate_classification "${GBIP_RELEASE_CLASSIFICATION}"; git_release_preflight "$v"; ensure_dirs "${GBIP_RELEASE_DIR}" "${GBIP_DIST_DIR}"; }
release_stage() {
    local v staging
    v="$(release_version)"
    staging="${GBIP_RELEASE_DIR}/${v}"
    safe_remove "${staging}" 2>/dev/null || true
    ensure_dir "${staging}"
    if [[ -d "${GBIP_BUILD_DIR}" ]] && find "${GBIP_BUILD_DIR}" -mindepth 1 -print -quit | grep -q .; then cp -a "${GBIP_BUILD_DIR}/." "${staging}/"
    else
        [[ -d "${GBIP_GBIPS_DIR}" ]] && cp -a "${GBIP_GBIPS_DIR}" "${staging}/gbips"
        [[ -d "${GBIP_REGISTRY_DIR}" ]] && cp -a "${GBIP_REGISTRY_DIR}" "${staging}/registry"
        [[ -d "${GBIP_SCHEMAS_DIR}" ]] && cp -a "${GBIP_SCHEMAS_DIR}" "${staging}/schemas"
    fi
    printf '%s\n' "${staging}"
}
release_make_archive() {
    local staging archive
    staging="$(release_stage)"
    archive="$(release_archive_path)"
    ensure_dir "$(dirname "${archive}")"
    safe_remove "${archive}" 2>/dev/null || true
    (cd "${staging}" && zip -qr "${archive}" .)
    printf '%s\n' "${archive}"
}
release_write_checksum() {
    local archive="${1:-$(release_archive_path)}" checksum_file="${GBIP_CHECKSUM_FILE}"
    ensure_dir "$(dirname "${checksum_file}")"
    if command_exists sha256sum; then
        (cd "$(dirname "${archive}")"; sha256sum "$(basename "${archive}")") > "${checksum_file}"
    elif command_exists shasum; then
        (cd "$(dirname "${archive}")"; shasum -a 256 "$(basename "${archive}")") > "${checksum_file}"
    else
        gbip_die_release "No SHA-256 utility found."
    fi
}
release_verify_archive() { local a="${1:-$(release_archive_path)}"; [[ -f "$a" ]] || gbip_die_release "Release archive not found: $a"; unzip -tq "$a" >/dev/null; }
release_build() { release_prepare; release_make_archive; release_write_checksum; }
release_verify() { release_verify_archive; }
release_summary() { local v a; v="$(release_version)"; a="$(release_archive_path)"; printf 'Version: %s\nChannel: %s\nClassification: %s\nArchive: %s\n' "$v" "${GBIP_RELEASE_CHANNEL}" "${GBIP_RELEASE_CLASSIFICATION}" "$a"; }
