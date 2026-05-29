#!/usr/bin/env bash
# Workspace health check (molt-cli check)

_check_suite_repos() {
  local PREFIX="$1"
  local WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(workspace_root_for_prefix "$PREFIX")}"
  local repos=() repo dir branch origin_url

  echo ""
  echo "--- workspace: ${PREFIX%-} ($WORKSPACE_ROOT) ---"
  if [[ -d "$WORKSPACE_ROOT" ]]; then
    say_ok "directory exists"
  else
    say_warn "missing (run: molt-cli clone --prefix ${PREFIX%-})"
  fi

  repos=()
  if [[ -n "$ONLY_REPO" ]]; then
    repos=("$ONLY_REPO")
    [[ -d "$WORKSPACE_ROOT/$ONLY_REPO/.git" ]] ||
      say_fail "not a git repo: $WORKSPACE_ROOT/$ONLY_REPO"
  elif [[ -d "$WORKSPACE_ROOT" ]]; then
    while IFS= read -r r; do repos+=("$r"); done < <(list_workspace_repos "$WORKSPACE_ROOT" "$PREFIX")
  fi

  if [[ ${#repos[@]} -eq 0 && -d "$WORKSPACE_ROOT" ]]; then
    say_warn "no ${PREFIX}* git repos"
  fi

  echo ""
  echo "--- repos ${PREFIX%-} (${#repos[@]}) ---"
  for repo in "${repos[@]}"; do
    dir="$WORKSPACE_ROOT/$repo"
    echo "=== $repo ==="
    origin_url="$(git -C "$dir" remote get-url origin 2>/dev/null || echo "?")"
    if is_ssh_url "$origin_url"; then
      say_ok "origin SSH: $origin_url"
    else
      say_warn "origin not SSH: $origin_url (molt-cli ssh fix)"
    fi
    branch="$(git -C "$dir" symbolic-ref -q --short HEAD 2>/dev/null || git -C "$dir" rev-parse --short HEAD 2>/dev/null || echo "?")"
    if [[ "$branch" == "$BRANCH" ]]; then
      say_ok "on $BRANCH"
    else
      say_warn "on $branch (expected $BRANCH)"
    fi
    if [[ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]]; then
      say_warn "uncommitted changes"
    else
      say_ok "clean working tree"
    fi
    git -C "$dir" fetch -q origin "$BRANCH" 2>/dev/null || git -C "$dir" fetch -q origin 2>/dev/null || true
    local behind
    behind="$(git -C "$dir" rev-list --count "HEAD..origin/$BRANCH" 2>/dev/null || echo "")"
    if [[ -n "$behind" && "$behind" -gt 0 ]]; then
      say_warn "$behind commit(s) behind origin/$BRANCH"
    elif git -C "$dir" show-ref --verify --quiet "refs/remotes/origin/$BRANCH" 2>/dev/null; then
      say_ok "up to date with origin/$BRANCH"
    else
      say_warn "origin/$BRANCH not found locally"
    fi
    if [[ "$QUICK" -eq 0 ]] && command -v gh >/dev/null; then
      for pair in "${MOLT_ENV_CHAIN[@]}"; do
        IFS=: read -r head base <<<"$pair"
        repo_has_remote_branch "$repo" "$head" || say_warn "remote missing $head"
        repo_has_remote_branch "$repo" "$base" || say_warn "remote missing $base"
      done
    fi
  done
}

cmd_check() {
  local BRANCH="${MOLT_DEFAULT_BRANCH}"
  local ONLY_REPO=""
  local QUIET=0
  local QUICK=0
  local PREFIX_ARG=""
  local PREFIX_EXPLICIT=0
  local prefixes=() p label

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prefix)   PREFIX_ARG="${2:?}"; PREFIX_EXPLICIT=1; shift ;;
      --branch)   BRANCH="${2:?}"; shift ;;
      --repo)     ONLY_REPO="${2:?}"; shift ;;
      --quiet|-q) QUIET=1 ;;
      --quick)    QUICK=1 ;;
      -h|--help)
        cat <<'EOF'
molt-cli check — verify tools, GitHub auth, SSH, and local repos

Usage:
  molt-cli check                  Interactive picker (be/web/mobile/iac/all)
  molt-cli check --quick          Skip slow per-repo GitHub API branch checks
  molt-cli check --prefix web
  molt-cli check --prefix all
  molt-cli check --repo be-user

