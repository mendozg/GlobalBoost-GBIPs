#!/usr/bin/env bash
#
# config.sh
#
# Central configuration and repository path definitions for the GBIP
# shell framework.
#
# This file is intended to be sourced by scripts in scripts/ and
# scripts/lib/.
#

[[ -n "${GBIP_CONFIG_LOADED:-}" ]] && return
readonly GBIP_CONFIG_LOADED=1

# ---------------------------------------------------------------------------
# Repository root
# ---------------------------------------------------------------------------

GBIP_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GBIP_ROOT_DIR="$(cd "${GBIP_SCRIPTS_DIR}/.." && pwd)"
GBIP_LIB_DIR="${GBIP_ROOT_DIR}/scripts/lib"

# ---------------------------------------------------------------------------
# Repository directories
# ---------------------------------------------------------------------------

GBIP_GBIPS_DIR="${GBIP_ROOT_DIR}/gbips"
GBIP_REGISTRY_DIR="${GBIP_ROOT_DIR}/registry"
GBIP_SCHEMAS_DIR="${GBIP_ROOT_DIR}/schemas"
GBIP_TEMPLATES_DIR="${GBIP_ROOT_DIR}/templates"
GBIP_DOCS_DIR="${GBIP_ROOT_DIR}/docs"
GBIP_TOOLS_DIR="${GBIP_ROOT_DIR}/tools"
GBIP_TESTS_DIR="${GBIP_ROOT_DIR}/tests"

# ---------------------------------------------------------------------------
# Generated / temporary directories
# ---------------------------------------------------------------------------

GBIP_BUILD_DIR="${GBIP_ROOT_DIR}/build"
GBIP_DIST_DIR="${GBIP_ROOT_DIR}/dist"
GBIP_CACHE_DIR="${GBIP_ROOT_DIR}/.cache"
GBIP_LOG_DIR="${GBIP_ROOT_DIR}/logs"
GBIP_TMP_DIR="${GBIP_ROOT_DIR}/tmp"

# ---------------------------------------------------------------------------
# Python environment
# ---------------------------------------------------------------------------

GBIP_VENV_DIR="${GBIP_ROOT_DIR}/.venv"
GBIP_PYTHON="${GBIP_VENV_DIR}/bin/python"
GBIP_PIP="${GBIP_VENV_DIR}/bin/pip"

# Windows / Git Bash compatibility.
#
# If the Unix-style virtualenv executable does not exist, callers may
# resolve the Windows executable as needed.
if [[ ! -x "${GBIP_PYTHON}" && -x "${GBIP_VENV_DIR}/Scripts/python.exe" ]]; then
    GBIP_PYTHON="${GBIP_VENV_DIR}/Scripts/python.exe"
fi

if [[ ! -x "${GBIP_PIP}" && -x "${GBIP_VENV_DIR}/Scripts/pip.exe" ]]; then
    GBIP_PIP="${GBIP_VENV_DIR}/Scripts/pip.exe"
fi

# ---------------------------------------------------------------------------
# Project files
# ---------------------------------------------------------------------------

GBIP_VERSION_FILE="${GBIP_ROOT_DIR}/VERSION"
GBIP_CHANGELOG_FILE="${GBIP_ROOT_DIR}/CHANGELOG.md"
GBIP_README_FILE="${GBIP_ROOT_DIR}/README.md"
GBIP_LICENSE_FILE="${GBIP_ROOT_DIR}/LICENSE"

GBIP_REQUIREMENTS_FILE="${GBIP_ROOT_DIR}/requirements.txt"
GBIP_DEV_REQUIREMENTS_FILE="${GBIP_ROOT_DIR}/requirements-dev.txt"

GBIP_PACKAGE_FILE="${GBIP_ROOT_DIR}/package.json"
GBIP_PACKAGE_LOCK_FILE="${GBIP_ROOT_DIR}/package-lock.json"

# ---------------------------------------------------------------------------
# Git configuration
# ---------------------------------------------------------------------------

GBIP_GIT_DIR="${GBIP_ROOT_DIR}/.git"
GBIP_GITHOOKS_DIR="${GBIP_ROOT_DIR}/.githooks"
GBIP_GITHUB_DIR="${GBIP_ROOT_DIR}/.github"

GBIP_DEFAULT_BRANCH="${GBIP_DEFAULT_BRANCH:-main}"

# ---------------------------------------------------------------------------
# Project identity
# ---------------------------------------------------------------------------

GBIP_PROJECT_NAME="${GBIP_PROJECT_NAME:-GBIP}"
GBIP_PROJECT_FULL_NAME="${GBIP_PROJECT_FULL_NAME:-GlobalBoost Improvement Proposals}"

# Repository archive naming.
GBIP_ARCHIVE_PREFIX="${GBIP_ARCHIVE_PREFIX:-GBIP}"

