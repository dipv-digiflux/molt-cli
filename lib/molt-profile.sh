#!/usr/bin/env bash
# Single profile for all molt scripts. Override via env or a profile file (see below).
#
# Profile file search order (first found wins for each unset variable):
#   1. $MOLT_PROFILE (explicit path)
#   2. ~/.config/molt/profile.env
#   3. $MOLT_ROOT/.molt/profile.env

molt_scripts_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

molt_root() {
  if [[ -n "${MOLT_ROOT:-}" ]]; then
    echo "$MOLT_ROOT"
    return 0
  fi
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

_load_molt_profile_file() {
  local f
  for f in \
    "${MOLT_PROFILE:-}" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/molt/profile.env" \
    "$(molt_root)/.molt/profile.env"; do
    [[ -n "$f" && -f "$f" ]] || continue
    # shellcheck disable=SC1090
    source "$f"
    return 0
  done
}

profile_file_resolved() {
  if [[ -n "${MOLT_PROFILE:-}" && -f "$MOLT_PROFILE" ]]; then
    echo "$MOLT_PROFILE"
    return 0
  fi
  local f="${XDG_CONFIG_HOME:-$HOME/.config}/molt/profile.env"
  [[ -f "$f" ]] && echo "$f" && return 0
  f="$(molt_root)/.molt/profile.env"
  [[ -f "$f" ]] && echo "$f" && return 0
  echo ""
}

molt_load_profile() {
  _load_molt_profile_file

  : "${GITHUB_ORG:=molt-digiflux}"
  : "${MOLT_DEFAULT_BRANCH:=env/staging}"
  : "${MERGE_STYLE:=merge}"
  : "${GIT_PROMOTE_EMAIL:=promote@local}"
  : "${GIT_PROMOTE_NAME:=env-promote-script}"
  # Local commits in ~/Workspace/molt/scripts (repo-local git config only)
  : "${MOLT_SCRIPTS_GIT_NAME:=${GIT_PROMOTE_NAME}}"
  : "${MOLT_SCRIPTS_GIT_EMAIL:=${GIT_PROMOTE_EMAIL}}"
  : "${MOLT_GIT_PROTOCOL:=ssh}"
  : "${MOLT_GITHUB_HOST:=github.com}"
  : "${MOLT_CLI_VERSION:=0.1.0}"

  export MOLT_GIT_PROTOCOL MOLT_GITHUB_HOST MOLT_CLI_VERSION

  if [[ -z "${MOLT_ENV_CHAIN+set}" || ${#MOLT_ENV_CHAIN[@]} -eq 0 ]]; then
    MOLT_ENV_CHAIN=(
      "env/staging:env/uat"
      "env/uat:env/preprod"
      "env/preprod:env/prod"
    )
  fi

  export GITHUB_ORG MOLT_DEFAULT_BRANCH MERGE_STYLE
  export GIT_PROMOTE_EMAIL GIT_PROMOTE_NAME MOLT_ROOT
  export MOLT_ENV_CHAIN
}

# Run once when sourced (idempotent if called again).
molt_load_profile
