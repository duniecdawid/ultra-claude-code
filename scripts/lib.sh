#!/bin/bash
# Ultra Claude shared library — sourced by hooks and statusline.
# Symlinked to ~/.claude/ultra/lib.sh by /uc:setup.

ULTRA_DIR="$HOME/.claude/ultra"
ACCOUNTS_DIR="$ULTRA_DIR/accounts"

# slugifyEmail: normalize email into a filesystem-safe account ID.
# Rules: lowercase, @ → -at-, . → -, strip remaining non-alphanumeric (keep hyphens).
# Example: "Dawid.Duniec@AXB.co" → "dawid-duniec-at-axb-co"
slugifyEmail() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/@/-at-/g; s/\./-/g; s/[^a-z0-9-]//g'
}
