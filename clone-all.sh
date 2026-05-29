#!/usr/bin/env bash
# Clone org repos by suite. Interactive picker or --prefix.
#
# Usage:
#   ./clone-all.sh                    # picker: 1=be 2=web 3=mobile 4=iac 5=all
#   molt clone --prefix web
#   molt clone --prefix all
#   ./clone-all.sh --repo be-user --dry-run
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/repos-common.sh
source "$SCRIPT_DIR/lib/repos-common.sh"
# shellcheck source=lib/ssh.sh
source "$SCRIPT_DIR/lib/ssh.sh"
# shellcheck source=lib/prefix.sh
source "$SCRIPT_DIR/lib/prefix.sh"

BRANCH="$MOLT_DEFAULT_BRANCH"
DRY_RUN=0
ONLY_REPO=""
PREFIX_ARG=""
PREFIX_EXPLICIT=0

clone_suite() {
  local PREFIX="$1"
  local WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(workspace_root_for_prefix "$PREFIX")}"
  local repos=() repo dir url failed=0

  echo ""
  echo "=== suite: ${PREFIX%-} ($WORKSPACE_ROOT) ==="

  if [[ -n "$ONLY_REPO" ]]; then
    repos=("$ONLY_REPO")
  else
    while IFS= read -r r; do repos+=("$r"); done < <(list_org_repos "$PREFIX")
  fi

  [[ ${#repos[@]} -gt 0 ]] || die "no ${PREFIX}* repos in ${GITHUB_ORG}"

  for repo in "${repos[@]}"; do
    dir="$WORKSPACE_ROOT/$repo"
    echo "--- $repo ---"
    if [[ -d "$dir/.git" ]]; then
      echo "  skip: already cloned"
      if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "  would: git -C $dir checkout $BRANCH"
        continue
      fi
      if checkout_branch "$dir" "$BRANCH"; then
        echo "  checked out $BRANCH"
      else
        failed=$((failed + 1))
      fi
      continue
    fi

    url="$(clone_url_for "$repo")"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  would: git clone $url $dir"
      echo "  would: git -C $dir checkout $BRANCH"
      continue
    fi

    if git clone "$url" "$dir"; then
      echo "  cloned ($url)"
      ensure_repo_origin_ssh "$dir" 2>/dev/null || true
      if checkout_branch "$dir" "$BRANCH"; then
        echo "  checked out $BRANCH"
      else
        failed=$((failed + 1))
      fi
    else
      echo "  WARNING: clone failed for $repo" >&2
      failed=$((failed + 1))
    fi
  done

  [[ "$failed" -eq 0 ]] || return 1
}

cmd_clone() {
  local prefixes=() p total_failed=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prefix)   PREFIX_ARG="${2:?}"; PREFIX_EXPLICIT=1; shift ;;
      --branch)   BRANCH="${2:?}"; shift ;;
      --repo)     ONLY_REPO="${2:?}"; shift ;;
      --dry-run)  DRY_RUN=1 ;;
      -h|--help)
        sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
      *) die "unknown flag: $1" ;;
    esac
    shift
  done

  require_cmd gh
  require_cmd git

  if [[ -n "$ONLY_REPO" ]]; then
    prefixes=("$(infer_prefix_from_repo "$ONLY_REPO")")
  elif [[ "$PREFIX_EXPLICIT" -eq 1 ]]; then
    while IFS= read -r p; do prefixes+=("$p"); done < <(expand_prefixes "$PREFIX_ARG")
  else
    while IFS= read -r p; do prefixes+=("$p"); done < <(resolve_prefixes "")
  fi

  for p in "${prefixes[@]}"; do
    clone_suite "$p" || total_failed=$((total_failed + 1))
  done

  [[ "$total_failed" -eq 0 ]] || die "$total_failed suite(s) had failures"
}

cmd_clone "$@"
