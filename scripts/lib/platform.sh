#!/usr/bin/env bash
#
# platform.sh
#
# Platform abstraction layer for the GBIP shell framework.
#
# Supports:
#   - Linux
#   - macOS
#   - Windows / Git Bash
#   - MSYS2
#   - Cygwin
#
# Responsibilities:
#   - Detect operating system
#   - Detect shell/environment
#   - Detect CPU architecture
#   - Resolve platform-specific executables
#   - Provide platform-safe commands
#   - Handle path conversion where necessary
#   - Detect archive/checksum utilities
#   - Provide CI platform information
#
# Other GBIP modules should use these functions instead of embedding
# operating-system-specific logic.
#

[[ -n "${GBIP_PLATFORM_LOADED:-}" ]] && return
readonly GBIP_PLATFORM_LOADED=1

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

SCRIPT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_LIB_DIR}/config.sh"
source "${SCRIPT_LIB_DIR}/common.sh"

# ---------------------------------------------------------------------------
# Platform state
# ---------------------------------------------------------------------------

GBIP_PLATFORM_OS="${GBIP_PLATFORM_OS:-}"
GBIP_PLATFORM_ARCH="${GBIP_PLATFORM_ARCH:-}"
GBIP_PLATFORM_SHELL="${GBIP_PLATFORM_SHELL:-}"

GBIP_PLATFORM_IS_WINDOWS="${GBIP_PLATFORM_IS_WINDOWS:-0}"
GBIP_PLATFORM_IS_LINUX="${GBIP_PLATFORM_IS_LINUX:-0}"
GBIP_PLATFORM_IS_MACOS="${GBIP_PLATFORM_IS_MACOS:-0}"
GBIP_PLATFORM_IS_BSD="${GBIP_PLATFORM_IS_BSD:-0}"

GBIP_PLATFORM_IS_GIT_BASH="${GBIP_PLATFORM_IS_GIT_BASH:-0}"
GBIP_PLATFORM_IS_MSYS="${GBIP_PLATFORM_IS_MSYS:-0}"
GBIP_PLATFORM_IS_CYGWIN="${GBIP_PLATFORM_IS_CYGWIN:-0}"

GBIP_PLATFORM_IS_CI="${GBIP_PLATFORM_IS_CI:-0}"

# ---------------------------------------------------------------------------
# OS detection
# ---------------------------------------------------------------------------

platform_detect_os() {
    local uname_s

    uname_s="$(uname -s 2>/dev/null || true)"

    case "${uname_s}" in
        Linux*)
            GBIP_PLATFORM_OS="linux"
            GBIP_PLATFORM_IS_LINUX=1
            ;;

        Darwin*)
            GBIP_PLATFORM_OS="macos"
            GBIP_PLATFORM_IS_MACOS=1
            ;;

        FreeBSD*)
            GBIP_PLATFORM_OS="freebsd"
            GBIP_PLATFORM_IS_BSD=1
            ;;

        OpenBSD*)
            GBIP_PLATFORM_OS="openbsd"
            GBIP_PLATFORM_IS_BSD=1
            ;;

        NetBSD*)
            GBIP_PLATFORM_OS="netbsd"
            GBIP_PLATFORM_IS_BSD=1
            ;;

        MINGW*)
            GBIP_PLATFORM_OS="windows"
            GBIP_PLATFORM_IS_WINDOWS=1
            GBIP_PLATFORM_IS_GIT_BASH=1
            ;;

        MSYS*)
            GBIP_PLATFORM_OS="windows"
            GBIP_PLATFORM_IS_WINDOWS=1
            GBIP_PLATFORM_IS_MSYS=1
            ;;

        CYGWIN*)
            GBIP_PLATFORM_OS="windows"
            GBIP_PLATFORM_IS_WINDOWS=1
            GBIP_PLATFORM_IS_CYGWIN=1
            ;;

        *)
            if [[ "${OS:-}" == "Windows_NT" ]]; then
                GBIP_PLATFORM_OS="windows"
                GBIP_PLATFORM_IS_WINDOWS=1
            else
                GBIP_PLATFORM_OS="unknown"
            fi
            ;;
    esac

    export GBIP_PLATFORM_OS
}

