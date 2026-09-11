#!/usr/bin/env bash
#
# validation.sh
#
# Common validation orchestration for the GBIP shell framework.
#
# Coordinates the individual repository validators while providing:
#   - Standardized validation stages
#   - Selective validation
#   - CI support
#   - Dry-run support
#   - Consistent exit codes
#   - Validation summaries
#   - Optional validator handling
#

[[ -n "${GBIP_VALIDATION_LOADED:-}" ]] && return
readonly GBIP_VALIDATION_LOADED=1

# ---------------------------------------------------------------------------
# Load framework modules
# ---------------------------------------------------------------------------

GBIP_VALIDATION_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${GBIP_VALIDATION_LIB_DIR}/filesystem.sh"

# ---------------------------------------------------------------------------
# Validation state
# ---------------------------------------------------------------------------

GBIP_VALIDATION_FAILED=0
GBIP_VALIDATION_PASSED=0
GBIP_VALIDATION_SKIPPED=0
GBIP_VALIDATION_TOTAL=0

GBIP_VALIDATION_START_TIME=""
GBIP_VALIDATION_END_TIME=""

# ---------------------------------------------------------------------------
# Validation stage switches
# ---------------------------------------------------------------------------

GBIP_RUN_METADATA="${GBIP_RUN_METADATA:-1}"
GBIP_RUN_REGISTRY="${GBIP_RUN_REGISTRY:-1}"
GBIP_RUN_SCHEMAS="${GBIP_RUN_SCHEMAS:-1}"
GBIP_RUN_DOCUMENTS="${GBIP_RUN_DOCUMENTS:-1}"
GBIP_RUN_NUMBERING="${GBIP_RUN_NUMBERING:-1}"
GBIP_RUN_LINKS="${GBIP_RUN_LINKS:-1}"

# ---------------------------------------------------------------------------
# Validator paths
# ---------------------------------------------------------------------------

GBIP_VALIDATE_METADATA_TOOL="${GBIP_TOOLS_DIR}/validate_metadata.py"
GBIP_VALIDATE_REGISTRY_TOOL="${GBIP_TOOLS_DIR}/validate_registries.py"
GBIP_VALIDATE_SCHEMAS_TOOL="${GBIP_TOOLS_DIR}/validate_schemas.py"
GBIP_VALIDATE_DOCUMENTS_TOOL="${GBIP_TOOLS_DIR}/validate_documents.py"
GBIP_VALIDATE_NUMBERING_TOOL="${GBIP_TOOLS_DIR}/validate_numbering.py"
GBIP_VALIDATE_LINKS_TOOL="${GBIP_TOOLS_DIR}/validate_links.py"

# ---------------------------------------------------------------------------
# Validation result tracking
# ---------------------------------------------------------------------------

validation_reset() {
    GBIP_VALIDATION_FAILED=0
    GBIP_VALIDATION_PASSED=0
    GBIP_VALIDATION_SKIPPED=0
    GBIP_VALIDATION_TOTAL=0

    GBIP_VALIDATION_START_TIME=""
    GBIP_VALIDATION_END_TIME=""
}

validation_record_pass() {
    GBIP_VALIDATION_TOTAL=$((GBIP_VALIDATION_TOTAL + 1))
    GBIP_VALIDATION_PASSED=$((GBIP_VALIDATION_PASSED + 1))
}

validation_record_failure() {
    GBIP_VALIDATION_TOTAL=$((GBIP_VALIDATION_TOTAL + 1))
    GBIP_VALIDATION_FAILED=$((GBIP_VALIDATION_FAILED + 1))
    GBIP_VALIDATION_FAILED=1
}

validation_record_skip() {
    GBIP_VALIDATION_SKIPPED=$((GBIP_VALIDATION_SKIPPED + 1))
}

# ---------------------------------------------------------------------------
# Individual validator execution
# ---------------------------------------------------------------------------

