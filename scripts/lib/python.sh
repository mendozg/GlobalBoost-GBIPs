#!/usr/bin/env bash
GBIP_PYTHON_EXECUTABLE="${GBIP_PYTHON_EXECUTABLE:-}"
GBIP_PYTHON_SOURCE="${GBIP_PYTHON_SOURCE:-}"
python_resolve() {
    if [[ -n "${GBIP_PYTHON_EXECUTABLE}" ]] && command_exists "${GBIP_PYTHON_EXECUTABLE}"; then printf '%s\n' "${GBIP_PYTHON_EXECUTABLE}"; return; fi
    if [[ -x "${GBIP_VENV_DIR}/bin/python" ]]; then printf '%s\n' "${GBIP_VENV_DIR}/bin/python"; return; fi
    if [[ -x "${GBIP_VENV_DIR}/Scripts/python.exe" ]]; then printf '%s\n' "${GBIP_VENV_DIR}/Scripts/python.exe"; return; fi
    command_exists python3 && { printf 'python3\n'; return; }
    command_exists python && { printf 'python\n'; return; }
    return 1
}
python_exec() { local p; p="$(python_resolve)" || gbip_die_dependency "Python 3 not found."; "$p" "$@"; }
python_version() { python_exec --version 2>&1; }
python_require_version() { [[ "$(python_exec -c 'import sys; print(sys.version_info[0])')" == 3 ]] || gbip_die_dependency "Python 3 is required."; }
python_pip() { python_exec -m pip "$@"; }
python_ensure_venv() { [[ -x "${GBIP_VENV_DIR}/bin/python" || -x "${GBIP_VENV_DIR}/Scripts/python.exe" ]] || python_exec -m venv "${GBIP_VENV_DIR}"; }
python_install_requirements() { local f="$1"; require_file "$f"; python_pip install -r "$f"; }
python_run_tool() { local t="$1"; shift; require_file "$t"; python_exec "$t" "$@"; }
python_pytest() { python_exec -m pytest "$@"; }
python_ruff() { python_exec -m ruff "$@"; }
python_black() { python_exec -m black "$@"; }
python_isort() { python_exec -m isort "$@"; }
python_validate_json() { local f="$1"; python_exec -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$f"; }
