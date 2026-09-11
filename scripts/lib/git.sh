#!/usr/bin/env bash
#
# git.sh
#
# Git utilities for the GBIP shell framework.
#
# Provides:
#   - Repository detection
#   - Working-tree checks
#   - Branch information
#   - Commit / tag helpers
#   - Remote information
#   - Release safety checks
#   - GitHub Actions helpers
#

[[ -n "${GBIP_GIT_LOADED:-}" ]] && return
readonly GBIP_GIT_LOADED=1

# ---------------------------------------------------------------------------
# Load framework modules
# ---------------------------------------------------------------------------

GBIP_GIT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${GBIP_GIT_LIB_DIR}/common.sh"

# ---------------------------------------------------------------------------
# Git availability
# ---------------------------------------------------------------------------

git_available() {
    command_exists git
}

require_git() {
    if !git_available; then
        gbip_die_dependency "Git is required but was not found."
    fi
}

# ---------------------------------------------------------------------------
# Repository detection
# ---------------------------------------------------------------------------

git_is_repository() {
    git -C "${GBIP_ROOT_DIR}" rev-parse \
        --is-inside-work-tree >/dev/null 2>&1
}

git_require_repository() {
    require_git

    if !git_is_repository; then
        error "GBIP root is not a Git repository:"
        error "  ${GBIP_ROOT_DIR}"
        return "${GBIP_EXIT_NOT_GIT_REPOSITORY}"
    fi
}

git_root() {
    git -C "${GBIP_ROOT_DIR}" rev-parse --show-toplevel 2>/dev/null
}

git_dir() {
    git -C "${GBIP_ROOT_DIR}" rev-parse --git-dir 2>/dev/null
}

# ---------------------------------------------------------------------------
# Working tree status
# ---------------------------------------------------------------------------

git_is_clean() {
    git_require_repository || return 1

    [[ -z "$(git -C "${GBIP_ROOT_DIR}" status --porcelain)" ]]
}

git_has_changes() {
    ! git_is_clean
}

git_status_porcelain() {
    git_require_repository || return 1

    git -C "${GBIP_ROOT_DIR}" status --porcelain
}

git_status() {
    git_require_repository || return 1

    git -C "${GBIP_ROOT_DIR}" status --short --branch
}

git_require_clean() {
    if git_is_clean; then
        debug "Git working tree is clean."
        return 0
    fi

    error "Git working tree contains uncommitted changes."
    git_status

    return 1
}

# ---------------------------------------------------------------------------
# Branch information
# ---------------------------------------------------------------------------

git_current_branch() {
    git_require_repository || return 1

    git -C "${GBIP_ROOT_DIR}" branch \
        --show-current
}

git_default_branch() {
    printf '%s\n' "${GBIP_DEFAULT_BRANCH}"
}

git_is_default_branch() {
    [[ "$(git_current_branch)" == "${GBIP_DEFAULT_BRANCH}" ]]
}

git_require_default_branch() {
    if git_is_default_branch; then
        debug "Currently on default branch: ${GBIP_DEFAULT_BRANCH}"
        return 0
    fi

    error "Operation requires branch '${GBIP_DEFAULT_BRANCH}'."
    error "Current branch: $(git_current_branch)"

    return 1
}

# ---------------------------------------------------------------------------
# Commit information
# ---------------------------------------------------------------------------

git_current_commit() {
    git_require_repository || return 1

    git -C "${GBIP_ROOT_DIR}" rev-parse HEAD
}

git_short_commit() {
    git_require_repository || return 1

    git -C "${GBIP_ROOT_DIR}" rev-parse --short HEAD
}

git_commit_count() {
    git_require_repository || return 1

    git -C "${GBIP_ROOT_DIR}" rev-list --count HEAD
}

git_commit_message() {
    git_require_repository || return 1

    git -C "${GBIP_ROOT_DIR}" log -1 --pretty=%s
}

git_commit_date() {
    git_require_repository || return 1

    git -C "${GBIP_ROOT_DIR}" log -1 \
        --date=format:'%Y-%m-%dT%H:%M:%SZ' \
        --format='%cd'
}

# ---------------------------------------------------------------------------
# Remote information
# ---------------------------------------------------------------------------

git_remote_exists() {
    local remote="${1:-origin}"

    git_require_repository || return 1

    git -C "${GBIP_ROOT_DIR}" remote get-url \
        "${remote}" >/dev/null 2>&1
}

git_remote_url() {
    local remote="${1:-origin}"

    git_require_repository || return 1

    git -C "${GBIP_ROOT_DIR}" remote get-url \
        "${remote}"
}

