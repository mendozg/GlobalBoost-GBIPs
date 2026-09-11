#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"

echo "=============================================="
echo " GlobalBoost GBIPs Build"
echo "=============================================="
echo

# ------------------------------------------------
# Clean build directories
# ------------------------------------------------

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$DIST_DIR"

echo "[1/5] Preparing build directories..."

# ------------------------------------------------
# Validate repository
# ------------------------------------------------

if [[ -x "$ROOT_DIR/validate.sh" ]]; then
    echo "[2/5] Validating GBIP repository..."
    "$ROOT_DIR/validate.sh"
else
    echo "ERROR: validate.sh not found or not executable."
    exit 1
fi

# ------------------------------------------------
# Collect GBIPs
# ------------------------------------------------

echo "[3/5] Collecting GBIP documents..."

GBIP_COUNT=0

for file in "$ROOT_DIR"/gbip-*.md; do
    [[ -f "$file" ]] || continue

    cp "$file" "$BUILD_DIR/"
    GBIP_COUNT=$((GBIP_COUNT + 1))
done

if [[ "$GBIP_COUNT" -eq 0 ]]; then
    echo "ERROR: No GBIP documents found."
    exit 1
fi

echo "      Found $GBIP_COUNT GBIP document(s)."

# ------------------------------------------------
# Generate manifest
# ------------------------------------------------

echo "[4/5] Generating manifest..."

MANIFEST="$BUILD_DIR/MANIFEST.sha256"

(
    cd "$BUILD_DIR"
    sha256sum gbip-*.md > "$MANIFEST"
)

# ------------------------------------------------
# Create distribution archive
# ------------------------------------------------

echo "[5/5] Creating distribution package..."

VERSION="$(git describe --tags --always --dirty 2>/dev/null || echo "development")"

ARCHIVE="$DIST_DIR/GlobalBoost-GBIPs-$VERSION.tar.gz"

tar \
    --exclude="build" \
    --exclude="dist" \
    -czf "$ARCHIVE" \
    gbip-*.md \
    README.md \
    LICENSE \
    2>/dev/null || {
        echo "WARNING: Some optional repository files were not included."
    }

echo
echo "=============================================="
echo " Build complete"
echo "=============================================="
echo
echo "GBIPs:    $GBIP_COUNT"
echo "Version:  $VERSION"
echo "Build:    $BUILD_DIR"
echo "Release:  $ARCHIVE"
echo
