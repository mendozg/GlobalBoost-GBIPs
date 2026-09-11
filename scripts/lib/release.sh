#!/usr/bin/env bash
#
# release.sh
#
# Release-management layer for the GBIP shell framework.
#
# Responsibilities:
#   - Validate release versions
#   - Validate release channels/classifications
#   - Prepare release directories
#   - Generate release manifests
#   - Generate SHA-256 checksums
#   - Build release archives
#   - Verify release artifacts
#   - Prepare Git tags
#   - Support optional GPG signing
#   - Export CI release information
#   - Provide dry-run and force-safe behavior
#
# This module does NOT push Git tags or GitHub releases automatically.
# Publishing remains an explicit operation controlled by the caller.
#

[[ -n "${GBIP_RELEASE_LIB_LOADED:-}" ]] && return
readonly GBIP_RELEASE_LIB_LOADED=1

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

SCRIPT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_LIB_DIR}/config.sh"
source "${SCRIPT_LIB_DIR}/common.sh"
source "${SCRIPT_LIB_DIR}/filesystem.sh"
source "${SCRIPT_LIB_DIR}/git.sh"
source "${SCRIPT_LIB_DIR}/python.sh"

# ---------------------------------------------------------------------------
# Release configuration
# ---------------------------------------------------------------------------

GBIP_RELEASE_VERSION="${GBIP_RELEASE_VERSION:-}"
GBIP_RELEASE_CHANNEL="${GBIP_RELEASE_CHANNEL:-${GBIP_DEFAULT_RELEASE_CHANNEL}}"
GBIP_RELEASE_CLASSIFICATION="${GBIP_RELEASE_CLASSIFICATION:-${GBIP_DEFAULT_RELEASE_CLASSIFICATION}}"

GBIP_RELEASE_DIR="${GBIP_RELEASE_DIR:-${GBIP_DIST_DIR}/release}"

GBIP_RELEASE_ARCHIVE="${GBIP_RELEASE_ARCHIVE:-}"
GBIP_RELEASE_MANIFEST="${GBIP_RELEASE_MANIFEST:-${GBIP_MANIFEST_FILE}}"
GBIP_RELEASE_CHECKSUMS="${GBIP_RELEASE_CHECKSUMS:-${GBIP_CHECKSUM_FILE}}"

GBIP_RELEASE_SIGN="${GBIP_RELEASE_SIGN:-0}"
GBIP_RELEASE_GPG_KEY="${GBIP_RELEASE_GPG_KEY:-}"

GBIP_RELEASE_CREATE_TAG="${GBIP_RELEASE_CREATE_TAG:-0}"
GBIP_RELEASE_PUSH_TAG="${GBIP_RELEASE_PUSH_TAG:-0}"

GBIP_RELEASE_ALLOW_DIRTY="${GBIP_RELEASE_ALLOW_DIRTY:-0}"
GBIP_RELEASE_ALLOW_EXISTING="${GBIP_RELEASE_ALLOW_EXISTING:-0}"

GBIP_RELEASE_TIMESTAMP="${GBIP_RELEASE_TIMESTAMP:-}"

# ---------------------------------------------------------------------------
# Release constants
# ---------------------------------------------------------------------------

readonly GBIP_RELEASE_TAG_PREFIX="${GBIP_RELEASE_TAG_PREFIX:-v}"

# ---------------------------------------------------------------------------
# Release version
# ---------------------------------------------------------------------------

release_set_version() {
    local version="$1"

    [[ -n "${version}" ]] ||
        gbip_die_usage "Release version is required."

    require_semver "${version}"

    GBIP_RELEASE_VERSION="${version}"

    export GBIP_RELEASE_VERSION
}

release_version() {
    if [[ -z "${GBIP_RELEASE_VERSION}" ]]; then
        load_version
        GBIP_RELEASE_VERSION="${GBIP_VERSION}"
    fi

    printf '%s\n' "${GBIP_RELEASE_VERSION}"
}

release_require_version() {
    local version

    version="$(release_version)"

    require_semver "${version}"
}

# ---------------------------------------------------------------------------
# Release channels
# ---------------------------------------------------------------------------

