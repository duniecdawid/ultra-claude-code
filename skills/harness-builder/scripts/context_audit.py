#!/usr/bin/env python3
"""Estimate the resident-context cost of a Claude Code session.

Attributes token cost to individual items (skill descriptions, agent
descriptions, CLAUDE.md files, MCP config) so the biggest offenders can be
ranked and trimmed. Estimates are chars/4 (roughly +/-20%); Claude Code's
built-in /context command is the authoritative total.

Usage: context_audit.py [project-dir]   (default: cwd)
"""

import json
import os
import re
import sys
from pathlib import Path

CHARS_PER_TOKEN = 4
PER_ITEM_OVERHEAD = 12  # name, framing, list syntax around each catalog entry


def est_tokens(text: str) -> int:
    return len(text) // CHARS_PER_TOKEN + PER_ITEM_OVERHEAD


def frontmatter_description(md_path: Path) -> str:
    """Extract the description value from YAML frontmatter (best-effort)."""
    try:
        text = md_path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""
    m = re.match(r"\A---\n(.*?)\n---", text, re.DOTALL)
    if not m:
        return ""
    fm = m.group(1)
    dm = re.search(r"^description:\s*(.+?)(?=\n\S|\Z)", fm, re.MULTILINE | re.DOTALL)
    if not dm:
        return ""
    return " ".join(dm.group(1).split())


def plugin_roots():
    """Plugin source dirs from plugin-dirs.txt plus installed marketplaces."""
    roots = []
    dirs_file = Path.home() / ".claude" / "plugin-dirs.txt"
    if dirs_file.is_file():
        for line in dirs_file.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            p = Path(os.path.expanduser(line))
            if p.is_dir():
                roots.append(p)
    marketplaces = Path.home() / ".claude" / "plugins" / "marketplaces"
    if marketplaces.is_dir():
        for mp in marketplaces.iterdir():
            plugins_dir = mp / "plugins"
            if plugins_dir.is_dir():
                roots.extend(d for d in plugins_dir.iterdir() if d.is_dir())
            elif (mp / "skills").is_dir() or (mp / "agents").is_dir():
                roots.append(mp)
    # de-dup, preserve order
    seen, out = set(), []
    for r in roots:
        key = r.resolve()
        if key not in seen:
            seen.add(key)
            out.append(r)
    return out


def collect_skills(roots, project_dir: Path):
    items = []
    skill_dirs = [(r.name, r / "skills") for r in roots]
    skill_dirs.append(("user", Path.home() / ".claude" / "skills"))
    skill_dirs.append(("project", project_dir / ".claude" / "skills"))
    for owner, sdir in skill_dirs:
        if not sdir.is_dir():
            continue
        for skill in sorted(sdir.iterdir()):
            sm = skill / "SKILL.md"
            if sm.is_file():
                desc = frontmatter_description(sm)
                items.append((f"{owner}:{skill.name}", est_tokens(desc), len(desc)))
    return items


def collect_agents(roots, project_dir: Path):
    items = []
    agent_dirs = [(r.name, r / "agents") for r in roots]
    agent_dirs.append(("project", project_dir / ".claude" / "agents"))
    agent_dirs.append(("user", Path.home() / ".claude" / "agents"))
    for owner, adir in agent_dirs:
        if not adir.is_dir():
            continue
        for f in sorted(adir.glob("*.md")):
            desc = frontmatter_description(f)
            items.append((f"{owner}:{f.stem}", est_tokens(desc), len(desc)))
    return items


def collect_claude_md(project_dir: Path):
    items = []
    candidates = [
        Path.home() / ".claude" / "CLAUDE.md",
        Path(os.environ.get("CLAUDE_CONFIG_DIR", "")) / "CLAUDE.md"
        if os.environ.get("CLAUDE_CONFIG_DIR")
        else None,
    ]
    # project chain: walk from project dir up to home
    d = project_dir.resolve()
    home = Path.home().resolve()
    while True:
        candidates.append(d / "CLAUDE.md")
        candidates.append(d / "CLAUDE.local.md")
        if d == home or d.parent == d:
            break
        d = d.parent
    seen = set()
    for c in candidates:
        if c is None:
            continue
        c = c.resolve()
        if c in seen or not c.is_file():
            continue
        seen.add(c)
        text = c.read_text(encoding="utf-8", errors="replace")
        items.append((str(c), len(text) // CHARS_PER_TOKEN, len(text)))
    return items


def collect_mcp(project_dir: Path):
    """MCP servers configured for the project. Tool schemas of remote servers
    can't be enumerated offline — counts are servers, flagged estimate-only."""
    items = []
    for cfg in [project_dir / ".mcp.json", Path.home() / ".claude" / "mcp.json"]:
        if not cfg.is_file():
            continue
        try:
            data = json.loads(cfg.read_text())
        except (json.JSONDecodeError, OSError):
            continue
        for name in data.get("mcpServers", {}):
            items.append((f"{cfg}:{name}", 0, 0))
    return items


def print_block(title, items, note=None):
    total = sum(t for _, t, _ in items)
    print(f"\n## {title} — ~{total:,} tokens est. ({len(items)} items)")
    if note:
        print(f"_{note}_")
    if not items:
        print("(none found)")
        return total
    print(f"{'est. tokens':>12}  {'chars':>7}  item")
    for name, tok, chars in sorted(items, key=lambda x: -x[1])[:15]:
        print(f"{tok:>12,}  {chars:>7,}  {name}")
    if len(items) > 15:
        rest = sum(t for _, t, _ in sorted(items, key=lambda x: -x[1])[15:])
        print(f"{rest:>12,}           … {len(items) - 15} more")
    return total


def main():
    project_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    roots = plugin_roots()
    print("# Resident-context audit (estimates, chars/4 — /context is authoritative)")
    print(f"project: {project_dir}")
    print(f"plugin roots discovered: {len(roots)}")

    grand = 0
    grand += print_block(
        "Skill descriptions (always-resident catalog)",
        collect_skills(roots, project_dir),
    )
    grand += print_block(
        "Agent descriptions (always-resident roster)",
        collect_agents(roots, project_dir),
    )
    grand += print_block("CLAUDE.md files", collect_claude_md(project_dir))
    mcp_items = collect_mcp(project_dir)
    print_block(
        "MCP servers (config presence only)",
        mcp_items,
        note="tool names/schemas of remote servers can't be sized offline; "
        "each server also injects its tool list and instructions — check /context",
    )

    print(f"\n## Total attributable estimate: ~{grand:,} tokens")
    print(
        "(excludes harness-fixed cost: core tool schemas, system instructions, "
        "MCP tool listings — see /context for ground truth)"
    )


if __name__ == "__main__":
    main()
