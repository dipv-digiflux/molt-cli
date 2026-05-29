#!/usr/bin/env bash
# Workspace health check (used by: molt check)

cmd_check() {
  local PREFIX
  PREFIX="$(normalize_prefix "${MOLT_DEFAULT_PREFIX}")" || return 1
  local BRANCH="${MOLT_DEFAULT_BRANCH}"
  local ONLY_REPO=""
  local QUIET=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prefix)   PREFIX="$(normalize_prefix "${2:?}")" || return 1; shift ;;
      --branch)   BRANCH="${2:?}"; shift ;;
      --repo)     ONLY_REPO="${2:?}"; shift ;;
      --quiet|-q) QUIET=1 ;;
      -h|--help)
        cat <<'EOF'
molt check — verify tools, auth, and local repos

Usage:
  molt check
  molt check --prefix web
  molt check --branch env/staging
  molt check --repo be-user
  molt check --quiet

Exit 0 if all checks pass; 1 if any hard failure (missing tools, gh auth, repo errors).
EOF
        return 0
        ;;
      *) die "unknown flag: $1" ;;
    esac
    shift
  done

  local failed=0 warn=0
  local say_ok say_warn say_fail
  say_ok()   { [[ "$QUIET" -eq 1 ]] || echo "  ok: $*"; }
  say_warn() { warn=$((warn + 1)); echo "  warn: $*" >&2; }
  say_fail() { failed=$((failed + 1)); echo "  fail: $*" >&2; }

  echo "=== molt check ==="
  echo "root:   $(molt_root)"
  echo "org:    $GITHUB_ORG"
  echo "prefix: $PREFIX"
  echo "branch: $BRANCH"
  profile_path="${MOLT_PROFILE:-}"
  [[ -z "$profile_path" && -f "${XDG_CONFIG_HOME:-$HOME/.config}/molt/profile.env" ]] &&
    profile_path="${XDG_CONFIG_HOME:-$HOME/.config}/molt/profile.env"
  [[ -z "$profile_path" && -f "$(molt_root)/.molt/profile.env" ]] &&
    profile_path="$(molt_root)/.molt/profile.env"
  echo "profile: ${profile_path:-<defaults only>}"

  echo ""
  echo "--- tools ---"
  for c in git gh; do
    if command -v "$c" >/dev/null; then
      say_ok "$c $(command -v "$c")"
    else
      say_fail "$c not installed"
    fi
  done
  if command -v jq >/dev/null; then
    say_ok "jq (optional, for JSON)"
  else
    say_warn "jq not installed (optional)"
  fi

  echo ""
  echo "--- github ---"
  if command -v gh >/dev/null; then
    if gh auth status -h github.com &>/dev/null; then
      say_ok "gh authenticated"
      if gh api "orgs/${GITHUB_ORG}" --jq '.login' &>/dev/null 2>&1; then
        say_ok "org access: $GITHUB_ORG"
      else
        say_warn "cannot read org $GITHUB_ORG (token scope or membership?)"
      fi
    else
      say_fail "gh not logged in (run: gh auth login)"
    fi
  fi

  local WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(workspace_root_for_prefix "$PREFIX")}"
  echo ""
  echo "--- workspace ($WORKSPACE_ROOT) ---"
  if [[ -d "$WORKSPACE_ROOT" ]]; then
    say_ok "directory exists"
  else
    say_warn "directory missing (run: molt clone --prefix ${PREFIX%-})"
  fi

  local repos=()
  if [[ -n "$ONLY_REPO" ]]; then
    repos=("$ONLY_REPO")
    [[ -d "$WORKSPACE_ROOT/$ONLY_REPO/.git" ]] ||
      say_fail "not a git repo: $WORKSPACE_ROOT/$ONLY_REPO"
  elif [[ -d "$WORKSPACE_ROOT" ]]; then
    while IFS= read -r r; do repos+=("$r"); done < <(list_workspace_repos "$WORKSPACE_ROOT" "$PREFIX")
  fi

  if [[ ${#repos[@]} -eq 0 && -d "$WORKSPACE_ROOT" ]]; then
    say_warn "no ${PREFIX}* git repos under $WORKSPACE_ROOT"
  fi

  echo ""
  echo "--- repos (${#repos[@]}) ---"
  local repo dir branch dirty behind
  for repo in "${repos[@]}"; do
    dir="$WORKSPACE_ROOT/$repo"
    echo "=== $repo ==="
    branch="$(git -C "$dir" symbolic-ref -q --short HEAD 2>/dev/null || git -C "$dir" rev-parse --short HEAD 2>/dev/null || echo "?")"
    if [[ "$branch" == "$BRANCH" ]]; then
      say_ok "on $BRANCH"
    else
      say_warn "on $branch (expected $BRANCH)"
    fi
    if [[ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]]; then
      dirty=1
      say_warn "uncommitted changes"
    else
      say_ok "clean working tree"
    fi
    git -C "$dir" fetch -q origin "$BRANCH" 2>/dev/null || git -C "$dir" fetch -q origin 2>/dev/null || true
    behind="$(git -C "$dir" rev-list --count "HEAD..origin/$BRANCH" 2>/dev/null || echo "")"
    if [[ -n "$behind" && "$behind" -gt 0 ]]; then
      say_warn "$behind commit(s) behind origin/$BRANCH"
    elif git -C "$dir" show-ref --verify --quiet "refs/remotes/origin/$BRANCH" 2>/dev/null; then
      say_ok "up to date with origin/$BRANCH"
    else
      say_warn "origin/$BRANCH not found locally"
    fi
    if command -v gh >/dev/null; then
      for pair in "${MOLT_ENV_CHAIN[@]}"; do
        IFS=: read -r head base <<<"$pair"
        repo_has_remote_branch "$repo" "$head" || say_warn "remote missing $head"
        repo_has_remote_branch "$repo" "$base" || say_warn "remote missing $base"
      done
    fi
  done

  echo ""
  echo "--- scripts repo (local git) ---"
  local srepo
  srepo="$(molt_scripts_dir)"
  if [[ -d "$srepo/.git" ]]; then
    say_ok "initialized at $srepo"
    if git -C "$srepo" rev-parse HEAD &>/dev/null; then
      say_ok "HEAD $(git -C "$srepo" rev-parse --short HEAD) — $(git -C "$srepo" log -1 --format='%s' 2>/dev/null)"
    else
      say_warn "no commits yet (run: molt setup-git --commit)"
    fi
    if [[ -n "$(git -C "$srepo" status --porcelain 2>/dev/null)" ]]; then
      say_warn "uncommitted script changes"
    else
      say_ok "scripts tree clean"
    fi
  else
    say_warn "not initialized (run: molt setup-git)"
  fi

  echo ""
  echo "--- env promote chain ---"
  for pair in "${MOLT_ENV_CHAIN[@]}"; do
    IFS=: read -r head base <<<"$pair"
    echo "  $head -> $base"
  done

  echo ""
  if [[ "$failed" -gt 0 ]]; then
    echo "result: FAIL ($failed error(s), $warn warning(s))"
    return 1
  fi
  if [[ "$warn" -gt 0 ]]; then
    echo "result: OK with warnings ($warn)"
    return 0
  fi
  echo "result: OK"
  return 0
}
