#!/usr/bin/env bash
#
# format.sh
#
# GBIP Repository Formatting Script
#

set -Eeuo pipefail

###############################################################################
# Configuration
###############################################################################

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

###############################################################################
# Logging
###############################################################################

info() {
    printf "\033[1;34m[INFO]\033[0m %s\n" "$*"
}

success() {
    printf "\033[1;32m[SUCCESS]\033[0m %s\n" "$*"
}

warning() {
    printf "\033[1;33m[WARNING]\033[0m %s\n" "$*"
}

###############################################################################
# Repository
###############################################################################

cd "${ROOT_DIR}"

echo
echo "========================================"
echo "GBIP Repository Formatter"
echo "========================================"

###############################################################################
# Format Python
###############################################################################

if command -v black >/dev/null 2>&1; then

    info "Formatting Python..."

    if [ -d tools ]; then
        black tools
    fi

    if [ -d tests ]; then
        black tests
    fi

    success "Python formatted."

else

    warning "black not installed."

fi

###############################################################################
# Sort Python Imports
###############################################################################

if command -v isort >/dev/null 2>&1; then

    info "Sorting Python imports..."

    [ -d tools ] && isort tools
    [ -d tests ] && isort tests

    success "Imports sorted."

else

    warning "isort not installed."

fi

###############################################################################
# Format Shell Scripts
###############################################################################

if command -v shfmt >/dev/null 2>&1; then

    info "Formatting shell scripts..."

    find scripts -type f -name "*.sh" -exec shfmt -w {} +

    success "Shell scripts formatted."

else

    warning "shfmt not installed."

fi

###############################################################################
# Format JSON
###############################################################################

if command -v jq >/dev/null 2>&1; then

    info "Formatting JSON..."

    while IFS= read -r FILE
    do
        TMP="$(mktemp)"
        jq . "${FILE}" > "${TMP}"
        mv "${TMP}" "${FILE}"
    done < <(find . -type f -name "*.json")

    success "JSON formatted."

else

    warning "jq not installed."

fi

###############################################################################
# Format YAML
###############################################################################

if command -v prettier >/dev/null 2>&1; then

    info "Formatting YAML..."

    prettier --write "**/*.{yaml,yml}"

    success "YAML formatted."

else

    warning "prettier not installed."

fi

###############################################################################
# Format Markdown
###############################################################################

if command -v prettier >/dev/null 2>&1; then

    info "Formatting Markdown..."

    prettier --write "**/*.md"

    success "Markdown formatted."

else

    warning "prettier not installed."

fi

###############################################################################
# Normalize Line Endings
###############################################################################

if command -v dos2unix >/dev/null 2>&1; then

    info "Normalizing line endings..."

    find . \
        -type f \
        \( -name "*.md" \
        -o -name "*.json" \
        -o -name "*.yaml" \
        -o -name "*.yml" \
        -o -name "*.sh" \
        -o -name "*.py" \) \
        -exec dos2unix {} + >/dev/null 2>&1

    success "Line endings normalized."

else

    warning "dos2unix not installed."

fi

###############################################################################
# Remove Trailing Whitespace
###############################################################################

info "Removing trailing whitespace..."

find . \
    -type f \
    \( -name "*.md" \
    -o -name "*.json" \
    -o -name "*.yaml" \
    -o -name "*.yml" \
    -o -name "*.py" \
    -o -name "*.sh" \) \
    -exec sed -i 's/[[:space:]]*$//' {} +

success "Trailing whitespace removed."

###############################################################################
# Summary
###############################################################################

echo
echo "========================================"
success "Formatting completed successfully."
echo "========================================"