validation_run_tool() {
    local name="$1"
    local tool="$2"

    if [[ ! -f "${tool}" ]]; then
        warning "Validator not found: ${tool}"
        warning "Skipping: ${name}"
        validation_record_skip
        return 0
    fi

    GBIP_VALIDATION_TOTAL=$((GBIP_VALIDATION_TOTAL + 1))

    header "${name}"

    debug "Validator: ${tool}"

    if [[ "${GBIP_DRY_RUN:-0}" -eq 1 ]]; then
        info "[dry-run] python ${tool}"
        validation_record_skip
        return 0
    fi

    if "${GBIP_PYTHON}" "${tool}"; then
        success "${name} passed."
        GBIP_VALIDATION_PASSED=$((GBIP_VALIDATION_PASSED + 1))
        return 0
    fi

    error "${name} failed."
    GBIP_VALIDATION_FAILED=$((GBIP_VALIDATION_FAILED + 1))

    return 1
}

# ---------------------------------------------------------------------------
# Specialized validation stages
# ---------------------------------------------------------------------------

validation_metadata() {
    [[ "${GBIP_RUN_METADATA}" -eq 1 ]] || {
        debug "Metadata validation disabled."
        validation_record_skip
        return 0
    }

    validation_run_tool \
        "Metadata validation" \
        "${GBIP_VALIDATE_METADATA_TOOL}"
}

validation_registry() {
    [[ "${GBIP_RUN_REGISTRY}" -eq 1 ]] || {
        debug "Registry validation disabled."
        validation_record_skip
        return 0
    }

    validation_run_tool \
        "Registry validation" \
        "${GBIP_VALIDATE_REGISTRY_TOOL}"
}

validation_schemas() {
    [[ "${GBIP_RUN_SCHEMAS}" -eq 1 ]] || {
        debug "Schema validation disabled."
        validation_record_skip
        return 0
    }

    validation_run_tool \
        "Schema validation" \
        "${GBIP_VALIDATE_SCHEMAS_TOOL}"
}

validation_documents() {
    [[ "${GBIP_RUN_DOCUMENTS}" -eq 1 ]] || {
        debug "Document validation disabled."
        validation_record_skip
        return 0
    }

    validation_run_tool \
        "Document validation" \
        "${GBIP_VALIDATE_DOCUMENTS_TOOL}"
}

validation_numbering() {
    [[ "${GBIP_RUN_NUMBERING}" -eq 1 ]] || {
        debug "Numbering validation disabled."
        validation_record_skip
        return 0
    }

    validation_run_tool \
        "Numbering validation" \
        "${GBIP_VALIDATE_NUMBERING_TOOL}"
}

validation_links() {
    [[ "${GBIP_RUN_LINKS}" -eq 1 ]] || {
        debug "Link validation disabled."
        validation_record_skip
        return 0
    }

    validation_run_tool \
        "Link validation" \
        "${GBIP_VALIDATE_LINKS_TOOL}"
}

# ---------------------------------------------------------------------------
# Repository structure validation
# ---------------------------------------------------------------------------

validation_structure() {
    header "Repository structure"

    local required_dirs=(
        "${GBIP_GBIPS_DIR}"
        "${GBIP_REGISTRY_DIR}"
        "${GBIP_SCHEMAS_DIR}"
        "${GBIP_TEMPLATES_DIR}"
        "${GBIP_DOCS_DIR}"
        "${GBIP_TOOLS_DIR}"
        "${GBIP_TESTS_DIR}"
        "${GBIP_SCRIPTS_DIR}"
    )

    local directory
    local failed=0

    for directory in "${required_dirs[@]}"; do
        if [[ -d "${directory}" ]]; then
            debug "Directory exists: ${directory}"
        else
            error "Missing required directory: ${directory}"
            failed=1
        fi
    done

    if [[ "${failed}" -eq 0 ]]; then
        success "Repository structure passed."
        validation_record_pass
        return 0
    fi

    error "Repository structure failed."
    validation_record_failure
    return 1
}

# ---------------------------------------------------------------------------
# Required repository files
# ---------------------------------------------------------------------------