# ---------------------------------------------------------------------------
# Version
# ---------------------------------------------------------------------------

GBIP_VERSION=""

load_version() {
    if [[ ! -f "${GBIP_VERSION_FILE}" ]]; then
        GBIP_VERSION="0.0.0-dev"
        return 0
    fi

    GBIP_VERSION="$(tr -d '[:space:]' < "${GBIP_VERSION_FILE}")"

    if [[ -z "${GBIP_VERSION}" ]]; then
        GBIP_VERSION="0.0.0-dev"
    fi
}

load_version

# ---------------------------------------------------------------------------
# Release paths
# ---------------------------------------------------------------------------

GBIP_RELEASE_DIR="${GBIP_DIST_DIR}/release"
GBIP_MANIFEST_FILE="${GBIP_BUILD_DIR}/release-manifest.json"
GBIP_CHECKSUM_FILE="${GBIP_DIST_DIR}/SHA256SUMS"

# ---------------------------------------------------------------------------
# Standard exit codes
# ---------------------------------------------------------------------------

readonly GBIP_EXIT_SUCCESS=0
readonly GBIP_EXIT_GENERAL=1
readonly GBIP_EXIT_USAGE=2
readonly GBIP_EXIT_MISSING_DEPENDENCY=3
readonly GBIP_EXIT_VALIDATION=4
readonly GBIP_EXIT_BUILD=5
readonly GBIP_EXIT_RELEASE=6
readonly GBIP_EXIT_NOT_GIT_REPOSITORY=7

# ---------------------------------------------------------------------------
# Environment defaults
# ---------------------------------------------------------------------------

GBIP_ENVIRONMENT="${GBIP_ENVIRONMENT:-development}"

GBIP_CI="${GBIP_CI:-0}"
GBIP_QUIET="${GBIP_QUIET:-0}"
GBIP_VERBOSE="${GBIP_VERBOSE:-0}"
GBIP_DEBUG="${GBIP_DEBUG:-0}"
GBIP_DRY_RUN="${GBIP_DRY_RUN:-0}"
GBIP_FORCE="${GBIP_FORCE:-0}"
GBIP_YES="${GBIP_YES:-0}"

# Color behavior is handled by colors.sh.
GBIP_COLOR_MODE="${GBIP_COLOR_MODE:-auto}"

# ---------------------------------------------------------------------------
# Validation configuration
# ---------------------------------------------------------------------------

GBIP_VALIDATE_REGISTRY="${GBIP_VALIDATE_REGISTRY:-1}"
GBIP_VALIDATE_SCHEMAS="${GBIP_VALIDATE_SCHEMAS:-1}"
GBIP_VALIDATE_METADATA="${GBIP_VALIDATE_METADATA:-1}"
GBIP_VALIDATE_DOCUMENTS="${GBIP_VALIDATE_DOCUMENTS:-1}"
GBIP_VALIDATE_NUMBERING="${GBIP_VALIDATE_NUMBERING:-1}"
GBIP_VALIDATE_LINKS="${GBIP_VALIDATE_LINKS:-1}"

# ---------------------------------------------------------------------------
# Build configuration
# ---------------------------------------------------------------------------

GBIP_BUILD_CLEAN="${GBIP_BUILD_CLEAN:-1}"
GBIP_BUILD_GENERATE="${GBIP_BUILD_GENERATE:-1}"
GBIP_BUILD_VALIDATE="${GBIP_BUILD_VALIDATE:-1}"

# ---------------------------------------------------------------------------
# Release configuration
# ---------------------------------------------------------------------------

GBIP_RELEASE_VALIDATE="${GBIP_RELEASE_VALIDATE:-1}"
GBIP_RELEASE_BUILD="${GBIP_RELEASE_BUILD:-1}"
GBIP_RELEASE_SIGN="${GBIP_RELEASE_SIGN:-0}"

GBIP_RELEASE_CHANNEL="${GBIP_RELEASE_CHANNEL:-stable}"
GBIP_RELEASE_CLASSIFICATION="${GBIP_RELEASE_CLASSIFICATION:-stable}"

# ---------------------------------------------------------------------------
# Utility functions
# ---------------------------------------------------------------------------

gbip_root() {
    printf '%s\n' "${GBIP_ROOT_DIR}"
}

gbip_version() {
    printf '%s\n' "${GBIP_VERSION}"
}

gbip_archive_name() {
    printf '%s-%s.zip\n' "${GBIP_ARCHIVE_PREFIX}" "${GBIP_VERSION}"
}

gbip_archive_path() {
    printf '%s\n' "${GBIP_DIST_DIR}/$(gbip_archive_name)"
}

gbip_path_exists() {
    [[ -e "$1" ]]
}

gbip_dir_exists() {
    [[ -d "$1" ]]
}

