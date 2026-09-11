#!/usr/bin/env bash
git_available() { command_exists git; }
require_git() { git_available || gbip_die_dependency "Git is required."; }
git_is_repository() { git -C "${GBIP_ROOT_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; }
git_require_repository() { git_is_repository || exit "${GBIP_EXIT_NOT_GIT:-7}"; }
git_status_porcelain() { git -C "${GBIP_ROOT_DIR}" status --porcelain; }
git_has_changes() { [[ -n "$(git_status_porcelain)" ]]; }
git_is_clean() { ! git_has_changes; }
git_require_clean() { git_is_clean || gbip_die_release "Git working tree is not clean."; }
git_current_branch() { git -C "${GBIP_ROOT_DIR}" branch --show-current; }
git_require_branch() { [[ "$(git_current_branch)" == "$1" ]] || gbip_die_release "Unexpected Git branch: $(git_current_branch)"; }
git_remote_default_branch() { git -C "${GBIP_ROOT_DIR}" remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF; exit}'; }
git_ahead_count() { local u; u="$(git -C "${GBIP_ROOT_DIR}" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"; [[ -n "$u" ]] && git -C "${GBIP_ROOT_DIR}" rev-list --count "$u..HEAD" || printf '0\n'; }
git_behind_count() { local u; u="$(git -C "${GBIP_ROOT_DIR}" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"; [[ -n "$u" ]] && git -C "${GBIP_ROOT_DIR}" rev-list --count "HEAD..$u" || printf '0\n'; }
git_tag_exists() { git -C "${GBIP_ROOT_DIR}" rev-parse "refs/tags/$1" >/dev/null 2>&1; }
git_version_tag() { printf 'v%s\n' "${1#v}"; }
git_create_tag() { local tag; tag="$(git_version_tag "$1")"; git_tag_exists "$tag" && gbip_die_release "Tag already exists: $tag"; git -C "${GBIP_ROOT_DIR}" tag -a "$tag" -m "GBIP release $1"; }
git_diff_check() { git -C "${GBIP_ROOT_DIR}" diff --check && git -C "${GBIP_ROOT_DIR}" diff --cached --check; }
git_release_preflight() { local v="$1"; require_git; git_require_repository; git_require_clean; git_require_branch "${GBIP_DEFAULT_BRANCH}"; require_semver "$v"; git_tag_exists "$(git_version_tag "$v")" && gbip_die_release "Release tag already exists."; git_diff_check; }
