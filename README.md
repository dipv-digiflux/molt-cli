# molt-cli

Workspace CLI for Molt repos. Clone, pull, check, and promote environment branches across the org — all from one command.

**Private install** — never put `~/Workspace/molt/molt-cli` on your PATH. Use `molt-cli install` instead.

---

## Table of contents

- [Prerequisites](#prerequisites)
- [Workspace layout](#workspace-layout)
- [Quick start](#quick-start)
- [Install](#install)
- [Configuration](#configuration)
- [Suite picker](#suite-picker)
- [Using prefixes and `all`](#using-prefixes-and-all)
- [Adding a new prefix](#adding-a-new-prefix)
- [Daily workflow](#daily-workflow)
- [Commands reference](#commands-reference)
- [Examples by task](#examples-by-task)
- [Environment promotion](#environment-promotion)
- [molt-cli repo maintenance](#molt-cli-repo-maintenance)
- [Troubleshooting](#troubleshooting)
- [Maintaining molt-cli](#maintaining-molt-cli)

---

## Prerequisites

| Tool | Required | Purpose |
|------|----------|---------|
| `git` | yes | Clone, pull, promote |
| `gh` | yes | List org repos, PR-based promotion, auth |
| `ssh` | yes (default) | Git over SSH |
| `jq` | optional | Faster JSON parsing in some checks |

You also need:

- GitHub access to the org (default: `molt-digiflux`)
- SSH key added to GitHub (`gh auth login` for API access)
- Workspace root at `~/Workspace/molt` (or set `MOLT_ROOT` in profile)

---

## Workspace layout

```
~/Workspace/molt/
├── molt-cli/          ← this repo (molt-cli lives here)
├── be/               ← backend repos   (be-*)
├── web/              ← web apps        (web-*)
├── mobile/           ← mobile apps     (mobile-*)
└── iac/              ← infrastructure  (iac-*)
```

Each suite folder holds cloned repos matching that prefix, e.g. `be/be-user`, `web/web-portal`.

---

## Quick start

```bash
# 1. Install CLI (private — ~/.local/bin only)
cd ~/Workspace/molt/molt-cli
./molt-cli install

# 2. Load in this shell if molt-cli is not found
source <(molt-cli activate --print)

# 3. Clone and work (picker asks: be / web / mobile / iac / all)
molt-cli clone
molt-cli pull
```

`molt` is a shortcut for `molt-cli`.

---

## Install

### Recommended (private install)

```bash
cd ~/Workspace/molt/molt-cli
./molt-cli install
# or:
./install.sh
```

This:

- Symlinks `molt-cli` and `molt` into **`~/.local/bin`**
- Writes **`~/.config/molt/activate`** (mode `600`) for per-session loading
- Does **not** add the molt-cli folder to PATH

### Install options

```bash
molt-cli install --force          # replace existing symlinks
molt-cli install --dir ~/bin      # custom install directory
```

### If `molt-cli` is not found

**Option A — per session (nothing in `.zshrc` required):**

```bash
source <(molt-cli activate --print)
# or:
source ~/.config/molt/activate
```

**Option B — one line in shell rc (only `~/.local/bin`, not molt-cli/):**

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Do not do this

```bash
# wrong — exposes workspace path; use install + ~/.local/bin instead
export PATH="$HOME/Workspace/molt/molt-cli:$PATH"
```

---

## Configuration

Settings live in **`~/.config/molt/profile.env`**. Copy the example:

```bash
cp ~/Workspace/molt/molt-cli/.molt/profile.env.example ~/.config/molt/profile.env
chmod 600 ~/.config/molt/profile.env
```

Profile search order (first file found is loaded):

1. `$MOLT_PROFILE` (explicit path)
2. `~/.config/molt/profile.env`
3. `$MOLT_ROOT/.molt/profile.env`

### All profile variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GITHUB_ORG` | `molt-digiflux` | GitHub organization |
| `MOLT_DEFAULT_BRANCH` | `env/staging` | Branch to checkout on clone/pull |
| `MOLT_GIT_PROTOCOL` | `ssh` | `ssh` or `https` for clone URLs |
| `MOLT_GITHUB_HOST` | `github.com` | SSH host for git |
| `MOLT_ROOT` | parent of `molt-cli/` | Workspace root |
| `GIT_PROMOTE_NAME` | `env-promote-script` | Git identity for promote pushes |
| `GIT_PROMOTE_EMAIL` | `promote@local` | Email for promote pushes |
| `MOLT_SCRIPTS_GIT_NAME` | `$GIT_PROMOTE_NAME` | Local git name for molt-cli repo |
| `MOLT_SCRIPTS_GIT_EMAIL` | `$GIT_PROMOTE_EMAIL` | Local git email for molt-cli repo |
| `MERGE_STYLE` | `merge` | PR merge style: `merge`, `squash`, or `rebase` |

### Example profile

```bash
# ~/.config/molt/profile.env

GITHUB_ORG=molt-digiflux
MOLT_DEFAULT_BRANCH=env/staging

MOLT_GIT_PROTOCOL=ssh
MOLT_GITHUB_HOST=github.com

GIT_PROMOTE_NAME=Your Name
GIT_PROMOTE_EMAIL=you@example.com
MOLT_SCRIPTS_GIT_NAME=Your Name
MOLT_SCRIPTS_GIT_EMAIL=you@example.com

MOLT_ROOT=/home/you/Workspace/molt
MERGE_STYLE=merge
```

View effective settings anytime:

```bash
molt-cli info
molt-cli info --json    # key=value lines, easy to grep
```

---

## Suite picker

There is **no saved default prefix**. Every interactive run of these commands shows a menu:

| Command | Uses picker |
|---------|-------------|
| `molt-cli clone` | yes |
| `molt-cli pull` | yes |
| `molt-cli check` | yes |
| `molt-cli ssh fix` | yes |
| `molt-cli ssh setup --fix` | yes (when fixing remotes) |

### Menu

```
Which repos?

  1) be-*
  2) web-*
  3) mobile-*
  4) iac-*
  5) all     (be + web + mobile + iac)

Enter 1-5 or name [be/web/mobile/iac/all]:
```

| Pick | What runs |
|------|-----------|
| `1` or `be` | Only `be-*` repos → `~/Workspace/molt/be/` |
| `2` or `web` | Only `web-*` repos → `molt/web/` |
| `3` or `mobile` | Only `mobile-*` repos → `molt/mobile/` |
| `4` or `iac` | Only `iac-*` repos → `molt/iac/` |
| `5` or `all` | **All four suites** in order (be, then web, then mobile, then iac) |

See current paths and repo counts: `molt-cli info`

---

## Using prefixes and `all`

### Interactive (picker)

```bash
molt-cli clone          # pick 1-5 when prompted
molt-cli pull           # same menu
molt-cli check          # same menu
molt-cli ssh fix        # same menu
```

### Skip picker with `--prefix`

```bash
# One suite
molt-cli clone --prefix be
molt-cli pull --prefix web --rebase
molt-cli check --prefix iac --quick
molt-cli ssh fix --prefix mobile

# All suites (same as picking 5 in the menu)
molt-cli clone --prefix all
molt-cli pull --prefix all
molt-cli check --prefix all
molt-cli ssh setup --fix --prefix all
```

### Other flags

```bash
molt-cli clone --prefix all --dry-run     # preview all suites
molt-cli clone --repo be-user             # infers be (no picker)
molt-cli pull --repo web-portal --prefix web
molt-cli clone --prefix be --branch env/uat
```

### Non-interactive shells (CI, scripts)

The picker needs a terminal. In CI, always pass `--prefix`:

```bash
molt-cli clone --prefix all
molt-cli check --prefix be --quick
```

---

## Adding a new prefix

To add a suite (example: `data-*` repos in `~/Workspace/molt/data/`):

### 1. Register the suite

Edit `lib/repos-common.sh`:

```bash
MOLT_VALID_SUITES=(be web mobile iac data)
```

`all` automatically includes every entry in this list.

### 2. Add picker menu entry

Edit `lib/prefix.sh` — `_prefix_menu()`:

```bash
echo "  6) data-*" >&2
```

Edit `_read_prefix_choice()`:

```bash
6|data) echo "data"; return 0 ;;
```

Update the prompt text to include `data` in the valid names list.

### 3. Create workspace folder

```bash
mkdir -p ~/Workspace/molt/data
```

### 4. Document

- Update `README.md` (workspace layout + picker table)
- Update `.molt/profile.env.example`
- Run `molt-cli info` to verify `workspace_data` path

### 5. Test

```bash
./molt-cli info
./clone-all.sh --prefix data --dry-run
molt-cli clone --prefix data
```

No profile variable is required — the new suite appears in the picker on the next run.

---

## Daily workflow

```bash
molt-cli info                    # paths, picker help, add-prefix guide
molt-cli ssh setup --fix         # SSH + fix HTTPS remotes
molt-cli check                   # picker → pick suite or all
molt-cli clone                   # picker → clone org repos
molt-cli pull --rebase           # picker → pull local repos
```

---

## Commands reference

### Core

| Command | Description |
|---------|-------------|
| `info` | Config, workspaces, picker menu, add-prefix guide |
| `info --json` | Same as info, `key=value` format |
| `check` | Health check (picker or `--prefix`; `--quick`) |
| `install` | Private install to `~/.local/bin` |
| `activate` | Load CLI in current shell only |

### SSH

| Command | Description |
|---------|-------------|
| `ssh test` | Test GitHub SSH authentication |
| `ssh keys` | List keys loaded in ssh-agent |
| `ssh fix` | Fix remotes to SSH (picker or `--prefix all`) |
| `ssh setup` | Set `gh git_protocol=ssh` + test |
| `ssh setup --fix` | Setup + fix remotes (picker or `--prefix`) |

### Workspace

| Command | Description |
|---------|-------------|
| `clone` | Clone org repos (picker 1–5 or `--prefix`) |
| `clone --prefix all` | Clone all suites in one run |
| `pull` | Checkout + pull local repos (picker or `--prefix`) |
| `pull --prefix all` | Pull every suite |
| `promote list` | List org repos (all suites) |
| `promote merge-all` | Promote env branches via PRs |
| `promote merge-all --ssh-push` | Promote via git merge + push |

### Scripts repo

| Command | Description |
|---------|-------------|
| `setup-git` | Init local git for molt-cli repo |
| `setup-git --commit` | Init + create initial commit |
| `git status` | Git status in molt-cli repo only |
| `git log` | Git log in molt-cli repo only |
| `git diff` | Git diff in molt-cli repo only |
| `git tag` | Tag in molt-cli repo only |

Every command supports `--help`:

```bash
molt-cli check --help
molt-cli clone --help
molt-cli pull --help
```

---

## Examples by task

### First-time setup

```bash
cd ~/Workspace/molt/molt-cli
./molt-cli install
source <(molt-cli activate --print)

molt-cli clone                    # interactive picker
molt-cli clone --prefix all       # all suites, no picker
cp .molt/profile.env.example ~/.config/molt/profile.env
# edit profile with your name/email

gh auth login
molt-cli ssh setup --fix
molt-cli check
```

### Clone all backend repos

```bash
molt-cli clone --prefix be
# uses MOLT_DEFAULT_BRANCH (env/staging) from profile
```

### Clone one repo only

```bash
molt-cli clone --repo be-user
molt-cli clone --repo web-portal --prefix web
```

### Preview without changes

```bash
molt-cli clone --dry-run
molt-cli pull --dry-run
molt-cli promote merge-all --dry-run
```

### Pull with options

```bash
molt-cli pull                           # default branch from profile
molt-cli pull --branch env/uat          # specific branch
molt-cli pull --rebase                  # pull with rebase
molt-cli pull --ff-only                 # fast-forward only
molt-cli pull --repo be-user            # single repo
molt-cli pull --prefix web --rebase
```

### Check health

```bash
molt-cli check                          # full check
molt-cli check --quick                  # skip remote branch API calls
molt-cli check --prefix web
molt-cli check --repo be-user
molt-cli check --branch env/uat
molt-cli check --quiet                  # less output
```

### Fix SSH remotes

```bash
molt-cli ssh test                       # test GitHub SSH
molt-cli ssh keys                       # show loaded keys
molt-cli ssh fix                        # fix remotes for default prefix
molt-cli ssh fix --prefix web
molt-cli ssh setup --fix                # full setup + fix
```

### Switch suite (e.g. backend → web)

```bash
molt-cli clone --prefix web
molt-cli pull --prefix web
```

---

## Environment promotion

Default promotion chain (configurable via `MOLT_ENV_CHAIN` in profile):

```
env/staging  →  env/uat  →  env/preprod  →  env/prod
```

### List repos eligible for promotion

```bash
molt-cli promote list
```

### Promote via GitHub PRs (recommended)

```bash
# Preview
molt-cli promote merge-all --dry-run

# Create PRs and merge them
molt-cli promote merge-all

# Single repo
molt-cli promote merge-all --repo be-user

# Change merge style
molt-cli promote merge-all --squash
molt-cli promote merge-all --rebase
```

Set default merge style in profile:

```bash
MERGE_STYLE=squash   # merge | squash | rebase
```

### Promote via git push (no PRs)

Use when you have direct push access and branch protection allows it:

```bash
molt-cli promote merge-all --ssh-push
molt-cli promote merge-all --ssh-push --repo be-user
molt-cli promote merge-all --ssh-push --dry-run
```

### Custom promotion chain

Add to `~/.config/molt/profile.env` (bash array syntax):

```bash
MOLT_ENV_CHAIN=(
  "env/staging:env/uat"
  "env/uat:env/preprod"
  "env/preprod:env/prod"
)
```

---

## molt-cli repo maintenance

The molt-cli folder has its **own local git** — it never touches your global git config.

### Initialize version control

```bash
molt-cli setup-git
molt-cli setup-git --commit     # also create initial commit
```

Set identity in profile before setup:

```bash
MOLT_SCRIPTS_GIT_NAME=Your Name
MOLT_SCRIPTS_GIT_EMAIL=you@example.com
```

### Day-to-day git in molt-cli repo

```bash
molt git status
molt git log --oneline -10
molt git diff

# commits — use git directly in the molt-cli folder
cd ~/Workspace/molt/molt-cli
git add -A
git commit -m "feat: add new helper"
git tag v0.2.0
```

### Update molt-cli after pulling script changes

If you changed `molt-cli` or lib files locally:

```bash
cd ~/Workspace/molt/molt-cli
git pull                          # if tracking a remote
# symlinks in ~/.local/bin point to molt-cli — no reinstall needed
molt-cli info                     # verify version and paths
```

Reinstall only if you moved the molt-cli folder or changed install dir:

```bash
molt-cli install --force
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `molt-cli: command not found` | `source <(molt-cli activate --print)` or add `~/.local/bin` to PATH |
| Non-interactive shell | Use `--prefix be` or `--prefix all` |
| GitHub SSH failed | `ssh-add ~/.ssh/id_ed25519` then `molt-cli ssh setup --fix` |
| `gh not logged in` | `gh auth login` |
| Origin not SSH | `molt-cli ssh fix` |
| Missing workspace folder | `molt-cli clone --prefix be` |
| Repo behind remote | `molt-cli pull` |
| Promote merge failed | Check branch protection, CI checks, permissions |
| Scripts repo not initialized | `molt-cli setup-git --commit` |

Run diagnostics:

```bash
molt-cli info
molt-cli check
molt-cli ssh test
```

---

## Maintaining molt-cli

### For developers working on this repo

**Project structure:**

```
molt-cli/
├── molt-cli              # main entry point
├── molt                  # shortcut → molt-cli
├── install.sh            # wrapper → molt-cli install
├── clone-all.sh          # clone command
├── pull-all.sh           # pull command
├── gh-org-env-promote.sh # promote command
├── lib/
│   ├── molt-profile.sh   # profile loading + defaults
│   ├── repos-common.sh   # org/repo helpers
│   ├── prefix.sh         # suite prefix logic
│   ├── ssh.sh            # SSH helpers
│   ├── check.sh          # health check
│   ├── info.sh           # info command
│   ├── install-cmd.sh    # install/activate
│   └── git-local.sh      # molt-cli repo git
└── .molt/
    └── profile.env.example
```

**Adding a new prefix:** see [Adding a new prefix](#adding-a-new-prefix) above.

**Adding a new command:**

1. Add handler in `molt-cli` `main()` case statement
2. Implement in `lib/` or a top-level script
3. Document in `lib/info.sh` command list
4. Add `--help` text
5. Update this README

**Changing defaults:**

Edit `lib/molt-profile.sh` for org-wide defaults, or `.molt/profile.env.example` for user-facing examples.

**Testing changes:**

```bash
# Run directly without install
./molt-cli info
./molt-cli check --quick
./clone-all.sh --dry-run --prefix be

# After install
molt-cli install --force
molt-cli check
```

**Profile and security:**

- Keep `~/.config/molt/profile.env` at mode `600`
- Never commit real emails/secrets to the molt-cli repo
- Use repo-local git config only (`molt setup-git`)

**Updating on a new machine:**

```bash
# Clone or copy ~/Workspace/molt/molt-cli
cd ~/Workspace/molt/molt-cli
./molt-cli install
cp .molt/profile.env.example ~/.config/molt/profile.env
# edit profile
molt-cli clone --prefix all
molt-cli ssh setup --fix
molt-cli clone
```

---

## Help

```bash
molt-cli --help
molt-cli <command> --help
molt-cli info
```