git_remote_urls() {
    git_require_repository || return 1

    git -C "${GBIP_ROOT_DIR}" remote -v
}

git_remote_default_branch() {
    local remote="${1:-origin}"

    git_require_repository || return 1

    git remote show "${remote}" 2>/dev/null |
        sed -n 's/.*HEAD branch: //p'
}

# ---------------------------------------------------------------------------
# Fetch
# ---------------------------------------------------------------------------

git_fetch() {
    local remote="${1:-origin}"

    git_require_repository || return 1

    if is_dry_run; then
        info "[dry-run] git fetch ${remote}"
        return 0
    fi

    run git -C "${GBIP_ROOT_DIR}" fetch \
        --prune \
        "${remote}"
}

# ---------------------------------------------------------------------------
# Pull status / synchronization
# ---------------------------------------------------------------------------

git_ahead_count() {
    local remote_branch="${1:-origin/${GBIP_DEFAULT_BRANCH}}"

    git_require_repository || return 1

    git rev-list \
        --count "${remote_branch}..HEAD" 2>/dev/null || printf '0\n'
}

git_behind_count() {
    local remote_branch="${1:-origin/${GBIP_DEFAULT_BRANCH}}"

    git_require_repository || return 1

    git rev-list \
        --count "HEAD..${remote_branch}" 2>/dev/null || printf '0\n'
}

