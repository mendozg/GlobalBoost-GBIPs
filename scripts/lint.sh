#!/usr/bin/env bash
#
# lint.sh
#
# GBIP Repository Linting Script
#

set -Eeuo pipefail

###############################################################################
# Configuration
###############################################################################

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

EXIT_CODE=0

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

failure() {
    printf "\033[1;31m[FAILED]\033[0m %s\n" "$*"
}

###############################################################################
# Repository
###############################################################################

cd "${ROOT_DIR}"

echo
echo "========================================"
echo "GBIP Repository Lint"
echo "========================================"

###############################################################################
# Markdown Lint
###############################################################################

if command -v markdownlint >/dev/null 2>&1; then

    info "Linting Markdown..."

    if markdownlint "**/*.md"; then
        success "Markdown passed."
    else
        failure "Markdown lint failed."
        EXIT_CODE=1
    fi

else

    warning "markdownlint not installed."

fi

###############################################################################
# YAML Lint
###############################################################################

if command -v yamllint >/dev/null 2>&1; then

    info "Linting YAML..."

    if yamllint .; then
        success "YAML passed."
    else
        failure "YAML lint failed."
        EXIT_CODE=1
    fi

else

    warning "yamllint not installed."

fi

###############################################################################
# JSON Validation
###############################################################################

if command -v jq >/dev/null 2>&1; then

    info "Checking JSON..."

    while IFS= read -r FILE
    do
        if ! jq empty "${FILE}" >/dev/null 2>&1; then
            failure "Invalid JSON: ${FILE}"
            EXIT_CODE=1
        fi
    done < <(find . -type f -name "*.json")

    success "JSON syntax verified."

else

    warning "jq not installed."

fi

###############################################################################
# ShellCheck
###############################################################################

if command -v shellcheck >/dev/null 2>&1; then

    info "Linting shell scripts..."

    while IFS= read -r FILE
    do
        shellcheck "${FILE}"
    done < <(find scripts -type f -name "*.sh")

    success "Shell scripts passed."

else

    warning "shellcheck not installed."

fi

###############################################################################
# Python Lint (Ruff)
###############################################################################

if command -v ruff >/dev/null 2>&1; then

    info "Linting Python..."

    ruff check tools tests

    success "Python passed."

else

    warning "ruff not installed."

fi

###############################################################################
# Python Formatting Check (Black)
###############################################################################

if command -v black >/dev/null 2>&1; then

    info "Checking Python formatting..."

    black --check tools tests

    success "Formatting passed."

else

    warning "black not installed."

fi

###############################################################################
# Git Whitespace Checks
###############################################################################

if command -v git >/dev/null 2>&1 && [ -d ".git" ]; then

    info "Checking whitespace..."

    if git diff --check; then
        success "Whitespace check passed."
    else
        failure "Whitespace errors found."
        EXIT_CODE=1
    fi

fi

###############################################################################
# Summary
###############################################################################

echo
echo "========================================"

if [ "${EXIT_CODE}" -eq 0 ]; then
    success "Lint completed successfully."
else
    failure "Lint completed with errors."
fi

echo "========================================"

exit "${EXIT_CODE}"