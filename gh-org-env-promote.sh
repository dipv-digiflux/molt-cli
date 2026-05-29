#!/usr/bin/env bash
# List org repos and promote env branches via GitHub PRs or git push.
#
# Prerequisites: gh authenticated for the org; git for --ssh-push path.
#
# Usage:
#   ./gh-org-env-promote.sh list
#   molt promote merge-all [--dry-run] [--repo be-user]
#   molt promote merge-all --ssh-push
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/repos-common.sh
source "$SCRIPT_DIR/lib/repos-common.sh"

CHAIN=("${MOLT_ENV_CHAIN[@]}")

open_or_get_pr() {
  local repo="$1" base="$2" head="$3"
  local existing
  existing="$(gh pr list --repo "$GITHUB_ORG/$repo" --base "$base" --head "$head" --state all \
    --json number --jq '.[0].number // empty' 2>/dev/null || true)"
  if [[ -n "$existing" ]]; then
    echo "$existing"
    return 0
  fi
  gh pr create --repo "$GITHUB_ORG/$repo" --base "$base" --head "$head" \
    --title "chore(ci): promote ${head} -> ${base}" \
    --body "Automated environment promotion: merge **${head}** into **${base}** for deploy pipeline." \
    >/dev/null || true
  existing="$(gh pr list --repo "$GITHUB_ORG/$repo" --base "$base" --head "$head" --state open \
    --json number --jq '.[0].number // empty' 2>/dev/null || true)"
  [[ -n "$existing" ]] || die "could not create or find PR for $repo ($base <- $head)"
  echo "$existing"
}

merge_pr() {
  local repo="$1" pr="$2"
  case "$MERGE_STYLE" in
    merge)   gh pr merge "$pr" --repo "$GITHUB_ORG/$repo" --merge ;;
    squash)  gh pr merge "$pr" --repo "$GITHUB_ORG/$repo" --squash ;;
    rebase)  gh pr merge "$pr" --repo "$GITHUB_ORG/$repo" --rebase ;;
    *) die "MERGE_STYLE must be merge, squash, or rebase" ;;
  esac
}

cmd_list() {
  echo "# repos in ${GITHUB_ORG} matching be-*, web-*, mobile-*"
  list_org_repos_any_suite
}

