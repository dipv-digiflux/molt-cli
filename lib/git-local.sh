#!/usr/bin/env bash
# Local git for the molt scripts repo only (never touches global git config).

molt_scripts_repo() {
  molt_scripts_dir
}

molt_scripts_git_identity() {
  local name="${MOLT_SCRIPTS_GIT_NAME:-}"
  local email="${MOLT_SCRIPTS_GIT_EMAIL:-}"
  [[ -n "$name" ]]  || name="${GIT_PROMOTE_NAME:-}"
  [[ -n "$email" ]] || email="${GIT_PROMOTE_EMAIL:-}"
  if [[ -z "$name" ]]; then
    name="$(git config --global user.name 2>/dev/null || true)"
  fi
  if [[ -z "$email" ]]; then
    email="$(git config --global user.email 2>/dev/null || true)"
  fi
  if [[ -z "$name" || -z "$email" ]]; then
    echo "error: set MOLT_SCRIPTS_GIT_NAME and MOLT_SCRIPTS_GIT_EMAIL in ~/.config/molt/profile.env" >&2
    echo "       (or GIT_PROMOTE_NAME / GIT_PROMOTE_EMAIL, or global git user.name / user.email)" >&2
    return 1
  fi
  printf '%s\n%s' "$name" "$email"
}

apply_scripts_repo_config() {
  local repo="$1" name email
  read -r name email < <(molt_scripts_git_identity) || return 1
  git -C "$repo" config user.name "$name"
  git -C "$repo" config user.email "$email"
  git -C "$repo" config init.defaultBranch main
  git -C "$repo" config core.autocrlf input
  git -C "$repo" config pull.ff only
  git -C "$repo" config advice.detachedHead false
  true
}

cmd_setup_git() {
  local do_commit=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --commit) do_commit=1 ;;
      -h|--help)
        cat <<'EOF'
molt setup-git — init local git for this molt-cli repo

Applies repo-local user.name / user.email (never --global).

Identity (first match):
  MOLT_SCRIPTS_GIT_NAME / MOLT_SCRIPTS_GIT_EMAIL in profile
  GIT_PROMOTE_NAME / GIT_PROMOTE_EMAIL in profile
  global git user.name / user.email

Options:
  --commit   Create initial commit if the repo has no commits yet

After setup:
  git -C ~/Workspace/molt/molt-cli log --oneline
  molt git status
EOF
        return 0
        ;;
      *) die "unknown flag: $1" ;;
    esac
    shift
  done

  require_cmd git

  local repo
  repo="$(molt_scripts_repo)"

  if [[ ! -d "$repo/.git" ]]; then
    git -C "$repo" init -b main
    echo "initialized: $repo (.git)"
  else
    echo "already initialized: $repo"
  fi

  apply_scripts_repo_config "$repo" || return 1

  local name email
  read -r name email < <(molt_scripts_git_identity)
  echo "local config: user.name=$name user.email=$email branch=$(git -C "$repo" symbolic-ref --short HEAD 2>/dev/null || echo main)"

  if [[ "$do_commit" -eq 1 ]]; then
    if git -C "$repo" rev-parse HEAD &>/dev/null; then
      echo "skip commit: repository already has commits"
    else
      git -C "$repo" add -A
      if git -C "$repo" diff --cached --quiet; then
        echo "nothing to commit"
      else
        git -C "$repo" commit -m "$(cat <<'EOF'
chore: initial molt-cli workspace tooling

Unified molt CLI, profile, check, clone/pull/promote helpers.
EOF
)"
        echo "created initial commit: $(git -C "$repo" rev-parse --short HEAD)"
      fi
    fi
  else
    echo "tip: molt setup-git --commit  (or: cd $repo && git add -A && git commit)"
  fi
}

cmd_git() {
  local sub="${1:-status}"
  shift || true

  require_cmd git

  local repo
  repo="$(molt_scripts_repo)"
  [[ -d "$repo/.git" ]] || die "molt-cli repo not initialized (run: molt setup-git)"

  case "$sub" in
    status|log|diff|show|branch|tag)
      git -C "$repo" "$sub" "$@"
      ;;
    -h|--help)
      cat <<'EOF'
molt git — run git in the molt-cli repo (local version control)

  molt git status
  molt git log --oneline -10
  molt git diff
  molt git tag v1.0.0

For commits, use git -C ~/Workspace/molt/molt-cli ... or cd there.
Repo-local identity comes from profile (MOLT_SCRIPTS_GIT_*).
EOF
      ;;
    *)
      die "unsupported: molt git $sub (try: status, log, diff, tag)"
      ;;
  esac
}
