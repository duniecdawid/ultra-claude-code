---
description: Update Ultra Claude to the latest version — pulls from git, clears plugin cache, restarts dashboard, and checks if projects need migration. Use when user says "update", "upgrade", "pull latest", "refresh plugin", "update ultra claude", "get latest version", or after hearing about new features they want. Run this skill proactively if the user mentions wanting a feature that might already exist in a newer version.
user-invocable: true
allowed-tools: [Bash, Read, Glob, Grep]
---

# Update Ultra Claude

Updates the plugin to the latest version and handles all post-update housekeeping.

## Step 1: Pull Latest

Get the current version before pulling, then update:

```bash
cd "${CLAUDE_PLUGIN_ROOT}"
OLD_VERSION=$(jq -r '.version' .claude-plugin/plugin.json)
echo "Current version: $OLD_VERSION"
git pull
NEW_VERSION=$(jq -r '.version' .claude-plugin/plugin.json)
echo "New version: $NEW_VERSION"
```

If versions match, tell the user "Already up to date (v{version})" and stop here.

Show what changed:

```bash
cd "${CLAUDE_PLUGIN_ROOT}"
git log --oneline HEAD@{1}..HEAD
```

## Step 2: Show Changelog

Read the changelog using jq:

```bash
# Get user's last known seq from setup marker
LAST_SEQ=$(jq -r '.seq // 0' ~/.claude/uc-setup.json 2>/dev/null || echo 0)

# Get entries since last known version
jq --argjson last "$LAST_SEQ" \
  '[.[] | select(.seq > $last)] | reverse | .[] | "\(.version) — \(.summary)"' \
  "${CLAUDE_PLUGIN_ROOT}/CHANGELOG.json"
```

If `~/.claude/uc-setup.json` doesn't exist or has no seq field, show the last 10 entries:

```bash
jq '.[0:10] | .[] | "\(.version) — \(.summary)"' "${CLAUDE_PLUGIN_ROOT}/CHANGELOG.json"
```

Format the output as a readable table for the user.

## Step 3: Clear Plugin Cache

Remove any cached copies of the uc plugin so Claude Code picks up the fresh source:

```bash
# Remove cached plugin versions
rm -rf ~/.claude/plugins/cache/*/uc/ 2>/dev/null
echo "Plugin cache cleared"
```

Update the installed plugins registry if it tracks uc:

```bash
INSTALLED="$HOME/.claude/plugins/installed_plugins.json"
if [ -f "$INSTALLED" ] && jq -e '."uc@ultra-claude"' "$INSTALLED" > /dev/null 2>&1; then
  NEW_VERSION=$(jq -r '.version' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json")
  jq --arg v "$NEW_VERSION" --arg t "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" \
    '."uc@ultra-claude".version = $v | ."uc@ultra-claude".lastUpdated = $t' \
    "$INSTALLED" > "${INSTALLED}.tmp" && mv "${INSTALLED}.tmp" "$INSTALLED"
  echo "Registry updated to v$NEW_VERSION"
fi
```

## Step 4: Force Restart Dashboard

Kill the existing dashboard and start fresh so it picks up any server-side changes:

```bash
PID_FILE="$HOME/.claude/dashboard.pid"
if [ -f "$PID_FILE" ]; then
  kill "$(cat "$PID_FILE")" 2>/dev/null
  rm -f "$PID_FILE"
  sleep 1
  echo "Old dashboard stopped"
fi

node "${CLAUDE_PLUGIN_ROOT}/scripts/ultra-dashboard/index.js" --ensure
```

Verify it's running:

```bash
sleep 2
curl -sf http://localhost:3847/api/version
```

## Step 5: Check Migration Needs

Check CHANGELOG.json for migration entries between the old and new versions:

```bash
OLD_SEQ=$(jq -r '.seq // 0' ~/.claude/uc-setup.json 2>/dev/null || echo 0)
NEW_SEQ=$(jq '.[0].seq' "${CLAUDE_PLUGIN_ROOT}/CHANGELOG.json")

# Get pending migrations
jq --argjson old "$OLD_SEQ" --argjson new "$NEW_SEQ" \
  '[.[] | select(.seq > $old and .seq <= $new and .migration != null)]' \
  "${CLAUDE_PLUGIN_ROOT}/CHANGELOG.json"
```

If migration entries exist:

1. List each migration with version + summary
2. Read `~/.claude/dashboard-projects.json` to get registered projects:
   ```bash
   jq -r '.[]' ~/.claude/dashboard-projects.json 2>/dev/null
   ```
3. Actively recommend migration:

> **Project migrations available.** These changes affect project structure:
> - {version} — {summary}
>
> **Registered projects that should be migrated:**
> - {project path}
>
> Run `/uc:migrate` in each project to apply the changes. You can do this now or next time you open each project.

If the user wants to migrate now, offer to help — but don't do it without asking.

If no migration entries exist: "No project migration needed for this update."

## Step 6: Update Setup Marker

Bump the version in the setup marker so `/uc:setup` doesn't nag about being out of date:

```bash
MARKER="$HOME/.claude/uc-setup.json"
NEW_VERSION=$(jq -r '.version' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json")
if [ -f "$MARKER" ]; then
  jq --arg v "$NEW_VERSION" --arg t "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" \
    '.version = $v | .timestamp = $t' "$MARKER" > "${MARKER}.tmp" && mv "${MARKER}.tmp" "$MARKER"
else
  echo "{\"version\":\"$NEW_VERSION\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\"}" > "$MARKER"
fi
echo "Setup marker updated to v$NEW_VERSION"
```

## Step 7: Reload Notice

End with:

> Updated to v{NEW_VERSION}. Start a new Claude Code conversation to load the updated skills — plugins are loaded at startup.
