#!/usr/bin/env bash
# Open dump of all molt-cli configuration (molt-cli info).

molt_cli_version() {
  echo "${MOLT_CLI_VERSION:-0.1.0}"
}

cmd_info() {
  local json=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json=1 ;;
      -h|--help)
        cat <<'EOF'
molt-cli info — show all config, paths, and available commands

  molt-cli info
  molt-cli info --json   (key=value lines, easy to grep)

Use before any operation to see org, branch, SSH mode, and workspace paths.
EOF
        return 0
        ;;
      *) die "unknown flag: $1" ;;
    esac
    shift
  done

  local pf
  pf="$(profile_file_resolved)"

  _kv() {
    if [[ "$json" -eq 1 ]]; then
      printf '%s=%s\n' "$1" "$2"
    else
      printf '  %-22s %s\n' "$1:" "$2"
    fi
  }

  if [[ "$json" -eq 0 ]]; then
    echo "=== molt-cli info ==="
    echo ""
    echo "--- identity ---"
  fi
  _kv version "$(molt_cli_version)"
  _kv cli_home "$(molt_scripts_dir)"
  _kv molt_root "$(molt_root)"
  _kv profile "${pf:-<defaults only>}"
  _kv github_org "$GITHUB_ORG"
  if [[ -n "${MOLT_DEFAULT_PREFIX:-}" ]]; then
    _kv default_prefix "$MOLT_DEFAULT_PREFIX"
  else
    _kv default_prefix "<not set — run: molt-cli configure prefix>"
  fi
  _kv valid_prefixes "${MOLT_VALID_SUITES[*]}"
  _kv default_branch "$MOLT_DEFAULT_BRANCH"
  _kv git_protocol "${MOLT_GIT_PROTOCOL:-ssh}"

  if [[ "$json" -eq 0 ]]; then
    echo ""
    echo "--- git / ssh ---"
  fi
  _kv github_host "$(molt_github_ssh_host)"
  _kv gh_git_protocol "$(gh config get git_protocol -h github.com 2>/dev/null || echo n/a)"
  _kv ssh_auth_sock "${SSH_AUTH_SOCK:-<unset>}"
  if ssh_agent_has_keys 2>/dev/null; then
    _kv ssh_agent "keys loaded"
  else
    _kv ssh_agent "no keys"
  fi
  if test_github_ssh 2>/dev/null; then
    _kv github_ssh "ok"
  else
    _kv github_ssh "fail"
  fi
  _kv scripts_git_name "${MOLT_SCRIPTS_GIT_NAME:-}"
  _kv scripts_git_email "${MOLT_SCRIPTS_GIT_EMAIL:-}"
  _kv promote_git_name "${GIT_PROMOTE_NAME:-}"
  _kv promote_git_email "${GIT_PROMOTE_EMAIL:-}"
  _kv merge_style "$MERGE_STYLE"

  if [[ "$json" -eq 0 ]]; then
    echo ""
    echo "--- workspaces ---"
  fi
  local s root n
  for s in "${MOLT_VALID_SUITES[@]}"; do
    root="$(workspace_root_for_prefix "${s}-")"
    if [[ -d "$root" ]]; then
      n="$(list_workspace_repos "$root" "${s}-" | wc -l | tr -d ' ')"
      _kv "workspace_${s}" "$root ($n repos)"
    else
      _kv "workspace_${s}" "$root (missing)"
    fi
  done

  if [[ "$json" -eq 0 ]]; then
    echo ""
    echo "--- env promote chain ---"
  fi
  local pair head base i=0
  for pair in "${MOLT_ENV_CHAIN[@]}"; do
    IFS=: read -r head base <<<"$pair"
    _kv "chain_${i}" "${head} -> ${base}"
    i=$((i + 1))
  done

  if [[ "$json" -eq 0 ]]; then
    echo ""
    echo "--- commands (run one at a time) ---"
    cat <<'EOF'
  molt-cli info              This summary (all settings open)
  molt-cli check             Health: tools, gh, ssh, repos
  molt-cli check --quick     Faster check (skip remote branch API)
  molt-cli ssh test          Test GitHub SSH
  molt-cli ssh setup --fix   gh ssh + test + fix HTTPS remotes
  molt-cli configure prefix  Set be | web | mobile | iac (saved to profile)
  molt-cli install           Private install (~/.local/bin)
  molt-cli activate          Per-shell only: source <(molt-cli activate --print)
  molt-cli clone             Clone org repos (SSH URLs)
  molt-cli pull              Pull all local repos
  molt-cli promote list      List org repos for promotion
  molt-cli promote merge-all Promote env branches (PR or --ssh-push)
  molt-cli setup-git         Version-control the scripts repo
  molt-cli git status        Git in scripts repo only

Profile: ~/.config/molt/profile.env  (copy from scripts/.molt/profile.env.example)
EOF
  fi
}
