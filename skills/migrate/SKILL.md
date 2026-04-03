---
description: >
  Migrate projects to the latest Ultra Claude structure. Handles fresh initialization
  (greenfield), legacy project detection, and version-aware incremental upgrades.
  Use this skill whenever onboarding a project, upgrading after an Ultra Claude update,
  or when the update skill recommends running it. Triggers on "migrate", "init project",
  "initialize", "setup project", "onboard project", "bootstrap project", "upgrade project",
  "migrate docs", "docs migration", "onboard existing project".
argument-hint: "project name or description (optional)"
user-invocable: true
allowed-tools: [Bash, Read, Glob, Grep, Write, Edit, Agent, AskUserQuestion]
---

# Migrate

Target: $ARGUMENTS

You bring projects into Ultra Claude's spec-driven workflow and keep them current as Ultra evolves. You handle three distinct project states — detect which one applies, then follow the right path.

**Do NOT modify existing source code.** You only create/move documentation, configuration, and directory structure.

## Mode Detection

Check these paths to determine the project's state. For each config file, check both the current location (`.claude/ultra/`) and the legacy location (`.claude/`) since unmigrated projects use the old paths.

```bash
# Check version marker (current and legacy locations)
ls .claude/ultra/version.json 2>/dev/null || ls .claude/ultra-version.json 2>/dev/null

# Check for documentation structure
ls -d documentation/ 2>/dev/null

# Check for docs-format (current and legacy)
ls .claude/ultra/docs-format 2>/dev/null || ls .claude/docs-format 2>/dev/null
```

Use the results to select a mode:

| version.json found? | documentation/ exists? | Mode |
|---|---|---|
| No | No | **Fresh Init** |
| No | Yes | **Legacy Project** |
| Yes | — | **Upgrade** |

## Fresh Init

This is a brand new project with no Ultra Claude structure.

Read and follow `${SKILL_DIR}/references/fresh-init.md`.

This runs the full exploration and scaffolding pipeline: survey the codebase, plan the documentation structure, scaffold directories, derive config files, create standards, and register with the dashboard.

## Legacy Project

This project has Ultra Claude documentation but no version marker — it was set up before version tracking existed.

Read and follow `${SKILL_DIR}/references/legacy-detect.md`.

This detects which migrations have already been applied by examining the filesystem, offers to apply any that are missing, and stamps a version marker so future upgrades work cleanly.

## Upgrade

This project has a version marker — you know exactly where it stands.

Read and follow `${SKILL_DIR}/references/upgrade.md`.

This reads the changelog, identifies migrations between the project's version and the current Ultra version, and applies only what's needed. Fast and targeted.

---

## Shared: Version Stamping

All three modes end by writing `.claude/ultra/version.json`:

```json
{
  "initialized": "{version}",
  "initializedSeq": {seq},
  "lastMigrated": "{version}",
  "lastMigratedSeq": {seq},
  "migratedAt": "{ISO timestamp}"
}
```

For Fresh Init: both `initialized` and `lastMigrated` are set to the current Ultra version.
For Legacy Project: `initialized` is `"unknown"`, `lastMigrated` is the current version.
For Upgrade: only `lastMigrated` fields are updated; `initialized` stays unchanged.

Read the current Ultra version and seq:
```bash
jq -r '.version' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"
jq '.[0].seq' "${CLAUDE_PLUGIN_ROOT}/CHANGELOG.json"
```

## Shared: What's New Summary

After completing any mode, print a nicely formatted summary for the user. Use jq to get recent changelog entries:

```bash
# Get entries since the project's previous version (or last 10 for fresh init)
jq -r '.[0:10] | .[] | "  \(.version) — \(.summary)"' "${CLAUDE_PLUGIN_ROOT}/CHANGELOG.json"
```

Format as a readable "What's New in Ultra Claude" section — group by theme (new skills, fixes, improvements) when there are many entries. Include tips about new features relevant to the project.
