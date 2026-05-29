#!/usr/bin/env bash
# molt-cli install — private install to ~/.local/bin (no workspace molt-cli repo on PATH)

molt_activate_file() {
  echo "${XDG_CONFIG_HOME:-$HOME/.config}/molt/activate"
}

write_private_activate() {
  local target="$1" af
  af="$(molt_activate_file)"
  mkdir -p "$(dirname "$af")"
  cat >"$af" <<EOF
# Private molt-cli session — source when you need it (not for .zshrc / .bashrc)
#   source ${af}
#
# Does not add ~/Workspace/molt/molt-cli to PATH.

case ":\$PATH:" in
  *":${target}:"*) ;;
  *) PATH="${target}:\$PATH" ;;
esac
EOF
  chmod 600 "$af"
  echo "private activate: $af (mode 600)"
}

cmd_activate() {
  local af
  af="$(molt_activate_file)"
  [[ -f "$af" ]] || die "run: molt-cli install first"
  case "${1:-}" in
    --print|-p)
      echo "source $af"
      return 0
      ;;
    -h|--help)
      cat <<EOF
molt-cli activate — load molt-cli in this shell only (private)

  source <(molt-cli activate --print)
  # or:
  source ~/.config/molt/activate

Does not modify .zshrc. Does not put Workspace/molt/molt-cli on PATH.
EOF
      return 0
      ;;
  esac
  # shellcheck disable=SC1090
  source "$af"
  echo "activated (this shell only): $(command -v molt-cli 2>/dev/null || echo 'molt-cli not on PATH')"
}

cmd_install() {
  local target="${MOLT_CLI_INSTALL_DIR:-$HOME/.local/bin}"
  local force=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir)   target="${2:?}"; shift ;;
      --force) force=1 ;;
      -h|--help)
        cat <<'EOF'
molt-cli install — private install (recommended)

  molt-cli install

Installs symlinks in ~/.local/bin only — NOT ~/Workspace/molt/molt-cli on PATH.

If ~/.local/bin is already on PATH (common on Linux), use molt-cli immediately.

Otherwise, per session (private, not in .zshrc):
  source <(molt-cli activate --print)

Options:
  --dir PATH   Install target (default: ~/.local/bin)
  --force      Replace existing symlinks
EOF
        return 0
        ;;
      *) die "unknown flag: $1" ;;
    esac
    shift
  done

  local cli="$MOLT_CLI_HOME/molt-cli"
  [[ -x "$cli" ]] || die "missing executable: $cli"

  mkdir -p "$target"
  local dest="$target/molt-cli"
  if [[ -e "$dest" && "$force" -ne 1 ]]; then
    if [[ "$(readlink -f "$dest" 2>/dev/null)" == "$(readlink -f "$cli")" ]]; then
      echo "already installed: $dest"
    else
      die "$dest exists (use --force to replace)"
    fi
  else
    ln -sf "$cli" "$dest"
    echo "installed: $dest -> $cli"
  fi

  ln -sf "$dest" "$target/molt"
  echo "shortcut:  $target/molt -> molt-cli"

  write_private_activate "$target"

  if command -v molt-cli &>/dev/null; then
    echo "PATH: molt-cli ready ($(command -v molt-cli))"
  else
    echo ""
    echo "Load in this shell (pick one):"
    echo "  source ~/.config/molt/activate"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
    echo "Optional once in ~/.zshrc (not the molt-cli folder):"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  fi

  echo ""
  echo "Next:"
  echo "  molt-cli info"
  echo "  molt-cli ssh setup --fix"
}
