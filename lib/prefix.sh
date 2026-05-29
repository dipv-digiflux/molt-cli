#!/usr/bin/env bash
# Interactive suite picker — always ask: be | web | mobile | iac | all
#
# To add a suite (e.g. data-*):
#   1. MOLT_VALID_SUITES in lib/repos-common.sh
#   2. _prefix_menu + _read_prefix_choice here
#   3. mkdir ~/Workspace/molt/data
#   "all" expands every entry in MOLT_VALID_SUITES automatically.

prefix_is_valid() {
  local p="${1%-}"
  [[ "$p" == "all" ]] && return 0
  local s
  for s in "${MOLT_VALID_SUITES[@]}"; do
    [[ "$p" == "$s" ]] && return 0
  done
  return 1
}

_prefix_menu() {
  echo "" >&2
  echo "Which repos?" >&2
  echo "" >&2
  echo "  1) be-*" >&2
  echo "  2) web-*" >&2
  echo "  3) mobile-*" >&2
  echo "  4) iac-*" >&2
  echo "  5) all     (be + web + mobile + iac)" >&2
  echo "" >&2
}

_read_prefix_choice() {
  local choice
  while true; do
    if [[ -t 0 ]] && [[ -r /dev/tty ]]; then
      read -r -p "Enter 1-5 or name [be/web/mobile/iac/all]: " choice </dev/tty
    else
      read -r choice
    fi
    case "${choice,,}" in
      1|be)     echo "be"; return 0 ;;
      2|web)    echo "web"; return 0 ;;
      3|mobile) echo "mobile"; return 0 ;;
      4|iac|iaac) echo "iac"; return 0 ;;
      5|all)    echo "all"; return 0 ;;
      "")
        echo "  pick 1-5 or be/web/mobile/iac/all" >&2
        ;;
      *)
        if prefix_is_valid "$choice"; then
          echo "${choice,,}"
          return 0
        fi
        echo "  invalid — pick be, web, mobile, iac, or all" >&2
        ;;
    esac
  done
}

# Prints chosen suite to stdout (be | web | mobile | iac | all).
prompt_for_prefix() {
  _prefix_menu
  _read_prefix_choice
}

# One normalized prefix per line (be-, web-, …). Expands all → four suites.
expand_prefixes() {
  local choice="$1"
  if prefix_is_all "$choice"; then
    local s
    for s in "${MOLT_VALID_SUITES[@]}"; do
      echo "${s}-"
    done
    return 0
  fi
  normalize_prefix "$choice"
}

# Infer be-/web-/… from repo name (be-user → be-).
infer_prefix_from_repo() {
  local repo="$1" s
  for s in "${MOLT_VALID_SUITES[@]}"; do
    if matches_prefix "$repo" "${s}-"; then
      echo "${s}-"
      return 0
    fi
  done
  die "cannot infer suite for repo: $repo (use --prefix be|web|mobile|iac)"
}

# explicit: be, web, all, be-, or empty to prompt.
resolve_prefixes() {
  local explicit="${1:-}"
  local choice

  if [[ -n "$explicit" ]]; then
    choice="${explicit%-}"
    expand_prefixes "$choice"
    return 0
  fi

  if [[ -t 0 ]]; then
    choice="$(prompt_for_prefix)"
    expand_prefixes "$choice"
    return 0
  fi

  die "pass --prefix be|web|mobile|iac|all (non-interactive shell)"
}

# Single normalized prefix (be-, …). Rarely used; prefer resolve_prefixes.
resolve_default_prefix() {
  resolve_prefixes "${1:-}" | head -n1
}
