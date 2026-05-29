#!/usr/bin/env bash
# Install molt-cli to PATH (wrapper around: molt-cli install)
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/molt-cli" install "$@"