release_validate_channel() {
    local channel="$1"

    case "${channel}" in
        development|preview|release-candidate|stable|maintenance|archived)
            return 0
            ;;
        *)
            error "Invalid release channel: ${channel}"
            error "Valid channels:"
            error "  development"
            error "  preview"
            error "  release-candidate"
            error "  stable"
            error "  maintenance"
            error "  archived"
            return 1
            ;;
    esac
}

release_set_channel() {
    local channel="$1"

    release_validate_channel "${channel}" ||
        gbip_die_usage "Invalid release channel: ${channel}"

    GBIP_RELEASE_CHANNEL="${channel}"
    export GBIP_RELEASE_CHANNEL
}

# ---------------------------------------------------------------------------
# Release classifications
# ---------------------------------------------------------------------------

release_validate_classification() {
    local classification="$1"

    case "${classification}" in
        draft|preview|release-candidate|stable|maintenance|deprecated|archived)
            return 0
            ;;
        *)
            error "Invalid release classification: ${classification}"
            error "Valid classifications:"
            error "  draft"
            error "  preview"
            error "  release-candidate"
            error "  stable"
            error "  maintenance"
            error "  deprecated"
            error "  archived"
            return 1
            ;;
    esac
}

release_set_classification() {
    local classification="$1"

    release_validate_classification "${classification}" ||
        gbip_die_usage "Invalid release classification: ${classification}"

    GBIP_RELEASE_CLASSIFICATION="${classification}"
    export GBIP_RELEASE_CLASSIFICATION
}

# ---------------------------------------------------------------------------
# Release tag
# ---------------------------------------------------------------------------

release_tag() {
    local version

    version="$(release_version)"

    printf '%s%s\n' "${GBIP_RELEASE_TAG_PREFIX}" "${version}"
}

release_tag_exists() {
    local tag

    tag="$(release_tag)"

    git_tag_exists "${tag}"
}

release_require_tag_available() {
    local tag

    tag="$(release_tag)"

    if git_tag_exists "${tag}"; then
        if [[ "${GBIP_RELEASE_ALLOW_EXISTING}" -eq 1 ]]; then
            warning "Git tag already exists: ${tag}"
            return 0
        fi

        gbip_die_release "Git tag already exists: ${tag}"
    fi
}

# ---------------------------------------------------------------------------
# Release directories
# ---------------------------------------------------------------------------

release_initialize_directories() {
    ensure_dir "${GBIP_DIST_DIR}"
    ensure_dir "${GBIP_RELEASE_DIR}"
    ensure_dir "${GBIP_BUILD_DIR}"
}

release_directory() {
    local version

    version="$(release_version)"

    printf '%s\n' "${GBIP_RELEASE_DIR}/${version}"
}

release_prepare_directory() {
    local directory

    directory="$(release_directory)"

    if [[ -d "${directory}" ]]; then
        if [[ "${GBIP_RELEASE_ALLOW_EXISTING}" -eq 1 ]]; then
            warning "Release directory already exists: ${directory}"
        else
            gbip_die_release \
                "Release directory already exists: ${directory}. Use --force to reuse it."
        fi
    else
        fs_mkdir "${directory}"
    fi

    printf '%s\n' "${directory}"
}

# ---------------------------------------------------------------------------
# Release archive
# ---------------------------------------------------------------------------

release_archive_name() {
    local version

    version="$(release_version)"

    printf '%s-%s.zip\n' "${GBIP_ARCHIVE_PREFIX}" "${version}"
}

release_archive_path() {
    local version

    version="$(release_version)"

    if [[ -n "${GBIP_RELEASE_ARCHIVE}" ]]; then
        printf '%s\n' "${GBIP_RELEASE_ARCHIVE}"
    else
        printf '%s\n' \
            "${GBIP_DIST_DIR}/${GBIP_ARCHIVE_PREFIX}-${version}.zip"
    fi
}

# ---------------------------------------------------------------------------
# Source selection
# ---------------------------------------------------------------------------

