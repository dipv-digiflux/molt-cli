#!/usr/bin/env bash
# SSH-first git helpers for molt-cli.

molt_github_ssh_host() {
  echo "${MOLT_GITHUB_HOST:-github.com}"
}

is_ssh_url() {
  [[ "$1" =~ ^git@ ]] || [[ "$1" =~ ^ssh:// ]]
}

test_github_ssh() {
  local host out
  host="$(molt_github_ssh_host)"
  out="$(ssh -o BatchMode=yes -o ConnectTimeout=10 -T "git@${host}" 2>&1)" || true
  if [[ "$out" == *"successfully authenticated"* ]] || [[ "$out" == *"You've successfully authenticated"* ]]; then
    return 0
  fi
  [[ "$out" == *"Hi "* ]] && return 0
  return 1
}

ssh_agent_has_keys() {
  [[ -n "${SSH_AUTH_SOCK:-}" ]] && ssh-add -l &>/dev/null
}

apply_gh_git_ssh() {
  command -v gh >/dev/null || return 0
  local current
  current="$(gh config get git_protocol -h github.com 2>/dev/null || true)"
  if [[ "$current" != "ssh" ]]; then
    gh config set git_protocol ssh -h github.com 2>/dev/null || true
    echo "  set gh git_protocol=ssh for github.com"
  fi
}

ensure_repo_origin_ssh() {
  local dir="$1" repo url current
  [[ -d "$dir/.git" ]] || return 1
  repo="$(basename "$dir")"
  url="$(ssh_url_for_repo "$repo")"
  current="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
  [[ -z "$current" ]] && return 1
  if is_ssh_url "$current"; then
    return 0
  fi
  if [[ "${MOLT_GIT_PROTOCOL:-ssh}" != "ssh" ]]; then
    return 0
  fi
  git -C "$dir" remote set-url origin "$url"
  echo "  $repo: origin -> $url"
}

cmd_ssh() {
  local sub="${1:-test}"
  shift || true
  local PREFIX="" fix=0 prefix_explicit=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prefix) PREFIX="$(normalize_prefix "${2:?}")" || return 1; prefix_explicit=1; shift ;;
      --fix)    fix=1 ;;
      -h|--help)
        cat <<'EOF'
molt-cli ssh — GitHub SSH for git operations

  molt-cli ssh              Test SSH to GitHub (same as: ssh test)
  molt-cli ssh test         Test git@github.com authentication
  molt-cli ssh keys         List keys loaded in ssh-agent
  molt-cli ssh fix          Rewrite workspace remotes to SSH URLs
  molt-cli ssh setup        gh git_protocol=ssh + test + optional --fix

Options:
  --prefix be|web|mobile|iac   Suite for fix (default from profile)
  --fix                    With setup: also fix remotes
EOF
        return 0
        ;;
      *) die "unknown flag: $1" ;;
    esac
    shift
  done

  if [[ "$prefix_explicit" -eq 0 ]]; then
    PREFIX="$(resolve_default_prefix)" || return 1
  fi

  require_cmd ssh
  require_cmd git

  case "$sub" in
    test)
      echo "=== ssh test (git@$(molt_github_ssh_host)) ==="
      if ssh_agent_has_keys; then
        echo "ssh-agent: keys loaded"
        ssh-add -l 2>/dev/null | sed 's/^/  /'
      else
        echo "ssh-agent: no keys (start agent and: ssh-add ~/.ssh/id_ed25519)"
      fi
      if test_github_ssh; then
        echo "github: authenticated via SSH"
        return 0
      fi
      echo "github: SSH auth failed (check keys and github.com SSH keys)" >&2
      return 1
      ;;
    keys)
      if ssh_agent_has_keys; then
        ssh-add -l
      else
        echo "no keys in ssh-agent"
        return 1
      fi
      ;;
    fix)
      local root="$WORKSPACE_ROOT"
      root="${root:-$(workspace_root_for_prefix "$PREFIX")}"
      echo "=== fix remotes -> SSH ($root) ==="
      local n=0 repo dir
      while IFS= read -r repo; do
        dir="$root/$repo"
        ensure_repo_origin_ssh "$dir" && n=$((n + 1))
      done < <(list_workspace_repos "$root" "$PREFIX")
      echo "done: $n repo(s) checked under $root"
      ;;
    setup)
      echo "=== ssh setup ==="
      apply_gh_git_ssh
      cmd_ssh test || return 1
      if [[ "$fix" -eq 1 ]]; then
        cmd_ssh fix --prefix "${PREFIX%-}"
      fi
      ;;
    *)
      die "unknown: molt-cli ssh $sub (try: test, keys, fix, setup)"
      ;;
  esac
}
