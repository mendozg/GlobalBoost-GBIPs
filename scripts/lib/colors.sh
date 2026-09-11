#!/usr/bin/env bash
#
# colors.sh
#
# ANSI color definitions for the GBIP shell framework.
#
# Supports:
#   - Automatic terminal detection
#   - NO_COLOR environment variable
#   - FORCE_COLOR environment variable
#   - CI environments
#

# Prevent multiple inclusion
[[ -n "${GBIP_COLORS_LOADED:-}" ]] && return
readonly GBIP_COLORS_LOADED=1

###############################################################################
# Color Detection
###############################################################################

GBIP_COLOR_ENABLED=1

# Disable if output is not a terminal
if [[ ! -t 1 ]]; then
    GBIP_COLOR_ENABLED=0
fi

# Disable in CI unless explicitly forced
if [[ -n "${CI:-}" ]]; then
    GBIP_COLOR_ENABLED=0
fi

# Honor NO_COLOR standard
if [[ -n "${NO_COLOR:-}" ]]; then
    GBIP_COLOR_ENABLED=0
fi

# Force colors if requested
if [[ -n "${FORCE_COLOR:-}" ]]; then
    GBIP_COLOR_ENABLED=1
fi

###############################################################################
# ANSI Colors
###############################################################################

if [[ "${GBIP_COLOR_ENABLED}" -eq 1 ]]; then

    readonly RESET="\033[0m"

    readonly BOLD="\033[1m"
    readonly DIM="\033[2m"
    readonly UNDERLINE="\033[4m"

    readonly BLACK="\033[30m"
    readonly RED="\033[31m"
    readonly GREEN="\033[32m"
    readonly YELLOW="\033[33m"
    readonly BLUE="\033[34m"
    readonly MAGENTA="\033[35m"
    readonly CYAN="\033[36m"
    readonly WHITE="\033[37m"

    readonly BRIGHT_BLACK="\033[90m"
    readonly BRIGHT_RED="\033[91m"
    readonly BRIGHT_GREEN="\033[92m"
    readonly BRIGHT_YELLOW="\033[93m"
    readonly BRIGHT_BLUE="\033[94m"
    readonly BRIGHT_MAGENTA="\033[95m"
    readonly BRIGHT_CYAN="\033[96m"
    readonly BRIGHT_WHITE="\033[97m"

else

    readonly RESET=""

    readonly BOLD=""
    readonly DIM=""
    readonly UNDERLINE=""

    readonly BLACK=""
    readonly RED=""
    readonly GREEN=""
    readonly YELLOW=""
    readonly BLUE=""
    readonly MAGENTA=""
    readonly CYAN=""
    readonly WHITE=""

    readonly BRIGHT_BLACK=""
    readonly BRIGHT_RED=""
    readonly BRIGHT_GREEN=""
    readonly BRIGHT_YELLOW=""
    readonly BRIGHT_BLUE=""
    readonly BRIGHT_MAGENTA=""
    readonly BRIGHT_CYAN=""
    readonly BRIGHT_WHITE=""

fi

###############################################################################
# Helper Functions
###############################################################################

enable_colors() {
    GBIP_COLOR_ENABLED=1
}

disable_colors() {
    GBIP_COLOR_ENABLED=0
}

colors_enabled() {
    [[ "${GBIP_COLOR_ENABLED}" -eq 1 ]]
}