# ---------------------------------------------------------------------------
# Architecture detection
# ---------------------------------------------------------------------------

platform_detect_arch() {
    local machine

    machine="$(uname -m 2>/dev/null || true)"

    case "${machine}" in
        x86_64|amd64)
            GBIP_PLATFORM_ARCH="x86_64"
            ;;

        i386|i486|i586|i686|x86)
            GBIP_PLATFORM_ARCH="x86"
            ;;

        aarch64|arm64)
            GBIP_PLATFORM_ARCH="aarch64"
            ;;

        armv7*|armv6*)
            GBIP_PLATFORM_ARCH="arm"
            ;;

        ppc64le)
            GBIP_PLATFORM_ARCH="ppc64le"
            ;;

        ppc64)
            GBIP_PLATFORM_ARCH="ppc64"
            ;;

        riscv64)
            GBIP_PLATFORM_ARCH="riscv64"
            ;;

        *)
            GBIP_PLATFORM_ARCH="${machine:-unknown}"
            ;;
    esac

    export GBIP_PLATFORM_ARCH
}

# ---------------------------------------------------------------------------
# Shell detection
# ---------------------------------------------------------------------------

platform_detect_shell() {
    local shell_name

    shell_name="$(basename "${SHELL:-bash}")"

    case "${shell_name}" in
        bash)
            GBIP_PLATFORM_SHELL="bash"
            ;;

        zsh)
            GBIP_PLATFORM_SHELL="zsh"
            ;;

        fish)
            GBIP_PLATFORM_SHELL="fish"
            ;;

        sh)
            GBIP_PLATFORM_SHELL="sh"
            ;;

        *)
            GBIP_PLATFORM_SHELL="${shell_name}"
            ;;
    esac

    export GBIP_PLATFORM_SHELL
}

# ---------------------------------------------------------------------------
# CI detection
# ---------------------------------------------------------------------------

