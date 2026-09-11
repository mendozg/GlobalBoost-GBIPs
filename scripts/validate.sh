#!/usr/bin/env bash

# GBIP Repository Validator
#
# Purpose:
#   Validate the structural and metadata integrity of the GBIP repository.
#
# Usage:
#   ./scripts/validate.sh
#   ./scripts/validate.sh --strict
#   ./scripts/validate.sh --quiet
#
# Exit codes:
#   0 - Validation successful
#   1 - Validation failed
#   2 - Invalid command-line usage
#
# Draft 3 implementation
# GBIP-0000

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

STRICT=false
QUIET=false

ERRORS=0
WARNINGS=0

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

info() {
    if [[ "${QUIET}" != true ]]; then
        printf '[INFO] %s\n' "$*"
    fi
}

success() {
    if [[ "${QUIET}" != true ]]; then
        printf '[ OK ] %s\n' "$*"
    fi
}

warning() {
    WARNINGS=$((WARNINGS + 1))
    printf '[WARN] %s\n' "$*" >&2
}

error() {
    ERRORS=$((ERRORS + 1))
    printf '[FAIL] %s\n' "$*" >&2
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

usage() {
    cat <<'EOF'
GBIP Repository Validator

Usage:
  ./scripts/validate.sh [OPTIONS]

Options:
  --strict    Treat warnings as validation failures.
  --quiet     Suppress informational output.
  --help      Show this help message.

Exit codes:
  0  Validation successful
  1  Validation failed
  2  Invalid command-line usage
EOF
}

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        --strict)
            STRICT=true
            shift
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            printf '[FAIL] Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Repository root
# ---------------------------------------------------------------------------

cd "${REPO_ROOT}"

info "GBIP repository validation started"
info "Repository: ${REPO_ROOT}"

# ---------------------------------------------------------------------------
# Required directories
# ---------------------------------------------------------------------------

REQUIRED_DIRS=(
    "gbips"
    "registry"
    "schemas"
    "templates"
    "docs"
    "scripts"
    "tools"
    "tests"
    ".github"
)

info "Checking repository directories..."

for directory in "${REQUIRED_DIRS[@]}"; do
    if [[ -d "${directory}" ]]; then
        success "Directory exists: ${directory}/"
    else
        error "Required directory missing: ${directory}/"
    fi
done

# ---------------------------------------------------------------------------
# Required root files
# ---------------------------------------------------------------------------

REQUIRED_FILES=(
    "README.md"
    "LICENSE"
    "CONTRIBUTING.md"
    "CODE_OF_CONDUCT.md"
    "SECURITY.md"
    "CHANGELOG.md"
    "ROADMAP.md"
    ".gitignore"
    ".editorconfig"
)

info "Checking required root files..."

for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "${file}" ]]; then
        success "File exists: ${file}"
    else
        error "Required file missing: ${file}"
    fi
done

# ---------------------------------------------------------------------------
# GBIP-0000
# ---------------------------------------------------------------------------

info "Checking GBIP-0000..."

if [[ -f "gbips/GBIP-0000.md" ]]; then
    success "GBIP-0000 exists"
else
    error "GBIP-0000.md not found"
fi

# ---------------------------------------------------------------------------
# Registry files
# ---------------------------------------------------------------------------

REQUIRED_REGISTRIES=(
    "proposal-types.yaml"
    "proposal-status.yaml"
    "proposal-lifecycle.yaml"
    "metadata-schema.yaml"
    "review-profile.yaml"
    "review-classifications.yaml"
    "acceptance-levels.yaml"
    "release-channels.yaml"
    "release-classifications.yaml"
    "releases.yaml"
    "deprecations.yaml"
    "governance.yaml"
    "references.yaml"
    "terminology.yaml"
    "document-sections.yaml"
    "file-layout.yaml"
    "domains.yaml"
    "validators.yaml"
    "revisions.yaml"
    "foundation-series.yaml"
)

info "Checking registry files..."

for registry in "${REQUIRED_REGISTRIES[@]}"; do
    if [[ -f "registry/${registry}" ]]; then
        success "Registry exists: registry/${registry}"
    else
        error "Required registry missing: registry/${registry}"
    fi
done

# ---------------------------------------------------------------------------
# YAML validation
# ---------------------------------------------------------------------------

if command -v python3 >/dev/null 2>&1; then

    if python3 -c 'import yaml' >/dev/null 2>&1; then
        info "Validating YAML files..."

        while IFS= read -r -d '' file; do
            if python3 - "$file" <<'PY'