Exit 0 on success (warnings allowed); 1 on hard failures.
EOF
        return 0
        ;;
      *) die "unknown flag: $1" ;;
    esac
    shift
  done

  local failed=0 warn=0
  say_ok()   { [[ "$QUIET" -eq 1 ]] || echo "  ok: $*"; }
  say_warn() { warn=$((warn + 1)); echo "  warn: $*" >&2; }
  say_fail() { failed=$((failed + 1)); echo "  fail: $*" >&2; }

  if [[ -n "$ONLY_REPO" ]]; then
    prefixes=("$(infer_prefix_from_repo "$ONLY_REPO")")
    label="${prefixes[0]%-}"
  elif [[ "$PREFIX_EXPLICIT" -eq 1 ]]; then
    while IFS= read -r p; do prefixes+=("$p"); done < <(expand_prefixes "$PREFIX_ARG")
    label="${PREFIX_ARG}"
  else
    while IFS= read -r p; do prefixes+=("$p"); done < <(resolve_prefixes "")
    label="picked"
  fi

  echo "=== molt-cli check ==="
  echo "version: $(molt_cli_version)"
  echo "root:    $(molt_root)"
  echo "org:     $GITHUB_ORG"
  echo "suite:   $label"
  echo "branch:  $BRANCH"
  echo "git:     ${MOLT_GIT_PROTOCOL:-ssh}"
  echo "profile: $(profile_file_resolved || echo '<defaults>')"

  echo ""
  echo "--- tools ---"
  for c in git gh ssh; do
    if command -v "$c" >/dev/null; then
      say_ok "$c $(command -v "$c")"
    else
      say_fail "$c not installed"
    fi
  done
  if command -v jq >/dev/null; then
    say_ok "jq (optional)"
  else
    say_warn "jq not installed (optional)"
  fi

  echo ""
  echo "--- ssh (git@${MOLT_GITHUB_HOST:-github.com}) ---"
  if command -v ssh >/dev/null; then
    if ssh_agent_has_keys; then
      say_ok "ssh-agent has keys"
    else
      say_warn "ssh-agent empty (ssh-add your key)"
    fi
    if test_github_ssh; then
      say_ok "GitHub SSH authentication"
    else
      say_fail "GitHub SSH failed (run: molt-cli ssh setup)"
    fi
  fi
  local gh_proto
  gh_proto="$(gh config get git_protocol -h github.com 2>/dev/null || echo "?")"
  if [[ "$gh_proto" == "ssh" ]]; then
    say_ok "gh git_protocol=ssh"
  else
    say_warn "gh git_protocol=$gh_proto (run: molt-cli ssh setup)"
  fi

  echo ""
  echo "--- github (gh api) ---"
  if command -v gh >/dev/null; then
    if gh auth status -h github.com &>/dev/null; then
      say_ok "gh authenticated"
      if gh api "orgs/${GITHUB_ORG}" --jq '.login' &>/dev/null 2>&1; then
        say_ok "org access: $GITHUB_ORG"
      else
        say_warn "cannot read org $GITHUB_ORG"
      fi
    else
      say_fail "gh not logged in (gh auth login)"
    fi
  fi

  for p in "${prefixes[@]}"; do
    _check_suite_repos "$p"
  done

  echo ""
  echo "--- molt-cli repo ---"
  local srepo
  srepo="$(molt_scripts_dir)"
  if [[ -d "$srepo/.git" ]]; then
    say_ok "initialized at $srepo"
    if git -C "$srepo" rev-parse HEAD &>/dev/null; then
      say_ok "HEAD $(git -C "$srepo" rev-parse --short HEAD)"
    else
      say_warn "no commits (molt-cli setup-git --commit)"
    fi
    [[ -z "$(git -C "$srepo" status --porcelain 2>/dev/null)" ]] && say_ok "clean" || say_warn "uncommitted changes"
  else
    say_warn "not initialized (molt-cli setup-git)"
  fi

  echo ""
  if [[ "$failed" -gt 0 ]]; then
    echo "result: FAIL ($failed error(s), $warn warning(s))"
    echo "hint:   molt-cli info && molt-cli ssh setup --fix"
    return 1
  fi
  if [[ "$warn" -gt 0 ]]; then
    echo "result: OK with warnings ($warn)"
    return 0
  fi
  echo "result: OK"
  return 0
}
