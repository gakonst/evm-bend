#!/bin/sh
set -eu
cd "$(dirname "$0")"
if [ -n "${BUN:-}" ]; then exec "$BUN" toolchain-debug/main.ts "$@"; fi
if command -v bun >/dev/null 2>&1; then exec bun toolchain-debug/main.ts "$@"; fi
exec "$HOME/.bun/bin/bun" toolchain-debug/main.ts "$@"
