#!/usr/bin/env bash
GBIP_COLORS_ENABLED="${GBIP_COLORS_ENABLED:-0}"
colors_enabled() { [[ "${GBIP_COLORS_ENABLED}" == "1" ]]; }
refresh_colors() {
    if colors_enabled; then
        COLOR_RESET=$'\033[0m'; COLOR_RED=$'\033[31m'; COLOR_GREEN=$'\033[32m'
        COLOR_YELLOW=$'\033[33m'; COLOR_BLUE=$'\033[34m'; COLOR_MAGENTA=$'\033[35m'
        COLOR_CYAN=$'\033[36m'; COLOR_WHITE=$'\033[37m'; COLOR_BOLD=$'\033[1m'
    else
        COLOR_RESET=''; COLOR_RED=''; COLOR_GREEN=''; COLOR_YELLOW=''; COLOR_BLUE=''
        COLOR_MAGENTA=''; COLOR_CYAN=''; COLOR_WHITE=''; COLOR_BOLD=''
    fi
}
enable_colors() { GBIP_COLORS_ENABLED=1; refresh_colors; }
disable_colors() { GBIP_COLORS_ENABLED=0; refresh_colors; }
if [[ -n "${NO_COLOR:-}" || "${CI:-}" == "true" ]]; then disable_colors
elif [[ -t 1 ]]; then enable_colors
else disable_colors
fi
