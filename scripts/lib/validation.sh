#!/usr/bin/env bash

GBIP_VALIDATION_FAILED="${GBIP_VALIDATION_FAILED:-0}"
GBIP_VALIDATION_PASSED="${GBIP_VALIDATION_PASSED:-0}"
GBIP_VALIDATION_SKIPPED="${GBIP_VALIDATION_SKIPPED:-0}"
GBIP_VALIDATION_TOTAL="${GBIP_VALIDATION_TOTAL:-0}"
GBIP_VALIDATION_START_TIME="${GBIP_VALIDATION_START_TIME:-}"
GBIP_VALIDATION_END_TIME="${GBIP_VALIDATION_END_TIME:-}"

GBIP_RUN_METADATA="${GBIP_RUN_METADATA:-1}"
GBIP_RUN_REGISTRY="${GBIP_RUN_REGISTRY:-1}"
GBIP_RUN_SCHEMAS="${GBIP_RUN_SCHEMAS:-1}"
GBIP_RUN_DOCUMENTS="${GBIP_RUN_DOCUMENTS:-1}"
GBIP_RUN_NUMBERING="${GBIP_RUN_NUMBERING:-1}"
GBIP_RUN_LINKS="${GBIP_RUN_LINKS:-1}"

GBIP_VALIDATE_METADATA_TOOL="${GBIP_TOOLS_DIR}/validate_metadata.py"
GBIP_VALIDATE_REGISTRY_TOOL="${GBIP_TOOLS_DIR}/validate_registries.py"
GBIP_VALIDATE_SCHEMAS_TOOL="${GBIP_TOOLS_DIR}/validate_schemas.py"
GBIP_VALIDATE_DOCUMENTS_TOOL="${GBIP_TOOLS_DIR}/validate_documents.py"
GBIP_VALIDATE_NUMBERING_TOOL="${GBIP_TOOLS_DIR}/validate_numbering.py"
GBIP_VALIDATE_LINKS_TOOL="${GBIP_TOOLS_DIR}/validate_links.py"

validation_reset() {
    GBIP_VALIDATION_FAILED=0
    GBIP_VALIDATION_PASSED=0
    GBIP_VALIDATION_SKIPPED=0
    GBIP_VALIDATION_TOTAL=0
    GBIP_VALIDATION_START_TIME="$(date +%s)"
    GBIP_VALIDATION_END_TIME=""
}

validation_record_pass() {
    GBIP_VALIDATION_TOTAL=$((GBIP_VALIDATION_TOTAL + 1))
    GBIP_VALIDATION_PASSED=$((GBIP_VALIDATION_PASSED + 1))
}

validation_record_failure() {
    GBIP_VALIDATION_TOTAL=$((GBIP_VALIDATION_TOTAL + 1))
    GBIP_VALIDATION_FAILED=$((GBIP_VALIDATION_FAILED + 1))
}

validation_record_skip() {
    GBIP_VALIDATION_SKIPPED=$((GBIP_VALIDATION_SKIPPED + 1))
}

validation_structure() {
    step "Validating repository structure"
    local required_dirs=(
        "${GBIP_GBIPS_DIR}" "${GBIP_REGISTRY_DIR}" "${GBIP_SCHEMAS_DIR}"
        "${GBIP_TEMPLATES_DIR}" "${GBIP_DOCS_DIR}" "${GBIP_TOOLS_DIR}"
        "${GBIP_TESTS_DIR}" "${GBIP_SCRIPTS_DIR}"
    )
    local dir
    for dir in "${required_dirs[@]}"; do
        if [[ -d "${dir}" ]]; then
            validation_record_pass
        else
            error "Missing required directory: ${dir}"
            validation_record_failure
        fi
    done
}

validation_required_files() {
    step "Validating required files"
    local required_files=(
        "${GBIP_ROOT_DIR}/README.md"
        "${GBIP_ROOT_DIR}/LICENSE"
        "${GBIP_ROOT_DIR}/CONTRIBUTING.md"
        "${GBIP_ROOT_DIR}/SECURITY.md"
        "${GBIP_VERSION_FILE}"
    )
    local file
    for file in "${required_files[@]}"; do
        if [[ -f "${file}" ]]; then
            validation_record_pass
        else
            error "Missing required file: ${file}"
            validation_record_failure
        fi
    done
}

validation_schema_inventory() {
    step "Validating schema inventory"
    local count
    count="$(find "${GBIP_SCHEMAS_DIR}" -type f -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "${count}" -gt 0 ]]; then
        info "Schema files found: ${count}"
        validation_record_pass
    else
        error "No JSON schemas found."
        validation_record_failure
    fi
}

validation_registry_inventory() {
    step "Validating registry inventory"
    local count
    count="$(find "${GBIP_REGISTRY_DIR}" -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.json' \) 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "${count}" -gt 0 ]]; then
        info "Registry files found: ${count}"
        validation_record_pass
    else
        error "No registry files found."
        validation_record_failure
    fi
}

