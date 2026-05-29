# molt-cli

Workspace CLI for Molt repos. **Private install** — never put `~/Workspace/molt/scripts` on your PATH.

## Install (private)

```bash
cd ~/Workspace/molt/scripts
./molt-cli install
```

This symlinks into **`~/.local/bin`** only and writes **`~/.config/molt/activate`** (mode `600`).

### If `molt-cli` is not found

Use a **private per-session** load (nothing in `.zshrc` required):

```bash
source <(molt-cli activate --print)
# or:
source ~/.config/molt/activate
```

### Optional: one line in shell rc (only `~/.local/bin`, not scripts/)

```bash
export PATH="$HOME/.local/bin:$PATH"
```

**Do not use:**

```bash
# wrong — exposes workspace path; use install + ~/.local/bin instead
export PATH="$HOME/Workspace/molt/scripts:$PATH"
```

## Daily flow

```bash
molt-cli info
molt-cli ssh setup --fix
molt-cli check --quick
molt-cli clone --prefix be
molt-cli pull
```

## Commands

| Command | What it does |
|---------|----------------|
| `info` | All settings (org, SSH, workspaces) |
| `check` / `check --quick` | Health check |
| `ssh setup --fix` | SSH git + fix remotes |
| `install` | `~/.local/bin` + private activate file |
| `activate` | Load CLI in current shell only |
| `clone` / `pull` / `promote` | Workspace operations |

### Suite prefix (required)

Choose **one**: `be` | `web` | `mobile` | `iac`

```bash
molt-cli configure prefix
```

Or set in `~/.config/molt/profile.env`:

```bash
MOLT_DEFAULT_PREFIX=be   # or web | mobile | iac
```

Profile: copy `.molt/profile.env.example` → `~/.config/molt/profile.env`.

`molt` is a shortcut for `molt-cli`.
