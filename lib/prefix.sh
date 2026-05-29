#!/usr/bin/env bash
# Interactive suite picker — be | web | mobile | iaac (iaac-*) | other | all
#
# To add a suite (e.g. data-*):
#   1. MOLT_VALID_SUITES in lib/repos-common.sh
#   2. suite_repo_prefix / suite_menu_label if name ≠ repo prefix
#   3. mkdir ~/Workspace/molt/data
#   "all" expands every entry in MOLT_VALID_SUITES automatically.

prefix_is_valid() {
  local p="${1%-}"
  [[ "$p" == "all" ]] && return 0
  [[ "$p" == "iac" ]] && return 0
  local s
  for s in "${MOLT_VALID_SUITES[@]}"; do
    [[ "$p" == "$s" ]] && return 0
  done
  return 1
}

_prefix_menu() {
  local i=1 s n="${#MOLT_VALID_SUITES[@]}"
  echo "" >&2
  echo "Which repos?" >&2
  echo "" >&2
  for s in "${MOLT_VALID_SUITES[@]}"; do
    echo "  $i) $(suite_menu_label "$s")" >&2
    i=$((i + 1))
  done
  echo "  $i) all     (${MOLT_VALID_SUITES[*]})" >&2
  echo "" >&2
}

_prefix_choice_names() {
  local names=() s
  for s in "${MOLT_VALID_SUITES[@]}"; do
    names+=("$s")
  done
  names+=("all")
  local IFS=/
  echo "${names[*]}"
}

_read_prefix_choice() {
  local choice names
  local n="${#MOLT_VALID_SUITES[@]}"
  local all_n=$((n + 1))
  names="$(_prefix_choice_names)"
  while true; do
    if [[ -t 0 ]] && [[ -r /dev/tty ]]; then
      read -r -p "Enter 1-${all_n} or name [${names}]: " choice </dev/tty
    else
      read -r choice
    fi
    case "${choice,,}" in
      all) echo "all"; return 0 ;;
      iac|iaac) echo "iaac"; return 0 ;;
      "")
        echo "  pick 1-${all_n} or ${names}" >&2
        ;;
      *)
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= n )); then
          echo "${MOLT_VALID_SUITES[$((choice - 1))]}"
          return 0
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice == all_n )); then
          echo "all"
          return 0
        fi
        if prefix_is_valid "$choice"; then
          local p="${choice,,}"
          [[ "$p" == "iac" ]] && p="iaac"
          echo "$p"
          return 0
        fi
        echo "  invalid — pick ${names}" >&2
        ;;
    esac
  done
}

# Prints chosen suite to stdout (be | web | mobile | iaac | other | all).
prompt_for_prefix() {
  _prefix_menu
  _read_prefix_choice
}

# One repo-name prefix per line (be-, iaac-, other, …). Expands all → every suite.
expand_prefixes() {
  local choice="$1"
  if prefix_is_all "$choice"; then
    local s
    for s in "${MOLT_VALID_SUITES[@]}"; do
      echo "$(suite_repo_prefix "$s")"
    done
    return 0
  fi
  normalize_prefix "$choice"
}

# Infer repo-name prefix from repo name (be-user → be-, iaac-vpc → iaac-).
infer_prefix_from_repo() {
  local repo="$1" s p
  for s in "${MOLT_VALID_SUITES[@]}"; do
    [[ "$s" == "other" ]] && continue
    p="$(suite_repo_prefix "$s")"
    if matches_prefix "$repo" "$p"; then
      echo "$p"
      return 0
    fi
  done
  echo "other"
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

  die "pass --prefix be|web|mobile|iaac|other|all (non-interactive shell)"
}

# Single normalized prefix (be-, …). Rarely used; prefer resolve_prefixes.
resolve_default_prefix() {
  resolve_prefixes "${1:-}" | head -n1
}
