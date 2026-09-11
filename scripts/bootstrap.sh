#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

echo "=============================================="
echo " GlobalBoost GBIPs Bootstrap"
echo "=============================================="
echo

# ------------------------------------------------
# Requirements
# ------------------------------------------------

command -v git >/dev/null 2>&1 || {
    echo "ERROR: git is required."
    exit 1
}

command -v bash >/dev/null 2>&1 || {
    echo "ERROR: bash is required."
    exit 1
}

echo "Repository: $ROOT_DIR"
echo "Git:        $(git --version)"

# ------------------------------------------------
# Optional Python support
# ------------------------------------------------

if command -v python3 >/dev/null 2>&1; then
    echo "Python:      $(python3 --version)"
else
    echo "Python:      not installed (optional)"
fi

echo

# ------------------------------------------------
# Repository directories
# ------------------------------------------------

echo "Checking repository structure..."

mkdir -p \
    tools \
    schemas \
    templates

# ------------------------------------------------
# Executable permissions
# ------------------------------------------------

if [[ -f "$ROOT_DIR/validate.sh" ]]; then
    chmod +x "$ROOT_DIR/validate.sh"
    echo "Enabled: validate.sh"
fi

# ------------------------------------------------
# Check GBIP files
# ------------------------------------------------

GBIP_COUNT=0

for file in "$ROOT_DIR"/gbip-*.md; do
    [[ -f "$file" ]] || continue
    GBIP_COUNT=$((GBIP_COUNT + 1))
done

echo "GBIP documents found: $GBIP_COUNT"

# ------------------------------------------------
# Run validation
# ------------------------------------------------

if [[ -x "$ROOT_DIR/validate.sh" ]]; then
    echo
    echo "Running GBIP validation..."
    "$ROOT_DIR/validate.sh"
else
    echo
    echo "WARNING: validate.sh was not found."
fi

echo
echo "=============================================="
echo " Bootstrap complete"
echo "=============================================="
