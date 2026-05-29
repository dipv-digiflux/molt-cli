# Molt workspace scripts

One CLI (`molt`) and one profile for org, branches, layout, and env promotion. Run from **any directory** if `scripts/` is on your `PATH`, or call scripts directly.

## Quick start

```bash
# From anywhere (after: export PATH="$HOME/Workspace/molt/scripts:$PATH")
molt setup-git --commit   # once: local git for scripts versioning
molt check
molt clone --prefix be
molt pull
molt promote list
```

Or from the workspace:

```bash
./scripts/molt check
./scripts/clone-all.sh
```

## Layout

| Path | Contents |
|------|----------|
| `molt/{be,web,mobile}/` | Cloned repos (`be-user`, `web-coach`, …) |
| `scripts/molt` | Main entry (`check`, `setup-git`, `git`, `clone`, `pull`, `promote`) |
| `scripts/.git` | Local version history for tooling only (not service repos) |
| `scripts/lib/molt-profile.sh` | Defaults + profile file loader |
| `scripts/lib/repos-common.sh` | Shared git/gh helpers |
| `~/.config/molt/profile.env` | Your overrides (optional) |

## Profile (one place for config)

Copy the example and edit:

```bash
mkdir -p ~/.config/molt
cp scripts/.molt/profile.env.example ~/.config/molt/profile.env
```

| Variable | Default | Purpose |
|----------|---------|---------|
| `GITHUB_ORG` | `molt-digiflux` | GitHub org for `gh` |
| `MOLT_DEFAULT_BRANCH` | `env/staging` | Branch for clone/pull/check |
| `MOLT_DEFAULT_PREFIX` | `be` | Suite: `be`, `web`, or `mobile` |
| `MOLT_ENV_CHAIN` | staging→uat→preprod→prod | Promote chain (in profile file only) |
| `MERGE_STYLE` | `merge` | PR merge: `merge`, `squash`, `rebase` |
| `MOLT_ROOT` | auto (`scripts/..`) | Workspace root if not under `~/Workspace/molt` |
| `WORKSPACE_ROOT` | per prefix | Override clone/pull target dir |

Profile search order: `$MOLT_PROFILE` → `~/.config/molt/profile.env` → `$MOLT_ROOT/.molt/profile.env`.

## Commands

### `molt check`

Verifies tools (`git`, `gh`), GitHub auth and org access, workspace directory, each repo’s branch/cleanliness/behind-remote, and remote env branches on the promote chain.

```bash
molt check
molt check --prefix web --branch env/staging
molt check --repo be-user --quiet
```

Exit `0` on success (warnings allowed); `1` on hard failures.

### `molt clone` / `clone-all.sh`

Clone all `be-*` / `web-*` / `mobile-*` repos from the org (or one `--repo`).

```bash
molt clone
molt clone --prefix web --branch env/staging --dry-run
```

### `molt pull` / `pull-all.sh`

Checkout and pull every local repo for a prefix.

```bash
molt pull --rebase
molt pull --prefix mobile --ff-only
```

### `molt promote` / `gh-org-env-promote.sh`

Environment promotion along the chain (same in profile):

```
env/staging → env/uat → env/preprod → env/prod
```

```bash
molt promote list
molt promote promote --dry-run          # open PRs only
molt promote merge-all                  # create + merge PRs (GitHub API)
molt promote merge-all --ssh-push       # git merge + push over SSH
molt promote merge-all --repo be-user --squash
```

Requires `gh auth login` with org/repo scope. Merge failures often mean branch protection or missing permissions — use `molt check` first.

## Local git (scripts repo only)

Version-control **this tooling** separately from `be-*` / `web-*` / `mobile-*` service repos.

```bash
molt setup-git              # git init + repo-local user.name / user.email
molt setup-git --commit     # also create first commit if none exists
molt git status
molt git log --oneline -10
molt git tag v0.1.0
```

- Config is **repo-local** only (`git config` without `--global`).
- Identity: `MOLT_SCRIPTS_GIT_NAME` / `MOLT_SCRIPTS_GIT_EMAIL` in profile, else promote vars, else your global git user.
- Ignored: `.molt/profile.env` (keep secrets out of commits).
- `molt check` reports scripts-repo HEAD and dirty state.

Service repos under `molt/be/` etc. stay independent; use `molt pull` / `molt clone` for those.

## Permissions

- **Clone / pull**: SSH or HTTPS remotes; local git only except `fetch`.
- **Promote (PR path)**: `gh` token with `repo` (and merge rights on protected branches).
- **Promote (`--ssh-push`)**: SSH push access to `env/*` branches.
- **Check**: read-only except `git fetch` per repo.

Set identity for git-push promotes in profile: `GIT_PROMOTE_EMAIL`, `GIT_PROMOTE_NAME`.

## Reuse

All scripts source `lib/repos-common.sh`, which loads `lib/molt-profile.sh`. Add new commands by extending `scripts/molt` and reusing `list_org_repos`, `checkout_branch`, `repo_has_remote_branch`, etc.