validation_document_inventory() {
    step "Validating document inventory"
    local count
    count="$(find "${GBIP_GBIPS_DIR}" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "${count}" -gt 0 ]]; then
        info "GBIP documents found: ${count}"
        validation_record_pass
    else
        error "No GBIP Markdown documents found."
        validation_record_failure
    fi
}

validation_version() {
    step "Validating project version"
    if [[ -f "${GBIP_VERSION_FILE}" ]]; then
        local version
        version="$(gbip_read_version)"
        if is_semver "${version}"; then
            info "Version: ${version}"
            validation_record_pass
        else
            error "Invalid project version: ${version}"
            validation_record_failure
        fi
    else
        error "VERSION file not found."
        validation_record_failure
    fi
}

validation_python() {
    step "Validating Python runtime"
    if python_require_version >/dev/null 2>&1; then
        validation_record_pass
    else
        error "Python 3 runtime is unavailable."
        validation_record_failure
    fi
}

validation_run_tool() {
    local name="$1"
    local tool="$2"
    shift 2

    if [[ ! -f "${tool}" ]]; then
        warning "${name}: validator not found; skipping."
        validation_record_skip
        return 0
    fi

    info "Running ${name}"
    if python_run_tool "${tool}" "$@"; then
        validation_record_pass
    else
        error "${name} failed."
        validation_record_failure
        return 1
    fi
}

validation_metadata() {
    [[ "${GBIP_RUN_METADATA}" == "1" ]] || { validation_record_skip; return 0; }
    validation_run_tool "metadata validation" "${GBIP_VALIDATE_METADATA_TOOL}"
}

validation_registry() {
    [[ "${GBIP_RUN_REGISTRY}" == "1" ]] || { validation_record_skip; return 0; }
    validation_run_tool "registry validation" "${GBIP_VALIDATE_REGISTRY_TOOL}"
}

validation_schemas() {
    [[ "${GBIP_RUN_SCHEMAS}" == "1" ]] || { validation_record_skip; return 0; }
    validation_run_tool "schema validation" "${GBIP_VALIDATE_SCHEMAS_TOOL}"
}

validation_documents() {
    [[ "${GBIP_RUN_DOCUMENTS}" == "1" ]] || { validation_record_skip; return 0; }
    validation_run_tool "document validation" "${GBIP_VALIDATE_DOCUMENTS_TOOL}"
}

validation_numbering() {
    [[ "${GBIP_RUN_NUMBERING}" == "1" ]] || { validation_record_skip; return 0; }
    validation_run_tool "numbering validation" "${GBIP_VALIDATE_NUMBERING_TOOL}"
}

validation_links() {
    [[ "${GBIP_RUN_LINKS}" == "1" ]] || { validation_record_skip; return 0; }
    validation_run_tool "link validation" "${GBIP_VALIDATE_LINKS_TOOL}"
}

validation_run_selected() {
    validation_metadata || true
    validation_registry || true
    validation_schemas || true
    validation_documents || true
    validation_numbering || true
    validation_links || true
}

validation_run_all() {
    validation_reset
    validation_structure
    validation_required_files
    validation_schema_inventory
    validation_registry_inventory
    validation_document_inventory
    validation_version
    validation_python
    validation_run_selected
    GBIP_VALIDATION_END_TIME="$(date +%s)"
}

validation_summary() {
    local duration=0
    if [[ -n "${GBIP_VALIDATION_START_TIME}" && -n "${GBIP_VALIDATION_END_TIME}" ]]; then
        duration=$((GBIP_VALIDATION_END_TIME - GBIP_VALIDATION_START_TIME))
    fi

    printf '\nValidation Summary\n------------------\n'
    printf 'Total:    %s\n' "${GBIP_VALIDATION_TOTAL}"
    printf 'Passed:   %s\n' "${GBIP_VALIDATION_PASSED}"
    printf 'Failed:   %s\n' "${GBIP_VALIDATION_FAILED}"
    printf 'Skipped:  %s\n' "${GBIP_VALIDATION_SKIPPED}"
    printf 'Duration: %ss\n' "${duration}"
}

validation_status() {
    [[ "${GBIP_VALIDATION_FAILED}" -eq 0 ]]
}

validation_ci_summary() {
    if [[ "${GBIP_CI:-0}" == "1" ]]; then
        printf '::notice::GBIP validation: %s passed, %s failed, %s skipped\n' \
            "${GBIP_VALIDATION_PASSED}" "${GBIP_VALIDATION_FAILED}" \
            "${GBIP_VALIDATION_SKIPPED}"
    fi
}

validate_repository() {
    validation_run_all
    validation_summary
    validation_ci_summary
    validation_status
}
