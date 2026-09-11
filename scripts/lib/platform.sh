#!/usr/bin/env bash
GBIP_OS="unknown"
case "$(uname -s 2>/dev/null || printf unknown)" in
    Linux*) GBIP_OS="linux" ;;
    Darwin*) GBIP_OS="macos" ;;
    MINGW*|MSYS*|CYGWIN*) GBIP_OS="windows" ;;
esac
GBIP_ARCH="$(uname -m 2>/dev/null || printf unknown)"
platform_is_linux() { [[ "${GBIP_OS}" == linux ]]; }
platform_is_macos() { [[ "${GBIP_OS}" == macos ]]; }
platform_is_windows() { [[ "${GBIP_OS}" == windows ]]; }
platform_is_ci() { [[ "${GBIP_CI:-0}" == 1 || "${CI:-}" == true ]]; }
platform_temp_dir() { printf '%s\n' "${TMPDIR:-${TEMP:-${TMP:-/tmp}}}"; }
