#!/usr/bin/env bash
# Checkout a branch and git pull in every local repo under molt/{be,web,mobile}/.
#
# Usage:
#   ./pull-all.sh
#   molt pull --prefix web --rebase
#   ./pull-all.sh --branch env/staging --repo be-user --dry-run
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/repos-common.sh
source "$SCRIPT_DIR/lib/repos-common.sh"
# shellcheck source=lib/prefix.sh
source "$SCRIPT_DIR/lib/prefix.sh"

PREFIX=""
PREFIX_EXPLICIT=0
BRANCH="$MOLT_DEFAULT_BRANCH"
PULL_MODE=""
DRY_RUN=0
ONLY_REPO=""

cmd_pull() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prefix)   PREFIX="$(normalize_prefix "${2:?}")" || exit 1; PREFIX_EXPLICIT=1; shift ;;
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

  if [[ "$PREFIX_EXPLICIT" -eq 0 ]]; then
    PREFIX="$(resolve_default_prefix)"
  fi

  require_cmd git

  WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(workspace_root_for_prefix "$PREFIX")}"

  local repos=()
  if [[ -n "$ONLY_REPO" ]]; then
    repos=("$ONLY_REPO")
    [[ -d "$WORKSPACE_ROOT/$ONLY_REPO/.git" ]] ||
      die "not a git repo: $WORKSPACE_ROOT/$ONLY_REPO"
  else
    while IFS= read -r r; do repos+=("$r"); done < <(list_workspace_repos "$WORKSPACE_ROOT" "$PREFIX")
  fi

  [[ ${#repos[@]} -gt 0 ]] || die "no ${PREFIX}* git repos under $WORKSPACE_ROOT"

  local failed=0
  for repo in "${repos[@]}"; do
    local dir="$WORKSPACE_ROOT/$repo"
    echo "=== $repo ==="
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

  if [[ "$failed" -gt 0 ]]; then
    die "$failed repo(s) failed to pull"
  fi
}

cmd_pull "$@"
