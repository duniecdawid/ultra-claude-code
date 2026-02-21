# Research

Solutions evaluated and methodology references that informed the Ultra Claude design.

## Existing Solutions Evaluated

| Solution | What We Took | What We Skipped |
|----------|-------------|-----------------|
| [levnikolaevich/claude-code-skills](https://github.com/levnikolaevich/claude-code-skills) | Checkpoint/recovery system, quality gate pattern, doc-first pipeline | 103-skill complexity, Agile/RICE methodology, Linear integration |
| [wshobson/agents (Conductor)](https://github.com/wshobson/agents) | Doc-first workflow (Context→Spec→Plan→Implement), phase-gated execution | 112-agent marketplace scale, four-tier model strategy |
| [github/spec-kit](https://github.com/github/spec-kit) | Constitution concept, spec evolution model, change classification | CLI tooling, multi-agent-tool support (we're Claude Code only) |
| [avifenesh/agentsys](https://github.com/avifenesh/agentsys) | Drift detection pattern (77% fewer tokens) | Full 12-phase pipeline |
| [obra/superpowers](https://github.com/obra/superpowers) | Skill-creation meta-skill pattern | Specific implementation choices |
| [ruvnet/claude-flow](https://github.com/ruvnet/claude-flow) | SPARC methodology concepts | Unstable alpha, 400+ open issues, scope creep |
| [Anthropic official plugins](https://github.com/anthropics/claude-code/tree/main/plugins) | Plugin structure, hook patterns, agent definitions | Specific plugin implementations |

## Methodology References

| Source | Key Insight |
|--------|-------------|
| [Addy Osmani — Good specs for AI agents](https://addyosmani.com/blog/good-spec/) | Three-tier boundary: Always/Ask First/Never |
| [InfoQ — Spec-Driven Development](https://www.infoq.com/articles/spec-driven-development/) | Specs as "type system for distributed architecture" |
| [O'Reilly — Agentic AI for Architecture Governance](https://www.oreilly.com/radar/how-agentic-ai-empowers-architecture-governance/) | MCP as governance abstraction layer |
| [Fowler/Bockeler — Understanding SDD](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html) | Three maturity levels: Spec-First → Spec-Anchored → Spec-as-Source |
| [Claude Code Agent Teams Docs](https://code.claude.com/docs/en/agent-teams) | Official architecture, constraints, patterns |
| [Claude Code Plugin Structure](https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/plugin-structure/SKILL.md) | Official plugin format, auto-discovery, manifest |