cmd_promote() {
  local dry_run=0 do_merge=0 only_repo=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry_run=1 ;;
      --merge)   do_merge=1 ;;
      --squash)  MERGE_STYLE=squash ;;
      --rebase)  MERGE_STYLE=rebase ;;
      --repo)    only_repo="${2:?}"; shift ;;
      *) die "unknown flag: $1 (try: list | merge-all | promote --help)" ;;
    esac
    shift
  done

  require_cmd gh

  local repos=()
  while IFS= read -r r; do repos+=("$r"); done < <(
    if [[ -n "$only_repo" ]]; then
      echo "$only_repo"
    else
      list_org_repos_any_suite
    fi
  )

  [[ ${#repos[@]} -gt 0 ]] || die "no repos matched"

  for repo in "${repos[@]}"; do
    echo "=== ${GITHUB_ORG}/${repo} ==="
    for pair in "${CHAIN[@]}"; do
      IFS=: read -r head base <<<"$pair"
      if ! repo_has_remote_branch "$repo" "$head"; then
        echo "  skip: missing branch $head"
        continue
      fi
      if ! repo_has_remote_branch "$repo" "$base"; then
        echo "  skip: missing branch $base"
        continue
      fi
      if [[ "$dry_run" -eq 1 ]]; then
        echo "  would PR: base=$base <- head=$head"
        continue
      fi
      pr="$(open_or_get_pr "$repo" "$base" "$head")"
      echo "  PR #${pr}: $base <- $head"
      if [[ "$do_merge" -eq 1 ]]; then
        if merge_pr "$repo" "$pr"; then
          echo "  merged PR #${pr} ($MERGE_STYLE)"
        else
          echo "  WARNING: merge failed for PR #${pr} (permissions / branch protection / checks?)" >&2
        fi
      fi
    done
  done
}

git_push_promote_repo() {
  local repo="$1" dry_run="$2"
  local clone_url tmp
  clone_url="$(clone_url_for "$repo")"

  if [[ "$dry_run" -eq 1 ]]; then
    echo "  would: clone $clone_url then merge+push: ${CHAIN[*]}"
    return 0
  fi

  tmp="$(mktemp -d)"
  if ! git clone --quiet "$clone_url" "$tmp/w"; then
    echo "  WARNING: clone failed for ${GITHUB_ORG}/${repo}" >&2
    rm -rf "$tmp"
    return 1
  fi

  pushd "$tmp/w" >/dev/null || die "pushd"
  if [[ -z "$(git config user.email)" ]]; then
    git config user.email "$GIT_PROMOTE_EMAIL"
    git config user.name "$GIT_PROMOTE_NAME"
  fi
  export GIT_MERGE_AUTOEDIT=no

  for pair in "${CHAIN[@]}"; do
    IFS=: read -r head base <<<"$pair"
    if ! repo_has_remote_branch "$repo" "$head"; then
      echo "  skip: missing branch $head"
      continue
    fi
    if ! repo_has_remote_branch "$repo" "$base"; then
      echo "  skip: missing branch $base"
      continue
    fi
    git fetch -q origin "$head" "$base"
    if ! git checkout -B "$base" "origin/$base"; then
      echo "  WARNING: checkout $base failed" >&2
      popd >/dev/null || true
      rm -rf "$tmp"
      return 1
    fi
    if ! git merge -q --no-edit "origin/$head" -m "promote: merge ${head} into ${base}"; then
      echo "  WARNING: merge conflict or failed: ${base} <- ${head} (aborting this repo)" >&2
      git merge --abort 2>/dev/null || true
      popd >/dev/null || true
      rm -rf "$tmp"
      return 1
    fi
    if ! git push -q origin "$base"; then
      echo "  WARNING: git push origin $base failed (branch protection / permissions?)" >&2
      popd >/dev/null || true
      rm -rf "$tmp"
      return 1
    fi
    echo "  pushed $base <- $head"
  done

  popd >/dev/null || true
  rm -rf "$tmp"
  return 0
}

cmd_merge_all_push() {
  local dry_run=0 only_repo=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry_run=1 ;;
      --repo)    only_repo="${2:?}"; shift ;;
      *) die "unknown flag: $1 (merge-all-push: --dry-run, --repo)" ;;
    esac
    shift
  done

  require_cmd gh
  require_cmd git

  local repos=()
  while IFS= read -r r; do repos+=("$r"); done < <(
    if [[ -n "$only_repo" ]]; then
      echo "$only_repo"
    else
      list_org_repos_any_suite
    fi
  )

  [[ ${#repos[@]} -gt 0 ]] || die "no repos matched"

  for repo in "${repos[@]}"; do
    echo "=== ${GITHUB_ORG}/${repo} (git push) ==="
    if ! git_push_promote_repo "$repo" "$dry_run"; then
      echo "  (see warnings above)" >&2
    fi
  done
}

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  echo ""
  echo "Env chain (from profile):"
  for pair in "${CHAIN[@]}"; do
    IFS=: read -r head base <<<"$pair"
    echo "  $head -> $base"
  done
}

cmd_merge_all_dispatch() {
  local ssh_push=0
  local pa=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ssh-push|--push) ssh_push=1; shift ;;
      --repo) pa+=("$1" "${2:?}"); shift 2 ;;
      --squash|--rebase) pa+=("$1"); shift ;;
      --dry-run) pa+=("$1"); shift ;;
      *) die "unknown merge-all flag: $1" ;;
    esac
  done
  if [[ "$ssh_push" -eq 1 ]]; then
    for x in "${pa[@]}"; do
      [[ "$x" == --squash || "$x" == --rebase ]] &&
        die "--squash/--rebase cannot be used with --ssh-push (git path uses merge commits)"
    done
    cmd_merge_all_push "${pa[@]}"
  else
    cmd_promote --merge "${pa[@]}"
  fi
}

main() {
  case "${1:-}" in
    list)           shift; cmd_list "$@" ;;
    merge-all)      shift; cmd_merge_all_dispatch "$@" ;;
    merge-all-push) shift; cmd_merge_all_push "$@" ;;
    promote)        shift; cmd_promote "$@" ;;
    ""|-h|--help) usage; exit 0 ;;
    *) die "usage: $0 list | merge-all [--ssh-push] [--squash|--rebase] [--repo NAME] [--dry-run] | merge-all-push ... | promote ..." ;;
  esac
}

main "$@"