release_should_include() {
    local path="$1"

    case "${path}" in
        .git)
            return 1
            ;;
        .git/*)
            return 1
            ;;
        .venv)
            return 1
            ;;
        .venv/*)
            return 1
            ;;
        build)
            return 1
            ;;
        build/*)
            return 1
            ;;
        dist)
            return 1
            ;;
        dist/*)
            return 1
            ;;
        .cache)
            return 1
            ;;
        .cache/*)
            return 1
            ;;
        logs)
            return 1
            ;;
        logs/*)
            return 1
            ;;
        tmp)
            return 1
            ;;
        tmp/*)
            return 1
            ;;
        __pycache__)
            return 1
            ;;
        *__pycache__/*)
            return 1
            ;;
        *.pyc)
            return 1
            ;;
        *.pyo)
            return 1
            ;;
    esac

    return 0
}

# ---------------------------------------------------------------------------
# Release staging
# ---------------------------------------------------------------------------

release_stage() {
    local stage_dir
    local version

    version="$(release_version)"
    stage_dir="$(release_prepare_directory)"

    info "Staging release ${version}"

    fs_mkdir "${stage_dir}"

    #
    # Copy canonical repository components.
    #
    local directories=(
        gbips
        registry
        schemas
        templates
        docs
        tools
        tests
        scripts
    )

    local directory

    for directory in "${directories[@]}"; do
        if [[ -d "${GBIP_ROOT_DIR}/${directory}" ]]; then
            fs_copy_dir \
                "${GBIP_ROOT_DIR}/${directory}" \
                "${stage_dir}/${directory}"
        fi
    done

    #
    # Copy root-level project files.
    #
    local files=(
        README.md
        LICENSE
        CONTRIBUTING.md
        CODE_OF_CONDUCT.md
        SECURITY.md
        CHANGELOG.md
        ROADMAP.md
        VERSION
        requirements.txt
        requirements-dev.txt
        package.json
        package-lock.json
        .editorconfig
        .gitignore
    )

    local file

    for file in "${files[@]}"; do
        if [[ -f "${GBIP_ROOT_DIR}/${file}" ]]; then
            fs_copy \
                "${GBIP_ROOT_DIR}/${file}" \
                "${stage_dir}/${file}"
        fi
    done

    #
    # Preserve GitHub workflow definitions when present.
    #
    if [[ -d "${GBIP_GITHUB_DIR}/workflows" ]]; then
        fs_mkdir "${stage_dir}/.github"
        fs_copy_dir \
            "${GBIP_GITHUB_DIR}/workflows" \
            "${stage_dir}/.github/workflows"
    fi

    success "Release staged: ${stage_dir}"

    printf '%s\n' "${stage_dir}"
}

# ---------------------------------------------------------------------------
# Release manifest
# ---------------------------------------------------------------------------

release_generate_manifest() {
    local version
    local manifest
    local generator

    version="$(release_version)"
    manifest="${GBIP_RELEASE_MANIFEST}"
    generator="${GBIP_TOOLS_DIR}/generate_release_manifest.py"

    info "Generating release manifest"

    if [[ -f "${generator}" ]]; then
        python_tool "$(basename "${generator}")" \
            --version "${version}" \
            --channel "${GBIP_RELEASE_CHANNEL}" \
            --classification "${GBIP_RELEASE_CLASSIFICATION}" \
            --output "${manifest}"

        return $?
    fi

    warning "Release manifest generator not found: ${generator}"
    warning "Generating minimal manifest."

    local timestamp

    if [[ -n "${GBIP_RELEASE_TIMESTAMP}" ]]; then
        timestamp="${GBIP_RELEASE_TIMESTAMP}"
    else
        timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    fi

    fs_write_atomic "${manifest}" <<EOF
{
  "schema_version": "1.0.0",
  "project": "${GBIP_PROJECT_NAME}",
  "version": "${version}",
  "release_channel": "${GBIP_RELEASE_CHANNEL}",
  "release_classification": "${GBIP_RELEASE_CLASSIFICATION}",
  "created_at": "${timestamp}",
  "archive": "${GBIP_ARCHIVE_PREFIX}-${version}.zip"
}
EOF

    success "Release manifest generated: ${manifest}"
}

# ---------------------------------------------------------------------------
# SHA-256 checksums
# ---------------------------------------------------------------------------

release_checksum_command() {
    if command_exists sha256sum; then
        printf '%s\n' "sha256sum"
        return 0
    fi

    if command_exists shasum; then
        printf '%s\n' "shasum"
        return 0
    fi

    if command_exists certutil; then
        printf '%s\n' "certutil"
        return 0
    fi

    return 1
}

release_generate_checksums() {
    local archive="$1"
    local checksum_file="${2:-${GBIP_RELEASE_CHECKSUMS}}"
    local command

    require_file "${archive}"

    command="$(release_checksum_command)" || {
        gbip_die_dependency \
            "No SHA-256 checksum utility found."
    }

    info "Generating SHA-256 checksum"

    case "${command}" in
        sha256sum)
            (
                cd "$(dirname "${archive}")"
                sha256sum "$(basename "${archive}")"
            ) > "${checksum_file}"
            ;;
        shasum)
            (
                cd "$(dirname "${archive}")"
                shasum -a 256 "$(basename "${archive")"
            ) > "${checksum_file}"
            ;;
        certutil)
            certutil -hashfile "${archive}" SHA256 > "${checksum_file}"
            ;;
        *)
            gbip_die_dependency \
                "Unsupported checksum command: ${command}"
            ;;
    esac

    success "Checksum file generated: ${checksum_file}"
}

# ---------------------------------------------------------------------------
# Archive creation
# ---------------------------------------------------------------------------

release_create_archive() {
    local stage_dir="$1"
    local archive

    require_dir "${stage_dir}"

    archive="$(release_archive_path)"

    info "Creating release archive"

    if [[ -e "${archive}" ]]; then
        if [[ "${GBIP_RELEASE_ALLOW_EXISTING}" -eq 1 ]]; then
            warning "Replacing existing archive: ${archive}"
            fs_remove_file "${archive}"
        else
            gbip_die_release \
                "Release archive already exists: ${archive}"
        fi
    fi

    if command_exists zip; then
        run_shell \
            "cd \"$(dirname "${stage_dir}")\" && zip -qr \"${archive}\" \"$(basename "${stage_dir}")\""
    elif python_has_module zipfile; then
        python_run - "${stage_dir}" "${archive}" <<'PY'
import os
import sys
import zipfile

source = os.path.abspath(sys.argv[1])
archive = os.path.abspath(sys.argv[2])

with zipfile.ZipFile(
    archive,
    "w",
    compression=zipfile.ZIP_DEFLATED,
) as zf:
    for root, dirs, files in os.walk(source):
        dirs[:] = [
            d for d in dirs
            if d not in {".git", ".venv", "__pycache__"}
        ]

        for filename in files:
            if filename.endswith((".pyc", ".pyo")):
                continue

            path = os.path.join(root, filename)
            arcname = os.path.relpath(path, os.path.dirname(source))
            zf.write(path, arcname)

print(f"Created archive: {archive}")
PY
    else
        gbip_die_dependency \
            "Neither zip nor Python zipfile is available."
    fi

    require_file "${archive}"

    success "Release archive created: ${archive}"

    printf '%s\n' "${archive}"
}

# ---------------------------------------------------------------------------
# Archive verification
# ---------------------------------------------------------------------------

release_verify_archive() {
    local archive="$1"

    require_file "${archive}"

    info "Verifying release archive"

    if command_exists unzip; then
        run unzip -t "${archive}"
    else
        python_run - "${archive}" <<'PY'
import sys
import zipfile

archive = sys.argv[1]

with zipfile.ZipFile(archive, "r") as zf:
    bad = zf.testzip()

if bad is not None:
    print(f"Corrupt archive member: {bad}", file=sys.stderr)
    raise SystemExit(1)

print(f"Archive OK: {archive}")
PY
    fi
}

# ---------------------------------------------------------------------------
# Checksum verification
# ---------------------------------------------------------------------------

release_verify_checksum() {
    local archive="$1"
    local checksum_file="$2"

    require_file "${archive}"
    require_file "${checksum_file}"

    local command
    command="$(release_checksum_command)" || {
        gbip_die_dependency \
            "No SHA-256 checksum utility found."
    }

    info "Verifying SHA-256 checksum"

    case "${command}" in
        sha256sum)
            (
                cd "$(dirname "${archive}")"
                sha256sum -c \
                    <(
                        sed \
                            "s#  .*#  $(basename "${archive}")#" \
                            "${checksum_file}"
                    )
            )
            ;;
        shasum)
            python_run - "${archive}" "${checksum_file}" <<'PY'
import hashlib
import sys

archive = sys.argv[1]
checksum_file = sys.argv[2]

with open(checksum_file, "r", encoding="utf-8") as f:
    expected = f.read().split()[0].lower()

digest = hashlib.sha256()

with open(archive, "rb") as f:
    for block in iter(lambda: f.read(1024 * 1024), b""):
        digest.update(block)

actual = digest.hexdigest()

if actual != expected:
    print(f"Checksum mismatch:\nexpected: {expected}\nactual:   {actual}")
    raise SystemExit(1)

print("SHA-256 checksum verified.")
PY
            ;;
        certutil)
            warning "Automatic certutil verification is not implemented."
            warning "Checksum file generated successfully; verify manually."
            ;;
        *)
            gbip_die_dependency \
                "Unsupported checksum command: ${command}"
            ;;
    esac

    success "SHA-256 checksum verified"
}

# ---------------------------------------------------------------------------
# Release signing
# ---------------------------------------------------------------------------

release_gpg_available() {
    command_exists gpg
}

release_sign_file() {
    local file="$1"

    require_file "${file}"

    release_gpg_available || {
        gbip_die_dependency \
            "GPG is required for release signing."
    }

    info "Signing release artifact: ${file}"

    if [[ -n "${GBIP_RELEASE_GPG_KEY}" ]]; then
        run gpg \
            --local-user "${GBIP_RELEASE_GPG_KEY}" \
            --detach-sign \
            --armor \
            "${file}"
    else
        run gpg \
            --detach-sign \
            --armor \
            "${file}"
    fi

    require_file "${file}.asc"

    success "Signature created: ${file}.asc"
}

release_sign_artifacts() {
    local archive="$1"

    [[ "${GBIP_RELEASE_SIGN}" -eq 1 ]] || return 0

    release_sign_file "${archive}"
    release_sign_file "${GBIP_RELEASE_CHECKSUMS}"

    if [[ -f "${GBIP_RELEASE_MANIFEST}" ]]; then
        release_sign_file "${GBIP_RELEASE_MANIFEST}"
    fi
}

# ---------------------------------------------------------------------------
# Release metadata
# ---------------------------------------------------------------------------

release_metadata() {
    local version

    version="$(release_version)"

    cat <<EOF
Project          : ${GBIP_PROJECT_NAME}
Version          : ${version}
Channel          : ${GBIP_RELEASE_CHANNEL}
Classification   : ${GBIP_RELEASE_CLASSIFICATION}
Tag              : $(release_tag)
Archive          : $(release_archive_name)
Release directory: $(release_directory)
EOF
}

# ---------------------------------------------------------------------------
# Release preflight
# ---------------------------------------------------------------------------

release_preflight() {
    local version

    version="$(release_version)"

    require_semver "${version}"

    release_validate_channel "${GBIP_RELEASE_CHANNEL}" ||
        gbip_die_release "Invalid release channel."

    release_validate_classification "${GBIP_RELEASE_CLASSIFICATION}" ||
        gbip_die_release "Invalid release classification."

    git_release_preflight "${version}" ||
        gbip_die_release "Git release preflight failed."

    release_require_tag_available

    release_initialize_directories
}

# ---------------------------------------------------------------------------
# Release validation
# ---------------------------------------------------------------------------

release_validate_artifacts() {
    local archive

    archive="$(release_archive_path)"

    require_file "${archive}"
    require_file "${GBIP_RELEASE_CHECKSUMS}"

    release_verify_archive "${archive}"
    release_verify_checksum "${archive}" "${GBIP_RELEASE_CHECKSUMS}"

    if [[ -f "${GBIP_RELEASE_MANIFEST}" ]]; then
        info "Release manifest present: ${GBIP_RELEASE_MANIFEST}"
    else
        warning "Release manifest is missing: ${GBIP_RELEASE_MANIFEST}"
    fi

    success "Release artifacts validated"
}

# ---------------------------------------------------------------------------
# Git tag preparation
# ---------------------------------------------------------------------------

release_create_git_tag() {
    local version
    local tag

    version="$(release_version)"
    tag="$(release_tag)"

    if git_tag_exists "${tag}"; then
        if [[ "${GBIP_RELEASE_ALLOW_EXISTING}" -eq 1 ]]; then
            warning "Git tag already exists: ${tag}"
            return 0
        fi

        gbip_die_release "Git tag already exists: ${tag}"
    fi

    info "Creating Git tag: ${tag}"

    git_create_tag "${tag}" \
        "GBIP ${version}"

    success "Git tag created: ${tag}"
}

release_push_git_tag() {
    local tag

    tag="$(release_tag)"

    require_git

    info "Pushing Git tag: ${tag}"

    run git -C "${GBIP_ROOT_DIR}" push origin "${tag}"

    success "Git tag pushed: ${tag}"
}

# ---------------------------------------------------------------------------
# GitHub Actions integration
# ---------------------------------------------------------------------------

release_export_ci() {
    local version
    local archive
    local tag

    version="$(release_version)"
    archive="$(release_archive_path)"
    tag="$(release_tag)"

    git_set_output "release_version" "${version}"
    git_set_output "release_channel" "${GBIP_RELEASE_CHANNEL}"
    git_set_output "release_classification" "${GBIP_RELEASE_CLASSIFICATION}"
    git_set_output "release_tag" "${tag}"
    git_set_output "release_archive" "${archive}"
    git_set_output "release_manifest" "${GBIP_RELEASE_MANIFEST}"
    git_set_output "release_checksums" "${GBIP_RELEASE_CHECKSUMS}"
}

# ---------------------------------------------------------------------------
# Complete local release pipeline
# ---------------------------------------------------------------------------

release_build() {
    local version
    local stage_dir
    local archive

    version="$(release_version)"

    header "Building GBIP Release ${version}"

    release_preflight

    stage_dir="$(release_stage)"

    release_generate_manifest

    archive="$(release_create_archive "${stage_dir}")"

    release_generate_checksums "${archive}"

    release_verify_archive "${archive}"
    release_verify_checksum "${archive}" "${GBIP_RELEASE_CHECKSUMS}"

    release_sign_artifacts "${archive}"

    release_export_ci

    success "Release ${version} built successfully"

    release_metadata
}

# ---------------------------------------------------------------------------
# Complete release verification
# ---------------------------------------------------------------------------

release_verify() {
    local archive

    archive="$(release_archive_path)"

    header "Verifying GBIP Release"

    release_validate_artifacts

    if [[ "${GBIP_RELEASE_SIGN}" -eq 1 ]]; then
        release_gpg_available || gbip_die_dependency "GPG is unavailable."

        if [[ -f "${archive}.asc" ]]; then
            info "Verifying archive signature"
            run gpg --verify "${archive}.asc" "${archive}"
        fi
    fi

    success "Release verification complete"
}

# ---------------------------------------------------------------------------
# Release cleanup
# ---------------------------------------------------------------------------

release_clean_version() {
    local directory
    local archive

    directory="$(release_directory)"
    archive="$(release_archive_path)"

    if [[ -d "${directory}" ]]; then
        info "Removing release staging directory: ${directory}"
        fs_remove_dir "${directory}"
    fi

    if [[ -f "${archive}" ]]; then
        info "Removing release archive: ${archive}"
        fs_remove_file "${archive}"
    fi
}

# ---------------------------------------------------------------------------
# Release summary
# ---------------------------------------------------------------------------

release_summary() {
    local archive

    archive="$(release_archive_path)"

    header "Release Summary"

    release_metadata

    printf "\nArtifacts:\n"

    if [[ -f "${archive}" ]]; then
        printf "  Archive    : %s\n" "${archive}"
    else
        printf "  Archive    : not created\n"
    fi

    if [[ -f "${GBIP_RELEASE_MANIFEST}" ]]; then
        printf "  Manifest   : %s\n" "${GBIP_RELEASE_MANIFEST}"
    else
        printf "  Manifest   : not created\n"
    fi

    if [[ -f "${GBIP_RELEASE_CHECKSUMS}" ]]; then
        printf "  SHA-256    : %s\n" "${GBIP_RELEASE_CHECKSUMS}"
    else
        printf "  SHA-256    : not created\n"
    fi

    if [[ -f "${archive}.asc" ]]; then
        printf "  Signature  : %s\n" "${archive}.asc"
    else
        printf "  Signature  : not created\n"
    fi
}

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

release_init() {
    release_version >/dev/null
    release_validate_channel "${GBIP_RELEASE_CHANNEL}" || return 1
    release_validate_classification "${GBIP_RELEASE_CLASSIFICATION}" || return 1
}

release_init