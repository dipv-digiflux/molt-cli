# molt-cli

Workspace CLI for Molt repos. Clone, pull, check, and promote environment branches across the org — all from one command.

**Private install** — never put `~/Workspace/molt/scripts` on your PATH. Use `molt-cli install` instead.

---

## Table of contents

- [Prerequisites](#prerequisites)
- [Workspace layout](#workspace-layout)
- [Quick start](#quick-start)
- [Install](#install)
- [Configuration](#configuration)
- [Suite prefix (required)](#suite-prefix-required)
- [Daily workflow](#daily-workflow)
- [Commands reference](#commands-reference)
- [Examples by task](#examples-by-task)
- [Environment promotion](#environment-promotion)
- [Scripts repo maintenance](#scripts-repo-maintenance)
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
├── scripts/          ← this repo (molt-cli lives here)
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
cd ~/Workspace/molt/scripts
./molt-cli install

# 2. Load in this shell if molt-cli is not found
source <(molt-cli activate --print)

# 3. Choose your suite (be | web | mobile | iac)
molt-cli configure prefix

# 4. Copy and edit profile
mkdir -p ~/.config/molt
cp .molt/profile.env.example ~/.config/molt/profile.env
# edit ~/.config/molt/profile.env

# 5. SSH + health check
molt-cli ssh setup --fix
molt-cli check --quick

# 6. Clone and work
molt-cli clone --prefix be
molt-cli pull
```

`molt` is a shortcut for `molt-cli`.

---

## Install

### Recommended (private install)

```bash
cd ~/Workspace/molt/scripts
./molt-cli install
# or:
./install.sh
```

This:

- Symlinks `molt-cli` and `molt` into **`~/.local/bin`**
- Writes **`~/.config/molt/activate`** (mode `600`) for per-session loading
- Does **not** add the scripts folder to PATH

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

**Option B — one line in shell rc (only `~/.local/bin`, not scripts/):**

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Do not do this

```bash
# wrong — exposes workspace path; use install + ~/.local/bin instead
export PATH="$HOME/Workspace/molt/scripts:$PATH"
```

---

## Configuration

Settings live in **`~/.config/molt/profile.env`**. Copy the example:

```bash
cp ~/Workspace/molt/scripts/.molt/profile.env.example ~/.config/molt/profile.env
chmod 600 ~/.config/molt/profile.env
```

Profile search order (first file found is loaded):

1. `$MOLT_PROFILE` (explicit path)
2. `~/.config/molt/profile.env`
3. `$MOLT_ROOT/.molt/profile.env`

### All profile variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MOLT_DEFAULT_PREFIX` | *(none)* | Suite: `be`, `web`, `mobile`, or `iac` |
| `GITHUB_ORG` | `molt-digiflux` | GitHub organization |
| `MOLT_DEFAULT_BRANCH` | `env/staging` | Branch to checkout on clone/pull |
| `MOLT_GIT_PROTOCOL` | `ssh` | `ssh` or `https` for clone URLs |
| `MOLT_GITHUB_HOST` | `github.com` | SSH host for git |
| `MOLT_ROOT` | parent of `scripts/` | Workspace root |
| `GIT_PROMOTE_NAME` | `env-promote-script` | Git identity for promote pushes |
| `GIT_PROMOTE_EMAIL` | `promote@local` | Email for promote pushes |
| `MOLT_SCRIPTS_GIT_NAME` | `$GIT_PROMOTE_NAME` | Local git name for scripts repo |
| `MOLT_SCRIPTS_GIT_EMAIL` | `$GIT_PROMOTE_EMAIL` | Local git email for scripts repo |
| `MERGE_STYLE` | `merge` | PR merge style: `merge`, `squash`, or `rebase` |

### Example profile

```bash
# ~/.config/molt/profile.env

MOLT_DEFAULT_PREFIX=be

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

## Suite prefix (required)

Choose **one** suite before clone/pull/check:

| Prefix | Folder | Repo pattern |
|--------|--------|--------------|
| `be` | `~/Workspace/molt/be/` | `be-*` |
| `web` | `~/Workspace/molt/web/` | `web-*` |
| `mobile` | `~/Workspace/molt/mobile/` | `mobile-*` |
| `iac` | `~/Workspace/molt/iac/` | `iac-*` |

### Set interactively

```bash
molt-cli configure prefix
```

### Set in profile

```bash
MOLT_DEFAULT_PREFIX=be   # or web | mobile | iac
```

### Override per command

```bash
molt-cli clone --prefix web
molt-cli pull --prefix mobile
molt-cli check --prefix iac
```

---

## Daily workflow

```bash
molt-cli info                    # see all settings
molt-cli ssh setup --fix         # SSH + fix HTTPS remotes
molt-cli check --quick           # health check
molt-cli clone --prefix be       # clone all be-* repos
molt-cli pull                    # checkout + pull all local repos
molt-cli pull --rebase           # pull with rebase
```

---

## Commands reference

### Core

| Command | Description |
|---------|-------------|
| `info` | Show org, paths, SSH status, workspaces, commands |
| `info --json` | Same as info, `key=value` format |
| `check` | Verify tools, gh auth, SSH, and local repos |
| `check --quick` | Skip slow per-repo GitHub API branch checks |
| `configure prefix` | Interactively set and save suite prefix |
| `install` | Private install to `~/.local/bin` |
| `activate` | Load CLI in current shell only |

### SSH

| Command | Description |
|---------|-------------|
| `ssh test` | Test GitHub SSH authentication |
| `ssh keys` | List keys loaded in ssh-agent |
| `ssh fix` | Rewrite workspace remotes to SSH URLs |
| `ssh setup` | Set `gh git_protocol=ssh` + test |
| `ssh setup --fix` | Setup + fix all remotes |

### Workspace

| Command | Description |
|---------|-------------|
| `clone` | Clone org repos matching prefix (SSH by default) |
| `pull` | Checkout branch + pull all local repos |
| `promote list` | List org repos (all suites) |
| `promote merge-all` | Promote env branches via PRs |
| `promote merge-all --ssh-push` | Promote via git merge + push |

### Scripts repo

| Command | Description |
|---------|-------------|
| `setup-git` | Init local git for scripts repo |
| `setup-git --commit` | Init + create initial commit |
| `git status` | Git status in scripts repo only |
| `git log` | Git log in scripts repo only |
| `git diff` | Git diff in scripts repo only |
| `git tag` | Tag in scripts repo only |

Every command supports `--help`:

```bash
molt-cli clone --help
molt-cli promote merge-all --help
```

---

## Examples by task

### First-time setup

```bash
cd ~/Workspace/molt/scripts
./molt-cli install
source <(molt-cli activate --print)

molt-cli configure prefix          # pick be, web, mobile, or iac
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
molt-cli configure prefix               # choose web
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

## Scripts repo maintenance

The scripts folder has its **own local git** — it never touches your global git config.

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

### Day-to-day git in scripts repo

```bash
molt git status
molt git log --oneline -10
molt git diff

# commits — use git directly in the scripts folder
cd ~/Workspace/molt/scripts
git add -A
git commit -m "feat: add new helper"
git tag v0.2.0
```

### Update molt-cli after pulling script changes

If you changed `molt-cli` or lib files locally:

```bash
cd ~/Workspace/molt/scripts
git pull                          # if tracking a remote
# symlinks in ~/.local/bin point to molt-cli — no reinstall needed
molt-cli info                     # verify version and paths
```

Reinstall only if you moved the scripts folder or changed install dir:

```bash
molt-cli install --force
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `molt-cli: command not found` | `source <(molt-cli activate --print)` or add `~/.local/bin` to PATH |
| `set MOLT_DEFAULT_PREFIX` error | Run `molt-cli configure prefix` or set in profile |
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
scripts/
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
│   └── git-local.sh      # scripts repo git
└── .molt/
    └── profile.env.example
```

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
- Never commit real emails/secrets to the scripts repo
- Use repo-local git config only (`molt setup-git`)

**Updating on a new machine:**

```bash
# Clone or copy ~/Workspace/molt/scripts
cd ~/Workspace/molt/scripts
./molt-cli install
cp .molt/profile.env.example ~/.config/molt/profile.env
# edit profile
molt-cli configure prefix
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
