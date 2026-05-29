#!/usr/bin/env bash
# Clone every org repo matching a prefix (be-*, web-*, mobile-*) into molt/{be,web,mobile}/.
#
# Usage:
#   ./clone-all.sh
#   molt clone --prefix web
#   ./clone-all.sh --prefix mobile --branch env/staging
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

PREFIX=""
PREFIX_EXPLICIT=0
BRANCH="$MOLT_DEFAULT_BRANCH"
DRY_RUN=0
ONLY_REPO=""

cmd_clone() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prefix)   PREFIX="$(normalize_prefix "${2:?}")" || exit 1; PREFIX_EXPLICIT=1; shift ;;
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

  if [[ "$PREFIX_EXPLICIT" -eq 0 ]]; then
    PREFIX="$(resolve_default_prefix)"
  fi

  require_cmd gh
  require_cmd git

  WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(workspace_root_for_prefix "$PREFIX")}"

  local repos=()
  if [[ -n "$ONLY_REPO" ]]; then
    repos=("$ONLY_REPO")
  else
    while IFS= read -r r; do repos+=("$r"); done < <(list_org_repos "$PREFIX")
  fi

  [[ ${#repos[@]} -gt 0 ]] || die "no ${PREFIX}* repos in ${GITHUB_ORG}"

  local failed=0
  for repo in "${repos[@]}"; do
    local dir="$WORKSPACE_ROOT/$repo"
    echo "=== $repo ==="
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

    local url
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

  if [[ "$failed" -gt 0 ]]; then
    die "$failed repo(s) failed"
  fi
}

cmd_clone "$@"
