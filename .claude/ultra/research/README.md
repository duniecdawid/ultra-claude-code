# Claude Harness Research

This directory holds research about **Claude Code**, the **Claude Agent SDK**, and the **Anthropic API** — the tooling we build *with*, not the libraries the product depends *on*. Product/domain research lives under `documentation/technology/research/`.

Files are flat (no subdirectories): one file per Claude surface (`claude-code.md`, `claude-agent-sdk.md`, `anthropic-api.md`), with H2 sections per primitive (hooks, slash commands, MCP, sub-agents, tool use, prompt caching, etc.).

The cache is managed by `/uc:research` — **do not edit `index.json` by hand**. To refresh a stale entry, re-invoke the skill (`/uc:research claude code hooks`) and the researcher will overwrite the file and re-key the index.