gbip_file_exists() {
    [[ -f "$1" ]]
}

# ---------------------------------------------------------------------------
# Repository sanity checks
# ---------------------------------------------------------------------------

gbip_config_check() {
    local missing=0

    local required_dirs=(
        "${GBIP_ROOT_DIR}"
        "${GBIP_SCRIPTS_DIR}"
        "${GBIP_GBIPS_DIR}"
        "${GBIP_REGISTRY_DIR}"
        "${GBIP_SCHEMAS_DIR}"
        "${GBIP_TOOLS_DIR}"
        "${GBIP_TESTS_DIR}"
    )

    local directory

    for directory in "${required_dirs[@]}"; do
        if [[ ! -d "${directory}" ]]; then
            printf 'Missing directory: %s\n' "${directory}" >&2
            missing=1
        fi
    done

    if [[ ! -f "${GBIP_VERSION_FILE}" ]]; then
        printf 'Warning: VERSION file not found: %s\n' \
            "${GBIP_VERSION_FILE}" >&2
    fi

    return "${missing}"
}

# ---------------------------------------------------------------------------
# Directory initialization
# ---------------------------------------------------------------------------

gbip_create_runtime_dirs() {
    mkdir -p \
        "${GBIP_BUILD_DIR}" \
        "${GBIP_DIST_DIR}" \
        "${GBIP_CACHE_DIR}" \
        "${GBIP_LOG_DIR}" \
        "${GBIP_TMP_DIR}"
}

# ---------------------------------------------------------------------------
# Configuration summary
# ---------------------------------------------------------------------------

gbip_config_summary() {
    cat <<EOF
GBIP Configuration
==================

Project:
  Name:              ${GBIP_PROJECT_NAME}
  Full Name:         ${GBIP_PROJECT_FULL_NAME}
  Version:           ${GBIP_VERSION}
  Environment:       ${GBIP_ENVIRONMENT}
  Default Branch:    ${GBIP_DEFAULT_BRANCH}

Repository:
  Root:              ${GBIP_ROOT_DIR}
  GBIPs:             ${GBIP_GBIPS_DIR}
  Registry:          ${GBIP_REGISTRY_DIR}
  Schemas:           ${GBIP_SCHEMAS_DIR}
  Templates:         ${GBIP_TEMPLATES_DIR}
  Documentation:     ${GBIP_DOCS_DIR}
  Tools:             ${GBIP_TOOLS_DIR}
  Tests:             ${GBIP_TESTS_DIR}

Runtime:
  Build:             ${GBIP_BUILD_DIR}
  Distribution:      ${GBIP_DIST_DIR}
  Cache:             ${GBIP_CACHE_DIR}
  Logs:              ${GBIP_LOG_DIR}
  Temporary:         ${GBIP_TMP_DIR}

Python:
  Virtualenv:        ${GBIP_VENV_DIR}
  Python:            ${GBIP_PYTHON}
  Pip:               ${GBIP_PIP}

Release:
  Channel:           ${GBIP_RELEASE_CHANNEL}
  Classification:    ${GBIP_RELEASE_CLASSIFICATION}
  Manifest:           ${GBIP_MANIFEST_FILE}
  Checksums:          ${GBIP_CHECKSUM_FILE}
EOF
}

# ---------------------------------------------------------------------------
# Export configuration
# ---------------------------------------------------------------------------

export GBIP_ROOT_DIR
export GBIP_SCRIPTS_DIR
export GBIP_LIB_DIR

export GBIP_GBIPS_DIR
export GBIP_REGISTRY_DIR
export GBIP_SCHEMAS_DIR
export GBIP_TEMPLATES_DIR
export GBIP_DOCS_DIR
export GBIP_TOOLS_DIR
export GBIP_TESTS_DIR

export GBIP_BUILD_DIR
export GBIP_DIST_DIR
export GBIP_CACHE_DIR
export GBIP_LOG_DIR
export GBIP_TMP_DIR

export GBIP_VENV_DIR
export GBIP_PYTHON
export GBIP_PIP

export GBIP_VERSION_FILE
export GBIP_CHANGELOG_FILE
export GBIP_README_FILE
export GBIP_LICENSE_FILE

export GBIP_REQUIREMENTS_FILE
export GBIP_DEV_REQUIREMENTS_FILE

export GBIP_GIT_DIR
export GBIP_GITHOOKS_DIR
export GBIP_GITHUB_DIR

export GBIP_DEFAULT_BRANCH

export GBIP_PROJECT_NAME
export GBIP_PROJECT_FULL_NAME
export GBIP_ARCHIVE_PREFIX
export GBIP_VERSION

export GBIP_RELEASE_DIR
export GBIP_MANIFEST_FILE
export GBIP_CHECKSUM_FILE

export GBIP_ENVIRONMENT