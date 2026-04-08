---
description: Update Ultra Claude to the latest version via the Claude Code plugin marketplace. Use when user says "update", "upgrade", "pull latest", "refresh plugin", "update ultra claude", "get latest version", or after hearing about new features they want. Run this skill proactively if the user mentions wanting a feature that might already exist in a newer version.
user-invocable: true
allowed-tools: [Bash, Read, Glob, Grep]
---

# Update Ultra Claude

Updates the plugin to the latest version via the Claude Code marketplace and handles all post-update housekeeping.

## Step 1: Update Plugin

Get the current version, detect the marketplace, and run the update:

```bash
cd "${CLAUDE_PLUGIN_ROOT}"
OLD_VERSION=$(jq -r '.version' .claude-plugin/plugin.json)
echo "Current version: $OLD_VERSION"

# Detect marketplace name from installed_plugins.json
MARKETPLACE=$(jq -r '.plugins | keys[] | select(startswith("uc@"))' ~/.claude/plugins/installed_plugins.json 2>/dev/null | head -1 | sed 's/^uc@//')
if [ -z "$MARKETPLACE" ]; then
  MARKETPLACE="ultra-claude"
  echo "Could not detect marketplace, using default: $MARKETPLACE"
else
  echo "Marketplace: $MARKETPLACE"
fi
```

Run the update:

```bash
claude plugin update "uc@${MARKETPLACE}"
```

Check the new version:

```bash
NEW_VERSION=$(jq -r '.version' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json")
echo "New version: $NEW_VERSION"
```

If versions match, tell the user "Already up to date (v{version})" and stop here.

## Step 2: Show Changelog

Read the changelog using jq:

```bash
# Get user's last known seq from setup marker
LAST_SEQ=$(jq -r '.seq // 0' ~/.claude/ultra/uc-setup.json 2>/dev/null || echo 0)

# Get entries since last known version
jq --argjson last "$LAST_SEQ" \
  '[.[] | select(.seq > $last)] | reverse | .[] | "\(.version) — \(.summary)"' \
  "${CLAUDE_PLUGIN_ROOT}/CHANGELOG.json"
```

If `~/.claude/ultra/uc-setup.json` does not exist or has no seq field, show the last 10 entries:

```bash
jq '.[0:10] | .[] | "\(.version) — \(.summary)"' "${CLAUDE_PLUGIN_ROOT}/CHANGELOG.json"
```

Format the output as a readable table for the user.

## Step 3: Migrate Global Files

Since v2026.04.04-15, Ultra Claude runtime files live under `~/.claude/ultra/` instead of `~/.claude/`. Check for files at the old locations and move them:

```bash
mkdir -p "$HOME/.claude/ultra"

# Files to move (old -> new)
for f in uc-setup.json usage-status.json; do
  if [ -f "$HOME/.claude/$f" ] && [ ! -f "$HOME/.claude/ultra/$f" ]; then
    mv "$HOME/.claude/$f" "$HOME/.claude/ultra/$f"
    echo "Moved $f -> ~/.claude/ultra/$f"
  elif [ -f "$HOME/.claude/$f" ] && [ -f "$HOME/.claude/ultra/$f" ]; then
    rm "$HOME/.claude/$f"
    echo "Removed stale ~/.claude/$f (already exists at new location)"
  fi
done

# Move statusline-auth directory
if [ -d "$HOME/.claude/statusline-auth" ] && [ ! -d "$HOME/.claude/ultra/statusline-auth" ]; then
  mv "$HOME/.claude/statusline-auth" "$HOME/.claude/ultra/statusline-auth"
  echo "Moved statusline-auth/ -> ~/.claude/ultra/statusline-auth/"
elif [ -d "$HOME/.claude/statusline-auth" ] && [ -d "$HOME/.claude/ultra/statusline-auth" ]; then
  rm -rf "$HOME/.claude/statusline-auth"
  echo "Removed stale ~/.claude/statusline-auth/ (already exists at new location)"
fi
```

Update the statusline symlink and settings.json if they still point to the old path:

```bash
# Re-create symlink at new location
if [ -L "$HOME/.claude/statusline.sh" ] || [ -f "$HOME/.claude/statusline.sh" ]; then
  rm -f "$HOME/.claude/statusline.sh"
  echo "Removed old ~/.claude/statusline.sh symlink"
fi
ln -sf "${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh" "$HOME/.claude/ultra/statusline.sh"
echo "Symlinked statusline.sh -> ~/.claude/ultra/statusline.sh"
ln -sf "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh" "$HOME/.claude/ultra/lib.sh"
echo "Symlinked lib.sh -> ~/.claude/ultra/lib.sh"

# Ensure session hook symlinks exist
mkdir -p "$HOME/.claude/ultra/hooks"
ln -sf "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/session-start.sh" "$HOME/.claude/ultra/hooks/session-start.sh"
ln -sf "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/session-end.sh" "$HOME/.claude/ultra/hooks/session-end.sh"
echo "Symlinked session hooks -> ~/.claude/ultra/hooks/"

# Update settings.json if it references the old path
settings_file="$HOME/.claude/settings.json"
if [ -f "$settings_file" ] && grep -q 'bash ~/.claude/statusline.sh' "$settings_file"; then
  jq '.statusLine.command = "bash ~/.claude/ultra/statusline.sh"' "$settings_file" > "${settings_file}.tmp" && mv "${settings_file}.tmp" "$settings_file"
  echo "Updated settings.json statusLine command to new path"
fi
```

If nothing was moved, skip silently — the user is already on the new layout.

## Step 4: Restart Tmux Layout Daemon

Kill the existing daemon and start fresh so it picks up any changes:

```bash
PID_FILE="$HOME/.claude/ultra/tmux-layout.pid"
if [ -f "$PID_FILE" ]; then
  kill "$(cat "$PID_FILE")" 2>/dev/null
  rm -f "$PID_FILE"
  sleep 1
  echo "Old layout daemon stopped"
fi

node "${CLAUDE_PLUGIN_ROOT}/scripts/tmux-layout-daemon.js" --ensure
```

## Step 5: Run Setup

Invoke `/uc:setup` to verify and fix the machine environment. Setup is idempotent — it will check all prerequisites, update symlinks, refresh hooks, and write the version marker. This ensures any new setup requirements introduced by the update are applied.

## Step 6: Check Migration Needs

Check CHANGELOG.json for migration entries between the old and new versions:

```bash
OLD_SEQ=$(jq -r '.seq // 0' ~/.claude/ultra/uc-setup.json 2>/dev/null || echo 0)
NEW_SEQ=$(jq '.[0].seq' "${CLAUDE_PLUGIN_ROOT}/CHANGELOG.json")

# Get pending migrations
jq --argjson old "$OLD_SEQ" --argjson new "$NEW_SEQ" \
  '[.[] | select(.seq > $old and .seq <= $new and .migration != null)]' \
  "${CLAUDE_PLUGIN_ROOT}/CHANGELOG.json"
```

Save the migration results for the recommendations step.

## Step 7: Recommendations

End with a summary of what the user should do next:

> **Updated to v{NEW_VERSION}.** Next steps:
>
> 1. **Reload plugins** — Run `/reload-plugins` or start a new Claude Code session to load the updated skills.

If migration entries were found in Step 6, also include:

> 2. **Run project migrations** — The following changes affect project structure:
>    - {version} — {summary}
>
>    Run `/uc:migrate` in each project to apply. You can do this now or next time you open each project.

If no migration entries exist, note: "No project migrations needed for this update."
