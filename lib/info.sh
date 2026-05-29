#!/usr/bin/env bash
# Open dump of all molt-cli configuration (molt-cli info).

molt_cli_version() {
  echo "${MOLT_CLI_VERSION:-0.1.0}"
}

_info_picker_lines() {
  local s root
  echo "  clone, pull, check, ssh fix — ask every run (no saved default)"
  echo ""
  echo "  Picker menu:"
  local i=1
  for s in "${MOLT_VALID_SUITES[@]}"; do
    root="$(workspace_root_for_prefix "${s}-")"
    printf "    %s) %s-*   → %s\n" "$i" "$s" "$root"
    i=$((i + 1))
  done
  printf "    %s) all      → be + web + mobile + iac\n" "$i"
  echo ""
  echo "  Skip picker:"
  echo "    molt-cli clone --prefix be"
  echo "    molt-cli pull --prefix all"
  echo "    molt-cli check --prefix web --quick"
  echo "    molt-cli ssh fix --prefix all"
  echo ""
  echo "  Single repo (--repo) infers suite from name (be-user → be)."
}

_info_add_prefix_lines() {
  cat <<'EOF'
  To add a new suite (e.g. data-* → molt/data/):

  1. lib/repos-common.sh
       MOLT_VALID_SUITES=(be web mobile iac data)

  2. lib/prefix.sh
       _prefix_menu     — add menu line (e.g. 6) data-*)
       _read_prefix_choice — add 6|data) case

  3. expand_prefixes — "all" loops MOLT_VALID_SUITES (new suite included)

  4. Create folder: mkdir -p ~/Workspace/molt/data

  5. Update README.md and .molt/profile.env.example

  6. molt-cli info   (verify workspace_data path)
EOF
}

cmd_info() {
  local json=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json=1 ;;
      -h|--help)
        cat <<'EOF'
molt-cli info — show all config, paths, picker, and commands

  molt-cli info
  molt-cli info --json   (key=value lines, easy to grep)

Shows org, branch, SSH, workspaces, suite picker help, and how to add prefixes.
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
  _kv suite_picker "interactive each run (no saved default)"
  _kv valid_suites "${MOLT_VALID_SUITES[*]}"
  _kv picker_all "runs every suite in valid_suites"
  _kv default_branch "$MOLT_DEFAULT_BRANCH"
  _kv git_protocol "${MOLT_GIT_PROTOCOL:-ssh}"

  local s root n i=1
  for s in "${MOLT_VALID_SUITES[@]}"; do
    root="$(workspace_root_for_prefix "${s}-")"
    if [[ "$json" -eq 1 ]]; then
      _kv "picker_${i}" "${s}-* → ${root}"
    fi
    i=$((i + 1))
  done
  if [[ "$json" -eq 1 ]]; then
    _kv "picker_${i}" "all → ${MOLT_VALID_SUITES[*]}"
    _kv prefix_flag "--prefix be|web|mobile|iac|all"
  fi

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
    echo "--- suite picker ---"
    _info_picker_lines
    echo ""
    echo "--- add a new prefix ---"
    _info_add_prefix_lines
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
    echo "--- commands ---"
    cat <<'EOF'
  molt-cli info              This summary
  molt-cli check             Health (picker or --prefix)
  molt-cli check --quick     Faster check
  molt-cli ssh setup --fix   SSH + fix remotes
  molt-cli install           ~/.local/bin install
  molt-cli activate          source ~/.config/molt/activate
  molt-cli clone             Clone (picker: 1-5 or --prefix all)
  molt-cli pull              Pull (same picker)
  molt-cli promote list      List org repos (all suites)
  molt-cli promote merge-all Env branch promotion
  molt-cli setup-git         Local git for scripts repo
  molt-cli git status        Git in scripts repo only

Profile: ~/.config/molt/profile.env
Help:    molt-cli <command> --help
EOF
  fi
}
