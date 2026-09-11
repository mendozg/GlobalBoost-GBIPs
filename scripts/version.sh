#!/usr/bin/env bash
#
# version.sh
#
# GBIP Repository Version Manager
#

set -Eeuo pipefail

###############################################################################
# Configuration
###############################################################################

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VERSION_FILE="${ROOT_DIR}/VERSION"

NEW_VERSION="${1:-}"

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

error() {
    printf "\033[1;31m[ERROR]\033[0m %s\n" "$*"
}

###############################################################################
# Validate Input
###############################################################################

if [[ -z "${NEW_VERSION}" ]]; then
    error "Usage: version.sh <semantic-version>"
    exit 1
fi

if ! [[ "${NEW_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9]+)*$ ]]; then
    error "Invalid Semantic Version: ${NEW_VERSION}"
    exit 1
fi

###############################################################################
# Repository
###############################################################################

cd "${ROOT_DIR}"

echo
echo "========================================"
echo "GBIP Version Manager"
echo "========================================"

###############################################################################
# Update VERSION File
###############################################################################

info "Updating VERSION..."

echo "${NEW_VERSION}" > "${VERSION_FILE}"

###############################################################################
# Update Markdown Files
###############################################################################

info "Updating Markdown documents..."

find . \
    -type f \
    -name "*.md" \
    -exec sed -i \
    -E "s/version: [0-9]+\.[0-9]+\.[0-9]+/version: ${NEW_VERSION}/g" {} +

###############################################################################
# Update JSON Schemas
###############################################################################

info "Updating JSON schemas..."

find schemas \
    -type f \
    -name "*.json" \
    -exec sed -i \
    -E "s/\"version\": *\"[^\"]+\"/\"version\": \"${NEW_VERSION}\"/g" {} +

###############################################################################
# Update Registry Files
###############################################################################

if [ -d registry ]; then

    info "Updating registries..."

    find registry \
        -type f \
        \( -name "*.yaml" -o -name "*.yml" \) \
        -exec sed -i \
        -E "s/version: [0-9]+\.[0-9]+\.[0-9]+/version: ${NEW_VERSION}/g" {} +

fi

###############################################################################
# Update CHANGELOG
###############################################################################

if [ -f CHANGELOG.md ]; then

    info "Updating CHANGELOG..."

    DATE="$(date +%Y-%m-%d)"

    sed -i \
        "1a\\
## ${NEW_VERSION} (${DATE})\\
- Repository version updated.\\
" CHANGELOG.md

fi

###############################################################################
# Git Tag Information
###############################################################################

if git rev-parse --git-dir >/dev/null 2>&1; then

    info "Suggested Git commands:"

    echo
    echo "git add ."
    echo "git commit -m \"Release v${NEW_VERSION}\""
    echo "git tag -a v${NEW_VERSION} -m \"GBIP ${NEW_VERSION}\""
    echo "git push origin main --tags"
    echo

fi

###############################################################################
# Summary
###############################################################################

echo "========================================"

success "Repository updated to version ${NEW_VERSION}"

echo "VERSION : ${NEW_VERSION}"

echo "========================================"