import sys
import yaml

path = sys.argv[1]

with open(path, "r", encoding="utf-8") as handle:
    yaml.safe_load(handle)
PY
            then
                success "Valid YAML: ${file}"
            else
                error "Invalid YAML: ${file}"
            fi
        done < <(find registry -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)

    else
        warning "PyYAML is not installed; YAML validation skipped"
    fi

else
    warning "python3 is not installed; YAML validation skipped"
fi

# ---------------------------------------------------------------------------
# Markdown validation
# ---------------------------------------------------------------------------

if command -v python3 >/dev/null 2>&1; then

    info "Checking Markdown files..."

    while IFS= read -r -d '' file; do

        if [[ ! -s "${file}" ]]; then
            error "Empty Markdown file: ${file}"
            continue
        fi

        success "Markdown file readable: ${file}"

    done < <(find gbips docs templates -type f -name '*.md' -print0)

else
    warning "python3 is not installed; Markdown validation skipped"
fi

# ---------------------------------------------------------------------------
# GBIP filename validation
# ---------------------------------------------------------------------------

info "Checking GBIP filenames..."

while IFS= read -r -d '' file; do

    filename="$(basename "${file}")"

    if [[ "${filename}" =~ ^GBIP-[0-9]{4}\.md$ ]]; then
        success "Valid GBIP filename: ${filename}"
    else
        error "Invalid GBIP filename: ${file}"
    fi

done < <(find gbips -type f -name '*.md' -print0)

# ---------------------------------------------------------------------------
# GBIP numbering
# ---------------------------------------------------------------------------

info "Checking GBIP numbering..."

declare -A GBIP_NUMBERS=()

while IFS= read -r -d '' file; do

    filename="$(basename "${file}")"

    if [[ "${filename}" =~ ^GBIP-([0-9]{4})\.md$ ]]; then

        number="${BASH_REMATCH[1]}"

        if [[ -n "${GBIP_NUMBERS[${number}]:-}" ]]; then
            error "Duplicate GBIP number: ${number}"
        else
            GBIP_NUMBERS["${number}"]="${file}"
            success "GBIP number registered: ${number}"
        fi

    fi

done < <(find gbips -type f -name 'GBIP-*.md' -print0)

# ---------------------------------------------------------------------------
# GitHub workflow validation
# ---------------------------------------------------------------------------

info "Checking GitHub workflows..."

if [[ -d ".github/workflows" ]]; then

    workflow_count=0

    while IFS= read -r -d '' file; do
        workflow_count=$((workflow_count + 1))

        if [[ -s "${file}" ]]; then
            success "Workflow found: ${file}"
        else
            error "Empty workflow: ${file}"
        fi

    done < <(find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) -print0)

    if [[ "${workflow_count}" -eq 0 ]]; then
        warning "No GitHub Actions workflows found"
    fi

else
    error "Missing .github/workflows directory"
fi

# ---------------------------------------------------------------------------
# Script validation
# ---------------------------------------------------------------------------

if command -v shellcheck >/dev/null 2>&1; then

    info "Running ShellCheck..."

    if shellcheck "${SCRIPT_DIR}/validate.sh"; then
        success "ShellCheck passed"
    else
        error "ShellCheck failed"
    fi

else
    warning "ShellCheck is not installed; shell validation skipped"
fi

# ---------------------------------------------------------------------------
# Git status
# ---------------------------------------------------------------------------

if [[ -d ".git" ]]; then

    info "Checking Git repository..."

    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        success "Git repository detected"
    else
        error "Current directory is not a Git repository"
    fi

else
    warning "Git metadata not found"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

printf '\n'
printf '%s\n' '========================================'
printf '%s\n' ' GBIP Validation Summary'
printf '%s\n' '========================================'
printf 'Errors:   %d\n' "${ERRORS}"
printf 'Warnings: %d\n' "${WARNINGS}"
printf '%s\n' '========================================'

if [[ "${ERRORS}" -gt 0 ]]; then
    printf '[FAIL] GBIP repository validation failed.\n' >&2
    exit 1
fi

if [[ "${STRICT}" == true && "${WARNINGS}" -gt 0 ]]; then
    printf '[FAIL] Validation failed in strict mode.\n' >&2
    exit 1
fi

printf '[ OK ] GBIP repository validation passed.\n'
exit 0
