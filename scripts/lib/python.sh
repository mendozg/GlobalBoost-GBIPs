#!/usr/bin/env bash
#
# python.sh
#
# Python runtime and tooling layer for the GBIP shell framework.
#
# Responsibilities:
#   - Detect Python installations
#   - Resolve the preferred Python interpreter
#   - Detect/create the GBIP virtual environment
#   - Resolve pip
#   - Validate Python versions
#   - Install requirements
#   - Run project Python tools
#   - Run pytest
#   - Run ruff / black / isort
#   - Provide CI-friendly helpers
#   - Support dry-run mode
#   - Support Linux, macOS and Windows/Git Bash
#
# This module intentionally does NOT force virtual-environment creation
# merely because it is sourced.
#

[[ -n "${GBIP_PYTHON_LOADED:-}" ]] && return
readonly GBIP_PYTHON_LOADED=1

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

SCRIPT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_LIB_DIR}/config.sh"
source "${SCRIPT_LIB_DIR}/common.sh"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

GBIP_PYTHON_MIN_VERSION="${GBIP_PYTHON_MIN_VERSION:-3.9}"

GBIP_PYTHON_EXECUTABLE="${GBIP_PYTHON_EXECUTABLE:-}"
GBIP_PIP_EXECUTABLE="${GBIP_PIP_EXECUTABLE:-}"

GBIP_PYTHON_SYSTEM=""
GBIP_PYTHON_SOURCE=""

GBIP_VENV_CREATE="${GBIP_VENV_CREATE:-0}"
GBIP_PYTHON_UPGRADE_PIP="${GBIP_PYTHON_UPGRADE_PIP:-0}"

# Windows/Git Bash commonly uses python.exe / pip.exe.
GBIP_WINDOWS_PYTHON="${GBIP_WINDOWS_PYTHON:-python.exe}"
GBIP_WINDOWS_PYTHON3="${GBIP_WINDOWS_PYTHON3:-python3.exe}"

# ---------------------------------------------------------------------------
# Platform helpers
# ---------------------------------------------------------------------------

python_is_windows() {
    case "${OS:-}" in
        Windows_NT)
            return 0
            ;;
    esac

    case "$(uname -s 2>/dev/null || true)" in
        MINGW*|MSYS*|CYGWIN*)
            return 0
            ;;
    esac

    return 1
}

python_is_macos() {
    [[ "$(uname -s 2>/dev/null || true)" == "Darwin" ]]
}

python_is_linux() {
    [[ "$(uname -s 2>/dev/null || true)" == "Linux" ]]
}

# ---------------------------------------------------------------------------
# Python executable detection
# ---------------------------------------------------------------------------

python_candidate_list() {
    local candidates=()

    if [[ -n "${GBIP_PYTHON_EXECUTABLE}" ]]; then
        candidates+=("${GBIP_PYTHON_EXECUTABLE}")
    fi

    if [[ -n "${GBIP_PYTHON:-}" && "${GBIP_PYTHON}" != "${GBIP_PYTHON_EXECUTABLE}" ]]; then
        candidates+=("${GBIP_PYTHON}")
    fi

    candidates+=(
        "${GBIP_VENV_DIR}/bin/python"
        "${GBIP_VENV_DIR}/bin/python3"
        "${GBIP_VENV_DIR}/Scripts/python.exe"
        "${GBIP_VENV_DIR}/Scripts/python"
        python3
        python
    )

    if python_is_windows; then
        candidates+=(
            "${GBIP_WINDOWS_PYTHON3}"
            "${GBIP_WINDOWS_PYTHON}"
        )
    fi

    printf '%s\n' "${candidates[@]}"
}

