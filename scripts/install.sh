#!/usr/bin/env bash
#
# install.sh
#
# GBIP Repository Installation Script
#

set -Eeuo pipefail

###############################################################################
# Configuration
###############################################################################

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VENV_DIR="${ROOT_DIR}/.venv"

PYTHON="${PYTHON:-python3}"

REQUIREMENTS="${ROOT_DIR}/requirements.txt"

DEV_REQUIREMENTS="${ROOT_DIR}/requirements-dev.txt"

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
# Verify Required Commands
###############################################################################

require_command() {

    if ! command -v "$1" >/dev/null 2>&1; then
        error "Missing required command: $1"
        exit 1
    fi

}

info "Checking required tools..."

require_command git
require_command "${PYTHON}"
require_command pip3

success "System requirements satisfied."

###############################################################################
# Repository
###############################################################################

cd "${ROOT_DIR}"

###############################################################################
# Create Virtual Environment
###############################################################################

if [ ! -d "${VENV_DIR}" ]; then

    info "Creating Python virtual environment..."

    "${PYTHON}" -m venv "${VENV_DIR}"

fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

###############################################################################
# Upgrade Packaging Tools
###############################################################################

info "Upgrading pip..."

python -m pip install \
    --upgrade \
    pip \
    setuptools \
    wheel

###############################################################################
# Install Runtime Requirements
###############################################################################

if [ -f "${REQUIREMENTS}" ]; then

    info "Installing runtime dependencies..."

    pip install -r "${REQUIREMENTS}"

else

    warning "requirements.txt not found."

fi

###############################################################################
# Install Development Requirements
###############################################################################

if [ -f "${DEV_REQUIREMENTS}" ]; then

    info "Installing development dependencies..."

    pip install -r "${DEV_REQUIREMENTS}"

fi

###############################################################################
# Install Git Hooks
###############################################################################

if [ -d ".git" ]; then

    info "Installing Git hooks..."

    mkdir -p .githooks

    git config core.hooksPath .githooks

fi

###############################################################################
# Optional Development Tools
###############################################################################

if command -v npm >/dev/null 2>&1; then

    info "Installing Markdown tooling..."

    npm install

else

    warning "npm not found. Markdown tools skipped."

fi

###############################################################################
# Verify Installation
###############################################################################

echo
echo "Installed Tool Versions"

python --version
pip --version
git --version

###############################################################################
# Repository Bootstrap
###############################################################################

if [ -x "./scripts/bootstrap.sh" ]; then

    info "Running bootstrap..."

    ./scripts/bootstrap.sh

fi

###############################################################################
# Summary
###############################################################################

echo
echo "========================================"
echo "GBIP Installation Complete"
echo "========================================"

echo "Repository : ${ROOT_DIR}"
echo "Python     : $(python --version)"
echo "Virtualenv : ${VENV_DIR}"

echo "========================================"

success "Installation completed successfully."