git_is_synced() {
    local remote_branch="${1:-origin/${GBIP_DEFAULT_BRANCH}}"

    [[ "$(git_ahead_count "${remote_branch}")" -eq 0 &&
       "$(git_behind_count "${remote_branch}")" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# Tags
# ---------------------------------------------------------------------------

git_tag_exists() {
    local tag="$1"

    git_require_repository || return 1

    git rev-parse \
        --verify \
        --quiet \
        "refs/tags/${tag}" >/dev/null
}

git_require_tag_not_exists() {
    local tag="$1"

    if git_tag_exists "${tag}"; then
        error "Git tag already exists: ${tag}"
        return 1
    fi
}

git_latest_tag() {
    git_require_repository || return 1

    git describe \
        --tags \
        --abbrev=0 \
        2>/dev/null || true
}

git_tags() {
    git_require_repository || return 1

    git tag --sort=-version:refname
}

# ---------------------------------------------------------------------------
# Version tag helpers
# ---------------------------------------------------------------------------

git_version_tag() {
    local version="${1:-${GBIP_VERSION}}"

    printf 'v%s\n' "${version#v}"
}

git_release_tag_exists() {
    local version="${1:-${GBIP_VERSION}}"

    git_tag_exists "$(git_version_tag "${version}")"
}

# ---------------------------------------------------------------------------
# Tag creation
# ---------------------------------------------------------------------------

git_create_tag() {
    local version="${1:-${GBIP_VERSION}}"
    local tag

    tag="$(git_version_tag "${version}")"

    git_require_repository || return 1
    require_semver "${version}" || return 1
    git_require_tag_not_exists "${tag}" || return 1

    if is_dry_run; then
        info "[dry-run] git tag -a ${tag} -m \"GBIP ${version}\""
        return 0
    fi

    run git -C "${GBIP_ROOT_DIR}" tag \
        -a "${tag}" \
        -m "GBIP ${version}"
}

# ---------------------------------------------------------------------------
# Commit
# ---------------------------------------------------------------------------

git_commit() {
    local message="$1"

    git_require_repository || return 1

    if [[ -z "${message}" ]]; then
        error "Commit message cannot be empty."
        return 1
    fi

    if git_is_clean; then
        warning "Nothing to commit."
        return 0
    fi

    if is_dry_run; then
        info "[dry-run] git add -A"
        info "[dry-run] git commit -m \"${message}\""
        return 0
    fi

    run git -C "${GBIP_ROOT_DIR}" add -A || return 1

    run git -C "${GBIP_ROOT_DIR}" commit \
        -m "${message}"
}

# ---------------------------------------------------------------------------
# Diff
# ---------------------------------------------------------------------------

git_diff() {
    git_require_repository || return 1

    git -C "${GBIP_ROOT_DIR}" diff
}

git_diff_cached() {
    git_require_repository || return 1

    git -C "${GBIP_ROOT_DIR}" diff --cached
}

git_diff_check() {
    git_require_repository || return 1

    git -C "${GBIP_ROOT_DIR}" diff --check
}

# ---------------------------------------------------------------------------
# File tracking
# ---------------------------------------------------------------------------

git_is_tracked() {
    local file="$1"

    git_require_repository || return 1

    git -C "${GBIP_ROOT_DIR}" ls-files \
        --error-unmatch "${file}" >/dev/null 2>&1
}

git_is_ignored() {
    local file="$1"

    git_require_repository || return 1

    git -C "${GBIP_ROOT_DIR}" check-ignore \
        -q "${file}"
}

# ---------------------------------------------------------------------------
# Release safety
# ---------------------------------------------------------------------------

git_release_preflight() {
    local version="${1:-${GBIP_VERSION}}"

    header "Git release preflight"

    git_require_repository || return 1

    require_semver "${version}" || return 1

    if ! git_is_clean; then
        error "Release requires a clean working tree."
        git_status
        return 1
    fi

    if ! git_is_default_branch; then
        error "Release requires branch '${GBIP_DEFAULT_BRANCH}'."
        error "Current branch: $(git_current_branch)"
        return 1
    fi

    local tag
    tag="$(git_version_tag "${version}")"

    if git_tag_exists "${tag}"; then
        error "Release tag already exists: ${tag}"
        return 1
    fi

    success "Git release preflight passed."
    return 0
}

# ---------------------------------------------------------------------------
# Repository identity
# ---------------------------------------------------------------------------

git_repository_name() {
    git_require_repository || return 1

    basename "$(git_root)"
}

git_repository_owner() {
    local remote="${1:-origin}"
    local url

    url="$(git_remote_url "${remote}" 2>/dev/null)" || return 1

    # HTTPS:
    #   https://github.com/owner/repository.git
    #
    # SSH:
    #   git@github.com:owner/repository.git

    url="${url%.git}"

    if [[ "${url}" =~ github\.com[:/]([^/]+)/[^/]+$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi

    return 1
}

git_repository_slug() {
    local remote="${1:-origin}"
    local url

    url="$(git_remote_url "${remote}" 2>/dev/null)" || return 1

    url="${url%.git}"

    if [[ "${url}" =~ github\.com[:/]([^/]+)/([^/]+)$ ]]; then
        printf '%s/%s\n' \
            "${BASH_REMATCH[1]}" \
            "${BASH_REMATCH[2]}"
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# GitHub Actions
# ---------------------------------------------------------------------------

git_is_github_actions() {
    [[ -n "${GITHUB_ACTIONS:-}" ]]
}

git_set_output() {
    local name="$1"
    local value="$2"

    if git_is_github_actions; then
        printf '%s=%s\n' "${name}" "${value}" \
            >> "${GITHUB_OUTPUT}"
    fi
}

git_set_env() {
    local name="$1"
    local value="$2"

    if git_is_github_actions; then
        printf '%s=%s\n' "${name}" "${value}" \
            >> "${GITHUB_ENV}"
    fi
}

git_github_summary() {
    local message="$1"

    if git_is_github_actions; then
        printf '%s\n' "${message}" \
            >> "${GITHUB_STEP_SUMMARY}"
    fi
}

# ---------------------------------------------------------------------------
# Git information summary
# ---------------------------------------------------------------------------

git_summary() {
    git_require_repository || return 1

    header "Git Repository"

    printf 'Root:       %s\n' "$(git_root)"
    printf 'Branch:     %s\n' "$(git_current_branch)"
    printf 'Commit:     %s\n' "$(git_short_commit)"
    printf 'Commits:    %s\n' "$(git_commit_count)"

    local tag
    tag="$(git_latest_tag)"

    if [[ -n "${tag}" ]]; then
        printf 'Latest tag: %s\n' "${tag}"
    else
        printf 'Latest tag: none\n'
    fi

    if git_remote_exists origin; then
        printf 'Remote:     %s\n' "$(git_remote_url origin)"
    else
        printf 'Remote:     none\n'
    fi

    if git_is_clean; then
        printf 'Status:     clean\n'
    else
        printf 'Status:     modified\n'
    fi
}

# ---------------------------------------------------------------------------
# Validation helpers
# ---------------------------------------------------------------------------

git_validate_repository() {
    git_require_repository || return 1

    local failed=0

    if [[ "$(git_root)" != "${GBIP_ROOT_DIR}" ]]; then
        error "Git root does not match GBIP root."
        error "Expected: ${GBIP_ROOT_DIR}"
        error "Actual:   $(git_root)"
        failed=1
    fi

    if ! git_diff_check; then
        error "Git whitespace validation failed."
        failed=1
    fi

    if [[ "${failed}" -eq 0 ]]; then
        success "Git repository validation passed."
        return 0
    fi

    error "Git repository validation failed."
    return 1
}

# ---------------------------------------------------------------------------
# Framework initialization
# ---------------------------------------------------------------------------

require_git