validation_required_files() {
    header "Required repository files"

    local required_files=(
        "${GBIP_ROOT_DIR}/README.md"
        "${GBIP_ROOT_DIR}/LICENSE"
        "${GBIP_ROOT_DIR}/CONTRIBUTING.md"
        "${GBIP_ROOT_DIR}/CODE_OF_CONDUCT.md"
        "${GBIP_ROOT_DIR}/SECURITY.md"
        "${GBIP_ROOT_DIR}/CHANGELOG.md"
        "${GBIP_ROOT_DIR}/ROADMAP.md"
        "${GBIP_ROOT_DIR}/VERSION"
    )

    local file
    local failed=0

    for file in "${required_files[@]}"; do
        if [[ -f "${file}" ]]; then
            debug "File exists: ${file}"
        else
            error "Missing required file: ${file}"
            failed=1
        fi
    done

    if [[ "${failed}" -eq 0 ]]; then
        success "Required files passed."
        validation_record_pass
        return 0
    fi

    error "Required files validation failed."
    validation_record_failure
    return 1
}

# ---------------------------------------------------------------------------
# Schema inventory validation
# ---------------------------------------------------------------------------

validation_schema_inventory() {
    header "Schema inventory"

    local schemas=(
        "${GBIP_SCHEMAS_DIR}/base.schema.json"
        "${GBIP_SCHEMAS_DIR}/metadata.schema.json"
        "${GBIP_SCHEMAS_DIR}/registry.schema.json"
        "${GBIP_SCHEMAS_DIR}/review.schema.json"
        "${GBIP_SCHEMAS_DIR}/release.schema.json"
        "${GBIP_SCHEMAS_DIR}/gbip.schema.json"
    )

    local schema
    local failed=0

    for schema in "${schemas[@]}"; do
        if [[ -f "${schema}" ]]; then
            debug "Schema exists: ${schema}"
        else
            error "Missing schema: ${schema}"
            failed=1
        fi
    done

    if [[ "${failed}" -eq 0 ]]; then
        success "Schema inventory passed."
        validation_record_pass
        return 0
    fi

    error "Schema inventory failed."
    validation_record_failure
    return 1
}

# ---------------------------------------------------------------------------
# Registry inventory validation
# ---------------------------------------------------------------------------

validation_registry_inventory() {
    header "Registry inventory"

    if [[ ! -d "${GBIP_REGISTRY_DIR}" ]]; then
        error "Registry directory missing: ${GBIP_REGISTRY_DIR}"
        validation_record_failure
        return 1
    fi

    local registry_count

    registry_count="$(
        find "${GBIP_REGISTRY_DIR}" \
            -type f \
            \( -name '*.yaml' -o -name '*.yml' -o -name '*.json' \) \
            | wc -l \
            | tr -d '[:space:]'
    )"

    if [[ "${registry_count}" -eq 0 ]]; then
        error "No registry files found."
        validation_record_failure
        return 1
    fi

    success "Registry inventory passed (${registry_count} files)."
    validation_record_pass
    return 0
}

# ---------------------------------------------------------------------------
# GBIP document inventory validation
# ---------------------------------------------------------------------------

validation_document_inventory() {
    header "GBIP document inventory"

    if [[ ! -d "${GBIP_GBIPS_DIR}" ]]; then
        error "GBIP directory missing: ${GBIP_GBIPS_DIR}"
        validation_record_failure
        return 1
    fi

    local document_count

    document_count="$(
        find "${GBIP_GBIPS_DIR}" \
            -type f \
            -name 'GBIP-*.md' \
            | wc -l \
            | tr -d '[:space:]'
    )"

    if [[ "${document_count}" -eq 0 ]]; then
        error "No GBIP documents found."
        validation_record_failure
        return 1
    fi

    success "GBIP document inventory passed (${document_count} documents)."
    validation_record_pass
    return 0
}

# ---------------------------------------------------------------------------
# Version validation
# ---------------------------------------------------------------------------

validation_version() {
    header "Version validation"

    require_file "${GBIP_VERSION_FILE}" || {
        validation_record_failure
        return 1
    }

    refresh_version

    if is_semver "${GBIP_VERSION}"; then
        success "Version is valid: ${GBIP_VERSION}"
        validation_record_pass
        return 0
    fi

    error "Invalid GBIP version: ${GBIP_VERSION}"
    validation_record_failure
    return 1
}

# ---------------------------------------------------------------------------
# Python environment validation
# ---------------------------------------------------------------------------

