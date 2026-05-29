#!/usr/bin/env bash
# Pull local repos by suite. Interactive picker or --prefix.
#
# Usage:
#   ./pull-all.sh                     # picker: be web mobile iaac other all
#   molt pull --prefix all --rebase
#   ./pull-all.sh --repo be-user --dry-run
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/repos-common.sh
source "$SCRIPT_DIR/lib/repos-common.sh"
# shellcheck source=lib/prefix.sh
source "$SCRIPT_DIR/lib/prefix.sh"

BRANCH="$MOLT_DEFAULT_BRANCH"
PULL_MODE=""
DRY_RUN=0
ONLY_REPO=""
PREFIX_ARG=""
PREFIX_EXPLICIT=0

pull_suite() {
  local PREFIX="$1"
  local WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(workspace_root_for_prefix "$PREFIX")}"
  local repos=() repo dir failed=0

  echo ""
  echo "=== suite: ${PREFIX%-} ($WORKSPACE_ROOT) ==="

  if [[ -n "$ONLY_REPO" ]]; then
    repos=("$ONLY_REPO")
    [[ -d "$WORKSPACE_ROOT/$ONLY_REPO/.git" ]] ||
      die "not a git repo: $WORKSPACE_ROOT/$ONLY_REPO"
  else
    while IFS= read -r r; do repos+=("$r"); done < <(list_workspace_repos "$WORKSPACE_ROOT" "$PREFIX")
  fi

  [[ ${#repos[@]} -gt 0 ]] || die "no ${PREFIX}* git repos under $WORKSPACE_ROOT"

  for repo in "${repos[@]}"; do
    dir="$WORKSPACE_ROOT/$repo"
    echo "--- $repo ---"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  would: git -C $dir fetch origin $BRANCH"
      echo "  would: git -C $dir checkout $BRANCH"
      echo "  would: git -C $dir pull origin $BRANCH ${PULL_MODE:+$PULL_MODE}"
      continue
    fi

    if ! checkout_branch "$dir" "$BRANCH"; then
      echo "  WARNING: checkout failed for $repo" >&2
      failed=$((failed + 1))
      continue
    fi

    if git -C "$dir" pull origin "$BRANCH" ${PULL_MODE:+$PULL_MODE}; then
      echo "  ok ($BRANCH)"
    else
      echo "  WARNING: pull failed for $repo" >&2
      failed=$((failed + 1))
    fi
  done

  [[ "$failed" -eq 0 ]] || return 1
}

cmd_pull() {
  local prefixes=() p total_failed=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prefix)   PREFIX_ARG="${2:?}"; PREFIX_EXPLICIT=1; shift ;;
      --branch)   BRANCH="${2:?}"; shift ;;
      --rebase)   PULL_MODE="--rebase" ;;
      --ff-only)  PULL_MODE="--ff-only" ;;
      --repo)     ONLY_REPO="${2:?}"; shift ;;
      --dry-run)  DRY_RUN=1 ;;
      -h|--help)
        sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
      *) die "unknown flag: $1" ;;
    esac
    shift
  done

  require_cmd git

  if [[ -n "$ONLY_REPO" ]]; then
    prefixes=("$(infer_prefix_from_repo "$ONLY_REPO")")
  elif [[ "$PREFIX_EXPLICIT" -eq 1 ]]; then
    while IFS= read -r p; do prefixes+=("$p"); done < <(expand_prefixes "$PREFIX_ARG")
  else
    while IFS= read -r p; do prefixes+=("$p"); done < <(resolve_prefixes "")
  fi

  for p in "${prefixes[@]}"; do
    pull_suite "$p" || total_failed=$((total_failed + 1))
  done

  [[ "$total_failed" -eq 0 ]] || die "$total_failed suite(s) failed to pull"
}

cmd_pull "$@"