python_resolve() {
    local candidate
    local resolved=""

    while IFS= read -r candidate; do
        [[ -z "${candidate}" ]] && continue

        if [[ -x "${candidate}" ]]; then
            resolved="${candidate}"
            break
        fi

        if command_exists "${candidate}"; then
            resolved="$(command -v "${candidate}")"
            break
        fi
    done < <(python_candidate_list)

    if [[ -z "${resolved}" ]]; then
        return 1
    fi

    GBIP_PYTHON_EXECUTABLE="${resolved}"

    if [[ "${resolved}" == "${GBIP_VENV_DIR}"/* ]]; then
        GBIP_PYTHON_SOURCE="venv"
    else
        GBIP_PYTHON_SOURCE="system"
        GBIP_PYTHON_SYSTEM="${resolved}"
    fi

    return 0
}

python_require() {
    if [[ -z "${GBIP_PYTHON_EXECUTABLE}" ]]; then
        python_resolve || gbip_die_dependency \
            "Python ${GBIP_PYTHON_MIN_VERSION}+ is required but was not found."
    fi

    [[ -x "${GBIP_PYTHON_EXECUTABLE}" ]] ||
        command_exists "${GBIP_PYTHON_EXECUTABLE}" ||
        gbip_die_dependency \
            "Python executable is unavailable: ${GBIP_PYTHON_EXECUTABLE}"
}

python_command() {
    python_require
    printf '%s\n' "${GBIP_PYTHON_EXECUTABLE}"
}

# ---------------------------------------------------------------------------
# Python version
# ---------------------------------------------------------------------------

python_version() {
    python_require

    "${GBIP_PYTHON_EXECUTABLE}" -c \
        'import sys; print(".".join(map(str, sys.version_info[:3])))'
}

python_major_version() {
    python_require

    "${GBIP_PYTHON_EXECUTABLE}" -c \
        'import sys; print(sys.version_info.major)'
}

python_minor_version() {
    python_require

    "${GBIP_PYTHON_EXECUTABLE}" -c \
        'import sys; print(sys.version_info.minor)'
}

python_version_tuple() {
    python_require

    "${GBIP_PYTHON_EXECUTABLE}" -c \
        'import sys; print(" ".join(map(str, sys.version_info[:3])))'
}

python_version_at_least() {
    local required="$1"

    python_require

    "${GBIP_PYTHON_EXECUTABLE}" - "${required}" <<'PY'
import sys
import re

required = sys.argv[1]

match = re.fullmatch(r"(\d+)\.(\d+)(?:\.(\d+))?", required)
if not match:
    raise SystemExit(2)

required_version = tuple(
    int(value) if value is not None else 0
    for value in match.groups()
)

current_version = sys.version_info[:3]

raise SystemExit(0 if current_version >= required_version else 1)
PY
}

python_require_version() {
    local required="${1:-${GBIP_PYTHON_MIN_VERSION}}"

    if ! python_version_at_least "${required}"; then
        local current
        current="$(python_version)"

        gbip_die_dependency \
            "Python ${required}+ is required; found Python ${current}."
    fi
}

# ---------------------------------------------------------------------------
# Virtual environment detection
# ---------------------------------------------------------------------------

python_venv_exists() {
    [[ -f "${GBIP_VENV_DIR}/pyvenv.cfg" ]]
}

python_venv_python() {
    if [[ -x "${GBIP_VENV_DIR}/bin/python" ]]; then
        printf '%s\n' "${GBIP_VENV_DIR}/bin/python"
        return 0
    fi

    if [[ -x "${GBIP_VENV_DIR}/bin/python3" ]]; then
        printf '%s\n' "${GBIP_VENV_DIR}/bin/python3"
        return 0
    fi

    if [[ -x "${GBIP_VENV_DIR}/Scripts/python.exe" ]]; then
        printf '%s\n' "${GBIP_VENV_DIR}/Scripts/python.exe"
        return 0
    fi

    if [[ -x "${GBIP_VENV_DIR}/Scripts/python" ]]; then
        printf '%s\n' "${GBIP_VENV_DIR}/Scripts/python"
        return 0
    fi

    return 1
}

python_using_venv() {
    [[ "${GBIP_PYTHON_SOURCE}" == "venv" ]]
}

python_create_venv() {
    local system_python

    if python_venv_exists; then
        debug "Python virtual environment already exists: ${GBIP_VENV_DIR}"
        return 0
    fi

    system_python="${GBIP_PYTHON_SYSTEM:-}"

    if [[ -z "${system_python}" ]]; then
        python_resolve || gbip_die_dependency \
            "Cannot create virtual environment: Python was not found."

        system_python="${GBIP_PYTHON_EXECUTABLE}"
    fi

    info "Creating Python virtual environment: ${GBIP_VENV_DIR}"

    run "${system_python}" -m venv "${GBIP_VENV_DIR}" ||
        gbip_die_dependency \
            "Failed to create Python virtual environment."
}

python_activate_venv() {
    local venv_python

    if ! python_venv_exists; then
        return 1
    fi

    venv_python="$(python_venv_python)" || return 1

    GBIP_PYTHON_EXECUTABLE="${venv_python}"
    GBIP_PYTHON_SOURCE="venv"

    export GBIP_PYTHON_EXECUTABLE
    export GBIP_PYTHON_SOURCE

    return 0
}

python_ensure_venv() {
    python_venv_exists || python_create_venv
    python_activate_venv || gbip_die_dependency \
        "Python virtual environment exists but its interpreter could not be found."

    python_require_version
}

# ---------------------------------------------------------------------------
# Python resolution strategy
# ---------------------------------------------------------------------------

python_resolve_preferred() {
    #
    # Preferred order:
    #
    #   1. Existing GBIP virtual environment
    #   2. Explicit GBIP_PYTHON_EXECUTABLE
    #   3. GBIP_PYTHON
    #   4. System python3
    #   5. System python
    #
    # The resolver does not create a venv.
    #

    if python_venv_exists; then
        if python_activate_venv; then
            python_require_version
            return 0
        fi
    fi

    GBIP_PYTHON_EXECUTABLE=""

    python_resolve || return 1

    python_require_version

    return 0
}

python_resolve_runtime() {
    #
    # Runtime resolution used by validation/build tooling.
    #
    # If a venv exists, use it.
    # Otherwise use the system interpreter.
    #
    # This prevents validation from failing simply because .venv has not
    # been created yet.
    #

    python_resolve_preferred ||
        gbip_die_dependency \
            "Unable to resolve a usable Python ${GBIP_PYTHON_MIN_VERSION}+ interpreter."

    export GBIP_PYTHON_EXECUTABLE
    export GBIP_PYTHON_SOURCE
}

# ---------------------------------------------------------------------------
# pip detection
# ---------------------------------------------------------------------------

pip_resolve() {
    local python_cmd

    python_require
    python_cmd="${GBIP_PYTHON_EXECUTABLE}"

    if [[ -n "${GBIP_PIP_EXECUTABLE}" ]]; then
        if [[ -x "${GBIP_PIP_EXECUTABLE}" ]] ||
            command_exists "${GBIP_PIP_EXECUTABLE}"; then
            return 0
        fi
    fi

    if [[ "${GBIP_PYTHON_SOURCE}" == "venv" ]]; then
        if [[ -x "${GBIP_VENV_DIR}/bin/pip" ]]; then
            GBIP_PIP_EXECUTABLE="${GBIP_VENV_DIR}/bin/pip"
        elif [[ -x "${GBIP_VENV_DIR}/Scripts/pip.exe" ]]; then
            GBIP_PIP_EXECUTABLE="${GBIP_VENV_DIR}/Scripts/pip.exe"
        fi
    fi

    if [[ -z "${GBIP_PIP_EXECUTABLE}" ]]; then
        if "${python_cmd}" -m pip --version >/dev/null 2>&1; then
            GBIP_PIP_EXECUTABLE="${python_cmd} -m pip"
        fi
    fi

    [[ -n "${GBIP_PIP_EXECUTABLE}" ]] || return 1

    export GBIP_PIP_EXECUTABLE
}

pip_require() {
    pip_resolve || gbip_die_dependency \
        "pip is not available for Python ${GBIP_PYTHON_EXECUTABLE}."
}

pip_version() {
    pip_require

    if [[ "${GBIP_PIP_EXECUTABLE}" == *" -m pip" ]]; then
        "${GBIP_PYTHON_EXECUTABLE}" -m pip --version
    else
        "${GBIP_PIP_EXECUTABLE}" --version
    fi
}

pip_install() {
    pip_require

    if [[ "${GBIP_PIP_EXECUTABLE}" == *" -m pip" ]]; then
        run "${GBIP_PYTHON_EXECUTABLE}" -m pip "$@"
    else
        run "${GBIP_PIP_EXECUTABLE}" "$@"
    fi
}

# ---------------------------------------------------------------------------
# Package installation
# ---------------------------------------------------------------------------

python_upgrade_pip() {
    info "Upgrading pip"

    pip_install install --upgrade pip
}

python_install_requirements() {
    local requirements_file="${1:-${GBIP_REQUIREMENTS_FILE}}"

    require_file "${requirements_file}"

    info "Installing Python requirements: ${requirements_file}"

    pip_install install -r "${requirements_file}"
}

python_install_dev_requirements() {
    local requirements_file="${1:-${GBIP_DEV_REQUIREMENTS_FILE}}"

    require_file "${requirements_file}"

    info "Installing development requirements: ${requirements_file}"

    pip_install install -r "${requirements_file}"
}

python_install_all_requirements() {
    python_install_requirements

    if [[ -f "${GBIP_DEV_REQUIREMENTS_FILE}" ]]; then
        python_install_dev_requirements
    fi
}

python_install_package() {
    local package="$1"

    [[ -n "${package}" ]] ||
        gbip_die_usage "Python package name is required."

    info "Installing Python package: ${package}"

    pip_install install "${package}"
}

python_uninstall_package() {
    local package="$1"

    [[ -n "${package}" ]] ||
        gbip_die_usage "Python package name is required."

    info "Uninstalling Python package: ${package}"

    pip_install uninstall -y "${package}"
}

# ---------------------------------------------------------------------------
# Python module/tool execution
# ---------------------------------------------------------------------------

python_run() {
    python_require

    run "${GBIP_PYTHON_EXECUTABLE}" "$@"
}

python_module() {
    local module="$1"
    shift || true

    [[ -n "${module}" ]] ||
        gbip_die_usage "Python module name is required."

    python_run -m "${module}" "$@"
}

python_script() {
    local script="$1"
    shift || true

    require_file "${script}"

    python_run "${script}" "$@"
}

python_tool() {
    local tool="$1"
    shift || true

    local tool_path="${GBIP_TOOLS_DIR}/${tool}"

    require_file "${tool_path}"

    python_run "${tool_path}" "$@"
}

# ---------------------------------------------------------------------------
# Project validators
# ---------------------------------------------------------------------------

python_validate_metadata() {
    local tool="${GBIP_VALIDATE_METADATA_TOOL}"

    [[ -f "${tool}" ]] || {
        warning "Metadata validator not found: ${tool}"
        return 0
    }

    python_tool "$(basename "${tool}")"
}

python_validate_registries() {
    local tool="${GBIP_VALIDATE_REGISTRY_TOOL}"

    [[ -f "${tool}" ]] || {
        warning "Registry validator not found: ${tool}"
        return 0
    }

    python_tool "$(basename "${tool}")"
}

python_validate_schemas() {
    local tool="${GBIP_VALIDATE_SCHEMAS_TOOL}"

    [[ -f "${tool}" ]] || {
        warning "Schema validator not found: ${tool}"
        return 0
    }

    python_tool "$(basename "${tool}")"
}

python_validate_documents() {
    local tool="${GBIP_VALIDATE_DOCUMENTS_TOOL}"

    [[ -f "${tool}" ]] || {
        warning "Document validator not found: ${tool}"
        return 0
    }

    python_tool "$(basename "${tool}")"
}

python_validate_numbering() {
    local tool="${GBIP_VALIDATE_NUMBERING_TOOL}"

    [[ -f "${tool}" ]] || {
        warning "Numbering validator not found: ${tool}"
        return 0
    }

    python_tool "$(basename "${tool}")"
}

python_validate_links() {
    local tool="${GBIP_VALIDATE_LINKS_TOOL}"

    [[ -f "${tool}" ]] || {
        warning "Link validator not found: ${tool}"
        return 0
    }

    python_tool "$(basename "${tool}")"
}

# ---------------------------------------------------------------------------
# pytest
# ---------------------------------------------------------------------------

python_has_module() {
    local module="$1"

    python_require

    "${GBIP_PYTHON_EXECUTABLE}" -c \
        "import importlib.util; raise SystemExit(0 if importlib.util.find_spec('${module}') else 1)"
}

python_require_module() {
    local module="$1"

    python_has_module "${module}" ||
        gbip_die_dependency \
            "Required Python module is not installed: ${module}"
}

python_pytest_available() {
    python_has_module pytest
}

python_run_pytest() {
    python_require_module pytest

    python_module pytest "$@"
}

# ---------------------------------------------------------------------------
# Formatting / linting tools
# ---------------------------------------------------------------------------

python_tool_available() {
    local tool="$1"

    command_exists "${tool}" && return 0

    case "${tool}" in
        black|ruff|isort)
            python_has_module "${tool}"
            ;;
        *)
            return 1
            ;;
    esac
}

python_run_black() {
    python_require_module black
    python_module black "$@"
}

python_run_isort() {
    python_require_module isort
    python_module isort "$@"
}

python_run_ruff() {
    python_require_module ruff
    python_module ruff "$@"
}

python_run_ruff_check() {
    python_run_ruff check "$@"
}

python_run_ruff_format() {
    python_run_ruff format "$@"
}

# ---------------------------------------------------------------------------
# JSON / YAML helpers
# ---------------------------------------------------------------------------

python_validate_json() {
    local file="$1"

    require_file "${file}"

    python_run - "${file}" <<'PY'
import json
import sys

path = sys.argv[1]

with open(path, "r", encoding="utf-8") as handle:
    json.load(handle)

print(f"JSON OK: {path}")
PY
}

python_validate_yaml() {
    local file="$1"

    require_file "${file}"

    python_require_module yaml

    python_run - "${file}" <<'PY'
import sys
import yaml

path = sys.argv[1]

with open(path, "r", encoding="utf-8") as handle:
    yaml.safe_load(handle)

print(f"YAML OK: {path}")
PY
}

# ---------------------------------------------------------------------------
# Environment information
# ---------------------------------------------------------------------------

python_environment() {
    python_require

    header "Python Environment"

    printf "Executable : %s\n" "${GBIP_PYTHON_EXECUTABLE}"
    printf "Source     : %s\n" "${GBIP_PYTHON_SOURCE}"
    printf "Version    : %s\n" "$(python_version)"

    if pip_resolve; then
        printf "pip        : %s\n" "${GBIP_PIP_EXECUTABLE}"
    else
        printf "pip        : unavailable\n"
    fi

    if python_venv_exists; then
        printf "Virtualenv : %s\n" "${GBIP_VENV_DIR}"
    else
        printf "Virtualenv : not created\n"
    fi
}

python_print_environment() {
    python_environment
}

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

python_init() {
    #
    # Resolve an interpreter without creating anything.
    #
    python_resolve_runtime

    if [[ "${GBIP_PYTHON_UPGRADE_PIP}" -eq 1 ]]; then
        python_upgrade_pip
    fi
}

python_init_venv() {
    python_ensure_venv

    if [[ "${GBIP_PYTHON_UPGRADE_PIP}" -eq 1 ]]; then
        python_upgrade_pip
    fi
}

# ---------------------------------------------------------------------------
# Compatibility exports
# ---------------------------------------------------------------------------

# validation.sh and older scripts may expect GBIP_PYTHON to point at the
# actual interpreter. Keep it synchronized after initialization.

python_export_legacy_variables() {
    if [[ -n "${GBIP_PYTHON_EXECUTABLE}" ]]; then
        GBIP_PYTHON="${GBIP_PYTHON_EXECUTABLE}"
        export GBIP_PYTHON
    fi

    if [[ -n "${GBIP_PIP_EXECUTABLE}" ]]; then
        export GBIP_PIP_EXECUTABLE
    fi
}

# ---------------------------------------------------------------------------
# Automatic lightweight initialization
# ---------------------------------------------------------------------------
#
# Do not create .venv here.
#
# This is intentionally safe for scripts such as:
#
#   validate.sh
#   lint.sh
#   build.sh
#
# They can use the system Python when no virtual environment exists.
#

python_init
python_export_legacy_variables