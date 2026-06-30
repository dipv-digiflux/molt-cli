#!/usr/bin/env bash
# Shared helpers for molt workspace CLI.
#
# Layout: $MOLT_ROOT/{be,web,mobile,iaac,other}/<suite>-*
# CLI home: $MOLT_ROOT/molt-cli/

# shellcheck source=lib/molt-profile.sh
source "$(dirname "${BASH_SOURCE[0]}")/molt-profile.sh"

MOLT_VALID_SUITES=(be web mobile iaac pkg other)
# To add a prefix: append here, then update lib/prefix.sh picker menu.
# "all" (--prefix all) runs every suite in this list.

# GitHub repo name prefix for a suite (iaac → iaac-*).
suite_repo_prefix() {
  local suite="${1%-}"
  case "$suite" in
    other) echo "other" ;;
    *) echo "${suite}-" ;;
  esac
}

# Workspace folder for a repo-name prefix (iaac- → iaac/).
suite_from_repo_prefix() {
  local p="${1%-}"
  case "$p" in
    other) echo "other" ;;
    *) echo "$p" ;;
  esac
}

suite_menu_label() {
  local s="$1" root
  case "$s" in
    other)
      root="$(workspace_root_for_prefix "other")"
      echo "other      → ${root}/ (not be/web/mobile/iaac/pkg)"
      ;;
    *)
      root="$(workspace_root_for_prefix "${s}-")"
      echo "${s}-*       → ${root}/"
      ;;
  esac
}

matches_known_repo() {
  local name="$1" s p
  for s in "${MOLT_VALID_SUITES[@]}"; do
    [[ "$s" == "other" ]] && continue
    p="$(suite_repo_prefix "$s")"
    matches_prefix "$name" "$p" && return 0
  done
  return 1
}

is_other_repo() {
  ! matches_known_repo "$1"
}

die() { echo "error: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null || die "missing command: $1 (install and retry)"
}

# be- -> $MOLT_ROOT/be, iaac- -> $MOLT_ROOT/iaac, other -> $MOLT_ROOT/other
workspace_root_for_prefix() {
  local prefix="${1:-be-}"
  local suite
  suite="$(suite_from_repo_prefix "$prefix")"
  echo "$(molt_root)/$suite"
}

prefix_is_all() {
  [[ "${1%-}" == "all" ]]
}

normalize_prefix() {
  local p="${1:-be}"
  p="${p%-}"
  if prefix_is_all "$p"; then
    echo "all"
    return 0
  fi
  [[ "$p" == "iac" ]] && p="iaac"
  local s
  for s in "${MOLT_VALID_SUITES[@]}"; do
    [[ "$p" == "$s" ]] && echo "$(suite_repo_prefix "$s")" && return 0
  done
  echo "error: prefix must be one of: ${MOLT_VALID_SUITES[*]} or all (got: $1)" >&2
  return 1
}

matches_prefix() {
  local name="$1" prefix="$2"
  [[ "$name" == "${prefix}"* ]]
}

matches_any_suite() {
  local name="$1"
  matches_known_repo "$name" || is_other_repo "$name"
}

checkout_branch() {
  local dir="$1" branch="$2"
  git -C "$dir" fetch -q origin "$branch" 2>/dev/null || git -C "$dir" fetch -q origin
  if git -C "$dir" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$dir" checkout "$branch"
  elif git -C "$dir" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    git -C "$dir" checkout -B "$branch" "origin/$branch"
  else
    echo "  WARNING: branch $branch not found in $dir" >&2
    return 1
  fi
}

list_org_repos() {
  local prefix="$1"
  require_cmd gh
  if [[ "${prefix%-}" == "other" ]]; then
    gh repo list "$GITHUB_ORG" --limit 1000 --json name --jq '.[].name' 2>/dev/null | while read -r name; do
      is_other_repo "$name" && echo "$name"
    done | sort -u
    return 0
  fi
  gh repo list "$GITHUB_ORG" --limit 1000 --json name --jq '.[].name' 2>/dev/null | while read -r name; do
    matches_prefix "$name" "$prefix" && echo "$name"
  done | sort -u
}

list_org_repos_any_suite() {
  require_cmd gh
  gh repo list "$GITHUB_ORG" --limit 1000 --json name --jq '.[].name' 2>/dev/null | while read -r name; do
    matches_any_suite "$name" && echo "$name"
  done | sort -u
}

list_workspace_repos() {
  local root="$1" prefix="$2"
  local name dir
  if [[ "${prefix%-}" == "other" ]]; then
    for dir in "$root"/*/; do
      [[ -d "$dir" ]] || continue
      [[ -d "$dir/.git" ]] || continue
      basename "$dir"
    done | sort -u
    return 0
  fi
  for dir in "$root"/*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    matches_prefix "$name" "$prefix" || continue
    [[ -d "$dir/.git" ]] || continue
    echo "$name"
  done | sort -u
}

ssh_url_for_repo() {
  local repo="$1"
  echo "git@${MOLT_GITHUB_HOST:-github.com}:${GITHUB_ORG}/${repo}.git"
}

clone_url_for() {
  local repo="$1"
  if [[ "${MOLT_GIT_PROTOCOL:-ssh}" == "ssh" ]]; then
    ssh_url_for_repo "$repo"
    return 0
  fi
  local url
  url="$(gh repo view "${GITHUB_ORG}/${repo}" --json url --jq -r '.url // empty' 2>/dev/null || true)"
  [[ -n "$url" ]] || url="https://github.com/${GITHUB_ORG}/${repo}.git"
  echo "$url"
}

repo_has_remote_branch() {
  local repo="$1" branch="$2"
  require_cmd gh
  gh api "repos/${GITHUB_ORG}/${repo}/branches/${branch//\//%2F}" &>/dev/null
}