validation_python() {
    header "Python environment"

    if [[ ! -x "${GBIP_PYTHON}" ]]; then
        warning "GBIP virtualenv Python not found:"
        warning "  ${GBIP_PYTHON}"

        if command_exists python3; then
            warning "System Python is available, but GBIP prefers the virtualenv."
        elif command_exists python; then
            warning "System Python is available, but GBIP prefers the virtualenv."
        else
            error "No Python interpreter available."
            validation_record_failure
            return 1
        fi

        validation_record_skip
        return 0
    fi

    local python_version

    python_version="$("${GBIP_PYTHON}" --version 2>&1)"

    success "Python available: ${python_version}"
    validation_record_pass
    return 0
}

# ---------------------------------------------------------------------------
# Individual validation selection
# ---------------------------------------------------------------------------

validation_run_selected() {
    local failed=0

    validation_structure || failed=1
    validation_required_files || failed=1
    validation_version || failed=1
    validation_python || failed=1

    validation_schema_inventory || failed=1
    validation_registry_inventory || failed=1
    validation_document_inventory || failed=1

    validation_metadata || failed=1
    validation_registry || failed=1
    validation_schemas || failed=1
    validation_documents || failed=1
    validation_numbering || failed=1
    validation_links || failed=1

    return "${failed}"
}

# ---------------------------------------------------------------------------
# Full validation
# ---------------------------------------------------------------------------

validation_run_all() {
    validation_reset

    GBIP_VALIDATION_START_TIME="$(date +%s)"

    ci_group_start "GBIP Repository Validation"

    local result=0

    validation_run_selected || result=1

    GBIP_VALIDATION_END_TIME="$(date +%s)"

    ci_group_end

    return "${result}"
}

# ---------------------------------------------------------------------------
# Validation summary
# ---------------------------------------------------------------------------

validation_summary() {
    local duration="unknown"

    if [[ -n "${GBIP_VALIDATION_START_TIME}" &&
          -n "${GBIP_VALIDATION_END_TIME}" ]]; then

        duration="$(
            (
                GBIP_VALIDATION_END_TIME -
                GBIP_VALIDATION_START_TIME
            )
        )s"
    fi

    header "Validation Summary"

    printf 'Total:    %s\n' "${GBIP_VALIDATION_TOTAL}"
    printf 'Passed:   %s\n' "${GBIP_VALIDATION_PASSED}"
    printf 'Failed:   %s\n' "${GBIP_VALIDATION_FAILED}"
    printf 'Skipped:  %s\n' "${GBIP_VALIDATION_SKIPPED}"
    printf 'Duration: %s\n' "${duration}"

    if [[ "${GBIP_VALIDATION_FAILED}" -eq 0 ]]; then
        success "GBIP validation completed successfully."
        return 0
    fi

    error "GBIP validation failed."
    return 1
}

# ---------------------------------------------------------------------------
# Machine-readable validation status
# ---------------------------------------------------------------------------

validation_status() {
    if [[ "${GBIP_VALIDATION_FAILED}" -eq 0 ]]; then
        printf '%s\n' "PASS"
        return 0
    fi

    printf '%s\n' "FAIL"
    return 1
}

# ---------------------------------------------------------------------------
# CI summary
# ---------------------------------------------------------------------------

validation_ci_summary() {
    if [[ "${GBIP_CI:-0}" -ne 1 ]]; then
        return 0
    fi

    printf 'GBIP_VALIDATION_TOTAL=%s\n' \
        "${GBIP_VALIDATION_TOTAL}"

    printf 'GBIP_VALIDATION_PASSED=%s\n' \
        "${GBIP_VALIDATION_PASSED}"

    printf 'GBIP_VALIDATION_FAILED=%s\n' \
        "${GBIP_VALIDATION_FAILED}"

    printf 'GBIP_VALIDATION_SKIPPED=%s\n' \
        "${GBIP_VALIDATION_SKIPPED}"
}

# ---------------------------------------------------------------------------
# Main validation entry point
# ---------------------------------------------------------------------------

validate_repository() {
    validation_run_all

    local result="$?"

    validation_summary || result=1
    validation_ci_summary

    return "${result}"
}

# ---------------------------------------------------------------------------
# Framework initialization
# ---------------------------------------------------------------------------

gbip_debug_environment