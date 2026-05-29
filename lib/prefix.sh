#!/usr/bin/env bash
# Interactive MOLT_DEFAULT_PREFIX selection (be | web | mobile | iac).

prefix_is_valid() {
  local p="${1%-}"
  local s
  for s in "${MOLT_VALID_SUITES[@]}"; do
    [[ "$p" == "$s" ]] && return 0
  done
  return 1
}

profile_has_prefix_set() {
  local pf line
  pf="$(profile_file_resolved 2>/dev/null || true)"
  [[ -n "$pf" && -f "$pf" ]] || return 1
  grep -qE '^[[:space:]]*MOLT_DEFAULT_PREFIX=' "$pf" 2>/dev/null
}

save_prefix_to_profile() {
  local choice="$1"
  local pf dir
  pf="${MOLT_PROFILE:-${XDG_CONFIG_HOME:-$HOME/.config}/molt/profile.env}"
  dir="$(dirname "$pf")"
  mkdir -p "$dir"
  touch "$pf"
  chmod 600 "$pf" 2>/dev/null || true

  if profile_has_prefix_set; then
    if grep -qE '^[[:space:]]*MOLT_DEFAULT_PREFIX=' "$pf"; then
      sed -i "s/^[[:space:]]*MOLT_DEFAULT_PREFIX=.*/MOLT_DEFAULT_PREFIX=${choice}/" "$pf"
    fi
  else
    {
      echo ""
      echo "# chosen via molt-cli configure"
      echo "MOLT_DEFAULT_PREFIX=${choice}"
    } >>"$pf"
  fi
  export MOLT_DEFAULT_PREFIX="$choice"
  echo "saved: MOLT_DEFAULT_PREFIX=${choice} in $pf"
}

prompt_for_prefix() {
  local choice opt
  echo ""
  echo "Select suite (MOLT_DEFAULT_PREFIX):"
  echo "  1) be      backend repos     (be-*)"
  echo "  2) web      web apps          (web-*)"
  echo "  3) mobile   mobile apps       (mobile-*)"
  echo "  4) iac      infrastructure    (iac-*)"
  echo ""
  while true; do
    if [[ -t 0 ]] && [[ -r /dev/tty ]]; then
      read -r -p "Enter 1-4 or name [be/web/mobile/iac]: " choice </dev/tty
    else
      read -r choice
    fi
    case "${choice,,}" in
      1|be)     choice=be; break ;;
      2|web)    choice=web; break ;;
      3|mobile) choice=mobile; break ;;
      4|iac|iaac) choice=iac; break ;;
      "")       choice=be; echo "  (using be)"; break ;;
      *)
        if prefix_is_valid "$choice"; then
          choice="${choice,,}"
          break
        fi
        echo "  invalid — pick be, web, mobile, or iac"
        ;;
    esac
  done

  if [[ -t 0 ]]; then
    local ans
    if [[ -r /dev/tty ]]; then
      read -r -p "Save to ~/.config/molt/profile.env? [Y/n] " ans </dev/tty
    else
      read -r ans
    fi
    case "${ans,,}" in
      n|no) export MOLT_DEFAULT_PREFIX="$choice" ;;
      *) save_prefix_to_profile "$choice" ;;
    esac
  else
    save_prefix_to_profile "$choice"
  fi
}

# Returns normalized prefix (e.g. be-). Prompts if unset and stdin is a TTY.
resolve_default_prefix() {
  local p="${MOLT_DEFAULT_PREFIX:-}"
  if [[ -n "$p" ]] && prefix_is_valid "$p"; then
    normalize_prefix "$p"
    return 0
  fi
  if [[ -t 0 ]]; then
    prompt_for_prefix
    normalize_prefix "$MOLT_DEFAULT_PREFIX"
    return 0
  fi
  die "set MOLT_DEFAULT_PREFIX to be, web, mobile, or iac in ~/.config/molt/profile.env (or run: molt-cli configure)"
}

cmd_configure() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      prefix|suite) shift; break ;;
      -h|--help)
        cat <<'EOF'
molt-cli configure — set defaults interactively

  molt-cli configure prefix

Chooses and saves MOLT_DEFAULT_PREFIX: be | web | mobile | iac
EOF
        return 0
        ;;
      *) die "unknown: configure $1 (try: configure prefix)" ;;
    esac
  done

  local sub="${1:-prefix}"
  case "$sub" in
    prefix|suite)
      prompt_for_prefix
      echo "current: MOLT_DEFAULT_PREFIX=${MOLT_DEFAULT_PREFIX}"
      ;;
    *)
      die "unknown: configure $sub"
      ;;
  esac
}