platform_detect_ci() {
    if [[ -n "${CI:-}" ]]; then
        GBIP_PLATFORM_IS_CI=1
    elif [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        GBIP_PLATFORM_IS_CI=1
    else
        GBIP_PLATFORM_IS_CI=0
    fi

    export GBIP_PLATFORM_IS_CI
}

platform_is_ci() {
    [[ "${GBIP_PLATFORM_IS_CI}" -eq 1 ]]
}

# ---------------------------------------------------------------------------
# Platform predicates
# ---------------------------------------------------------------------------

platform_is_windows() {
    [[ "${GBIP_PLATFORM_IS_WINDOWS}" -eq 1 ]]
}

platform_is_linux() {
    [[ "${GBIP_PLATFORM_IS_LINUX}" -eq 1 ]]
}

platform_is_macos() {
    [[ "${GBIP_PLATFORM_IS_MACOS}" -eq 1 ]]
}

platform_is_bsd() {
    [[ "${GBIP_PLATFORM_IS_BSD}" -eq 1 ]]
}

platform_is_git_bash() {
    [[ "${GBIP_PLATFORM_IS_GIT_BASH}" -eq 1 ]]
}

platform_is_msys() {
    [[ "${GBIP_PLATFORM_IS_MSYS}" -eq 1 ]]
}

platform_is_cygwin() {
    [[ "${GBIP_PLATFORM_IS_CYGWIN}" -eq 1 ]]
}

# ---------------------------------------------------------------------------
# Platform name
# ---------------------------------------------------------------------------

platform_name() {
    printf '%s\n' "${GBIP_PLATFORM_OS}"
}

platform_arch() {
    printf '%s\n' "${GBIP_PLATFORM_ARCH}"
}

platform_shell() {
    printf '%s\n' "${GBIP_PLATFORM_SHELL}"
}

# ---------------------------------------------------------------------------
# Executable suffix
# ---------------------------------------------------------------------------

platform_executable_suffix() {
    if platform_is_windows; then
        printf '%s\n' ".exe"
    else
        printf '%s\n' ""
    fi
}

# ---------------------------------------------------------------------------
# Executable resolution
# ---------------------------------------------------------------------------

platform_find_executable() {
    local name="$1"

    [[ -n "${name}" ]] || return 1

    if command_exists "${name}"; then
        command -v "${name}"
        return 0
    fi

    if platform_is_windows && [[ "${name}" != *.exe ]]; then
        if command_exists "${name}.exe"; then
            command -v "${name}.exe"
            return 0
        fi
    fi

    return 1
}

platform_require_executable() {
    local name="$1"

    platform_find_executable "${name}" >/dev/null ||
        gbip_die_dependency \
            "Required executable not found: ${name}"
}

# ---------------------------------------------------------------------------
# Path conversion
# ---------------------------------------------------------------------------

platform_path_convert() {
    local path="$1"

    [[ -n "${path}" ]] || return 1

    if platform_is_windows; then
        if command_exists cygpath; then
            cygpath -m "${path}"
            return 0
        fi
    fi

    printf '%s\n' "${path}"
}

platform_path_native() {
    local path="$1"

    [[ -n "${path}" ]] || return 1

    if platform_is_windows && command_exists cygpath; then
        cygpath -w "${path}"
        return 0
    fi

    printf '%s\n' "${path}"
}

# ---------------------------------------------------------------------------
# Home directory
# ---------------------------------------------------------------------------

platform_home() {
    if [[ -n "${HOME:-}" ]]; then
        printf '%s\n' "${HOME}"
        return 0
    fi

    if [[ -n "${USERPROFILE:-}" ]]; then
        printf '%s\n' "${USERPROFILE}"
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# Temporary directory
# ---------------------------------------------------------------------------

platform_temp_dir() {
    if [[ -n "${TMPDIR:-}" ]]; then
        printf '%s\n' "${TMPDIR}"
        return 0
    fi

    if [[ -n "${TEMP:-}" ]]; then
        printf '%s\n' "${TEMP}"
        return 0
    fi

    if [[ -n "${TMP:-}" ]]; then
        printf '%s\n' "${TMP}"
        return 0
    fi

    printf '%s\n' "/tmp"
}

# ---------------------------------------------------------------------------
# CPU count
# ---------------------------------------------------------------------------

platform_cpu_count() {
    if command_exists nproc; then
        nproc
        return 0
    fi

    if command_exists getconf; then
        getconf _NPROCESSORS_ONLN
        return 0
    fi

    if platform_is_windows && command_exists powershell.exe; then
        powershell.exe -NoProfile -Command \
            '[Environment]::ProcessorCount'
        return 0
    fi

    printf '%s\n' "1"
}

# ---------------------------------------------------------------------------
# Memory information
# ---------------------------------------------------------------------------

platform_memory_mb() {
    if platform_is_linux && [[ -f /proc/meminfo ]]; then
        awk '/MemTotal:/ { printf "%d\n", $2 / 1024; exit }' \
            /proc/meminfo
        return 0
    fi

    if platform_is_macos && command_exists sysctl; then
        sysctl -n hw.memsize | awk '{ printf "%d\n", $1 / 1024 / 1024 }'
        return 0
    fi

    if platform_is_windows && command_exists powershell.exe; then
        powershell.exe -NoProfile -Command \
            '[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB)'
        return 0
    fi

    printf '%s\n' "0"
}

# ---------------------------------------------------------------------------
# Archive tools
# ---------------------------------------------------------------------------

platform_has_zip() {
    command_exists zip
}

platform_has_unzip() {
    command_exists unzip
}

platform_has_tar() {
    command_exists tar
}

platform_has_7zip() {
    command_exists 7z || command_exists 7zz
}

platform_archive_tool() {
    if platform_has_zip; then
        printf '%s\n' "zip"
        return 0
    fi

    if platform_has_7zip; then
        if command_exists 7z; then
            printf '%s\n' "7z"
        else
            printf '%s\n' "7zz"
        fi
        return 0
    fi

    if platform_has_tar; then
        printf '%s\n' "tar"
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# Checksum tools
# ---------------------------------------------------------------------------

platform_has_sha256sum() {
    command_exists sha256sum
}

platform_has_shasum() {
    command_exists shasum
}

platform_has_certutil() {
    command_exists certutil
}

platform_checksum_tool() {
    if platform_has_sha256sum; then
        printf '%s\n' "sha256sum"
        return 0
    fi

    if platform_has_shasum; then
        printf '%s\n' "shasum"
        return 0
    fi

    if platform_has_certutil; then
        printf '%s\n' "certutil"
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# Shell utilities
# ---------------------------------------------------------------------------

platform_has_bash() {
    command_exists bash
}

platform_has_shellcheck() {
    command_exists shellcheck
}

platform_has_shfmt() {
    command_exists shfmt
}

# ---------------------------------------------------------------------------
# Line-ending helpers
# ---------------------------------------------------------------------------

platform_has_dos2unix() {
    command_exists dos2unix
}

platform_has_unix2dos() {
    command_exists unix2dos
}

platform_normalize_line_endings() {
    local file="$1"

    require_file "${file}"

    if platform_has_dos2unix; then
        run dos2unix "${file}"
        return $?
    fi

    #
    # Python fallback.
    #
    if command_exists python3; then
        run python3 - "${file}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])

data = path.read_bytes()
data = data.replace(b"\r\n", b"\n")
data = data.replace(b"\r", b"\n")

path.write_bytes(data)
PY
        return $?
    fi

    warning "Unable to normalize line endings: ${file}"
    return 1
}

# ---------------------------------------------------------------------------
# File opening
# ---------------------------------------------------------------------------

platform_open_file() {
    local file="$1"

    require_file "${file}"

    if platform_is_windows; then
        if command_exists cmd.exe; then
            run cmd.exe /c start "" \
                "$(platform_path_native "${file}")"
            return $?
        fi
    fi

    if platform_is_macos && command_exists open; then
        run open "${file}"
        return $?
    fi

    if platform_is_linux && command_exists xdg-open; then
        run xdg-open "${file}"
        return $?
    fi

    warning "No platform file opener available."
    return 1
}

# ---------------------------------------------------------------------------
# Environment information
# ---------------------------------------------------------------------------

platform_environment() {
    header "Platform Environment"

    printf "OS           : %s\n" "${GBIP_PLATFORM_OS}"
    printf "Architecture : %s\n" "${GBIP_PLATFORM_ARCH}"
    printf "Shell        : %s\n" "${GBIP_PLATFORM_SHELL}"
    printf "CI           : %s\n" "${GBIP_PLATFORM_IS_CI}"
    printf "Git Bash     : %s\n" "${GBIP_PLATFORM_IS_GIT_BASH}"
    printf "MSYS         : %s\n" "${GBIP_PLATFORM_IS_MSYS}"
    printf "Cygwin       : %s\n" "${GBIP_PLATFORM_IS_CYGWIN}"
    printf "CPU cores    : %s\n" "$(platform_cpu_count)"
    printf "Memory MB    : %s\n" "$(platform_memory_mb)"
    printf "Home         : %s\n" "$(platform_home || printf '%s' 'unknown')"
    printf "Temp         : %s\n" "$(platform_temp_dir)"

    printf "\nTools:\n"

    if platform_has_zip; then
        printf "  zip        : yes\n"
    else
        printf "  zip        : no\n"
    fi

    if platform_has_unzip; then
        printf "  unzip      : yes\n"
    else
        printf "  unzip      : no\n"
    fi

    if platform_has_tar; then
        printf "  tar        : yes\n"
    else
        printf "  tar        : no\n"
    fi

    if platform_has_7zip; then
        printf "  7-Zip      : yes\n"
    else
        printf "  7-Zip      : no\n"
    fi

    if platform_checksum_tool >/dev/null 2>&1; then
        printf "  SHA-256    : %s\n" "$(platform_checksum_tool)"
    else
        printf "  SHA-256    : unavailable\n"
    fi
}

# ---------------------------------------------------------------------------
# Platform-specific Git Bash handling
# ---------------------------------------------------------------------------

platform_git_bash_warning() {
    if platform_is_git_bash; then
        warning "Running under Windows Git Bash."
        warning "Use POSIX-style paths for GBIP shell scripts."
    fi
}

# ---------------------------------------------------------------------------
# Platform initialization
# ---------------------------------------------------------------------------

platform_init() {
    platform_detect_os
    platform_detect_arch
    platform_detect_shell
    platform_detect_ci
}

platform_init