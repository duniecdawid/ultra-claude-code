# Implementation Plan

> Each phase is self-contained and executed in a fresh context sequentially.

## Context Loading Protocol (MANDATORY — every phase)

Before doing ANY implementation work, execute these steps in order:

### Step 1: Load all repo files
```
Load every file in the repository into context:
- README.md
- IMPLEMENTATION.md (this file)
- docs/architecture.md
- docs/components.md
- docs/decisions.md
- docs/execution.md
- docs/workflows.md
- docs/migration.md
- docs/research.md
- assets/system-overview.html
- .gitignore
- Plus ALL files created by previous phases (agents/*.md, skills/*/SKILL.md, hooks/*, templates/*, etc.)
```

### Step 2: Load skills for writing quality prompts
```
/skill-agent-creator   — for best practices on creating skills and agents (SKILL.md format, YAML frontmatter, agent .md format)
/prompt-architect      — for crafting high-quality system prompts (personas, context framing, chain-of-thought, constraints)
```

### Step 3: Review what's done
Check off completed items in this file. Identify the current phase. Read all files from previous phases to understand what exists.

### Step 4: Begin implementation
Start building the current phase's components in order.

---

## Phase 1 — Scaffold, Agents, Templates, Hooks

**Goal:** Plugin skeleton + all components that skills reference. After this phase: structurally complete, no skills yet.

**Dependencies:** None.

### 1.1 Plugin Manifest & Config

- [x] `.claude-plugin/plugin.json` — Exact JSON in `docs/components.md` → "Plugin Manifest"
- [x] `settings.json` — Exact JSON in `docs/components.md` → "Settings"

### 1.2 Agent Definitions (9 files)

All 9 agents listed in `docs/components.md` → "Agents" table (model, tools, purpose, spawn context per agent) + "Agent File Format" (YAML frontmatter schema).

System prompt guidance per agent — what the prompt must teach beyond the frontmatter:

- [x] `agents/researcher.md` — Dual-use (subagent in planning, teammate in execution). Prompt must handle both modes: when spawned as subagent, follow spawn prompt instructions for output paths; when spawned as teammate, follow shared memory protocol from `docs/execution.md` → "Shared Memory Pattern" (read all shared/ before each claim, write to shared/researcher.md append-only, write IDLE when done).
- [x] `agents/task-executor.md` — Teammate only. Prompt must implement the full shared memory read/write cycle from `docs/execution.md` → "Shared Memory Pattern" + per-task research file consumption. Key constraint: never modify files outside task scope.
- [x] `agents/task-tester.md` — Teammate only. Prompt must enforce: read-only for source code, Bash restricted to test/build commands. Final gate behavior from `docs/execution.md` → "Completion" phase. Reads `.claude/system-test.md` if present.
- [x] `agents/code-review.md` — Teammate only. Completely read-only. Pass/fail criteria sourced from `documentation/technology/standards/`. Failures must include specific file:line references per `docs/execution.md` → "Plan Execution Team Structure".
- [x] `agents/system-tester.md` — Subagent only (Debug Mode). Must NOT modify source. Reads `.claude/system-test.md`. See `docs/architecture.md` → "Debug Mode".
- [x] `agents/checker.md` — Subagent only (Verification Mode). Returns discrepancies with severity levels. See `docs/architecture.md` → "Doc & Code Verification Mode".
- [x] `agents/code-surveyor.md` — Subagent only. Returns structure overview. See `docs/components.md` → "Agents" table.
- [x] `agents/doc-surveyor.md` — Subagent only. Returns what's documented. See `docs/components.md` → "Agents" table.
- [x] `agents/market-analyzer.md` — Subagent only (Discovery Mode). See `docs/architecture.md` → "Discovery Mode".

### 1.3 Hooks

- [x] `hooks/hooks.json` — Three prompt-type hooks. Exact JSON structure in `docs/components.md` → "hooks.json Structure". Hook purposes in `docs/components.md` → "Hook Events" and "Hooks in Execution Context".
- [x] `hooks/scripts/` — Create empty directory (all hooks are prompt-type currently).

### 1.4 Templates (7 files)

All 7 templates listed in `docs/components.md` → "Templates" table (purpose, when created). Content structure for each should match the document types described in `docs/architecture.md` → "What Goes Where" table.

- [x] `templates/architecture.md`
- [x] `templates/rfc.md`
- [x] `templates/requirement.md`
- [x] `templates/plan.md` — This is the base structure Plan Enhancer will use. Must include embedded task list format.
- [x] `templates/context.md`
- [x] `templates/dependency.md`
- [x] `templates/task.md`

### 1.5 Init Script

- [x] `scripts/init-docs.sh` — Scaffolds `documentation/` + `context/` + `.claude/` config files in a target project. Directory tree defined in `docs/architecture.md` → "Documentation Structure". Config files listed in `docs/components.md` → "Project-Level Configuration". Must be idempotent (don't overwrite existing files). Copies templates as placeholders.

### Phase 1 Verification

- Plugin recognized by Claude Code (valid `plugin.json`)
- All 9 agent files have correct frontmatter schema per `docs/components.md` → "Agent File Format"
- `hooks.json` parses correctly
- All 7 templates exist
- `init-docs.sh` creates the full directory tree

---

## Phase 2 — Foundation Skills

> **FRESH CONTEXT** — Run the full [Context Loading Protocol](#context-loading-protocol-mandatory--every-phase) before starting.

**Goal:** Internal/support skills that planning modes depend on. After this phase: support infrastructure works, no user-facing modes yet.

**Dependencies:** Phase 1 complete.

All skills follow the format in `docs/components.md` → "Skill File Format" (YAML frontmatter schema, body format, `$ARGUMENTS`, `${CLAUDE_PLUGIN_ROOT}`).

### 2.1 Plan Enhancer (internal)

- [ ] `skills/plan-enhancer/SKILL.md` — NOT user-invocable. Auto-loaded by all planning modes via `context:` field. The critical bridge between planning modes and the plan directory structure. Behavior described in `docs/architecture.md` → "Planning Layer" and `docs/components.md` → Skills table. Key implementation detail: must override plan mode's default file path to write to `documentation/plans/{name}/README.md`. Task classification rules in `docs/execution.md` → "Task Classification".

### 2.2 Docs Manager (auto-activated)

- [ ] `skills/docs-manager/SKILL.md` — Activated by `.claude/docs-format` file. Full behavior described in `docs/architecture.md` → "Docs Manager as Guardian" (routing rules, structure enforcement, index generation, format awareness). The "What Goes Where" table is the routing reference.

### 2.3 Checkpoint

- [ ] `skills/checkpoint/SKILL.md` — User-invocable. Checkpoint contents and triggers defined in `docs/execution.md` → "Checkpoint Architecture". Format must be parseable by Lead on resume per `docs/execution.md` → "Session Resume".

### 2.4 Tech Research

- [ ] `skills/tech-research/SKILL.md` — User-invocable. Migrated from global skill per `docs/migration.md`. Depends on Ref.tools MCP (D7). Reads `.claude/app-context-for-research.md` for domain context.

### 2.5 Help (meta-skill)

- [ ] `skills/help/SKILL.md` — User-invocable. Described in `docs/architecture.md` → "The Help Meta-Skill". Needs a companion `skills/help/system-overview.md` loaded via `context:` field — a concise reference of all components/workflows (distill from `docs/components.md` and `docs/workflows.md`, don't duplicate).

### 2.6 Context Management

- [ ] `skills/context-management/SKILL.md` — User-invocable. Full behavior in `docs/architecture.md` → "Context Management Skill" (structuring, aggregation, git submodules, agent-ready summaries).

### Phase 2 Verification

- Plan Enhancer creates correct directory structure when loaded
- Docs Manager activates on `.claude/docs-format` presence and routes correctly
- `/uc:checkpoint` produces a parseable checkpoint file
- `/uc:tech-research` queries Ref.tools successfully
- `/uc:help` answers system questions
- `/uc:context-management` creates properly structured context entries

---

## Phase 3 — Planning Modes

> **FRESH CONTEXT** — Run the full [Context Loading Protocol](#context-loading-protocol-mandatory--every-phase) before starting.

**Goal:** All four user-facing planning modes + migration skill. After this phase: users can plan any work type. Execution not yet available.

**Dependencies:** Phase 2 complete.

Each planning mode's full workflow is in `docs/workflows.md` (step-by-step flows with edge cases). Architecture context (which agents spawn, how coordination works) is in `docs/architecture.md` → "Planning Mode Structures". Skill metadata in `docs/components.md` → Skills table.

All modes except Discovery load plan-enhancer via `context:` field.

### 3.1 Feature Mode

- [ ] `skills/feature-mode/SKILL.md` — User-invocable. Full flow: `docs/workflows.md` → "Feature Mode". Agent structure: `docs/architecture.md` → "Feature Mode" (under Planning Mode Structures). The most complex planning mode — includes optional RFC sub-mode with AI persona review. Key: loads both plan-enhancer (via context) and Docs Manager, spawns Researcher as subagent.

### 3.2 Debug Mode

- [ ] `skills/debug-mode/SKILL.md` — User-invocable. Full flow: `docs/workflows.md` → "Debug Mode". Agent structure: `docs/architecture.md` → "Debug Mode". Key: spawns multiple Researcher subagents (one per hypothesis) + System Tester subagent in parallel.

### 3.3 Doc & Code Verification Mode

- [ ] `skills/doc-code-verification-mode/SKILL.md` — User-invocable. Full flow: `docs/workflows.md` → "Doc & Code Verification Mode". Agent structure: `docs/architecture.md` → "Doc & Code Verification Mode". Key: spawns Code Surveyor + Doc Surveyor + Checker subagents. Supports scoped verification.

### 3.4 Discovery Mode

- [ ] `skills/discovery-mode/SKILL.md` — User-invocable. Full flow: `docs/workflows.md` → "Discovery Mode". Agent structure: `docs/architecture.md` → "Discovery Mode". Key differences from other modes: coding DISABLED (Q3 — implement via prompt for now), does NOT produce a plan, does NOT enter plan mode, does NOT load plan-enhancer. Output goes to `documentation/product/description/`.

### 3.5 Docs Migration

- [ ] `skills/docs-migration/SKILL.md` — User-invocable. One-time tool. Full description: `docs/architecture.md` → "Docs Migration Skill" (4-step process: survey, map, plan, execute). Spawns Code Surveyor + Doc Surveyor subagents. Produces plan executable via `/uc:plan-execution`.

### Phase 3 Verification

- Each mode enters correct state (plan mode or not), spawns correct subagents, produces output in correct location
- All planning modes (except Discovery) produce plans via Plan Enhancer in standardized format
- Plans include embedded task lists with classifications and success criteria
- Discovery mode blocks coding and writes to `product/description/`
- Edge cases from `docs/workflows.md` are handled

---

## Phase 4 — Execution Engine

> **FRESH CONTEXT** — Run the full [Context Loading Protocol](#context-loading-protocol-mandatory--every-phase) before starting.

**Goal:** The plan-execution skill — most complex component. After this phase: entire system functional end-to-end.

**Dependencies:** Phase 1-3 complete.

### 4.1 Plan Execution Skill

- [ ] `skills/plan-execution/SKILL.md` — User-invocable. **The primary reference for this skill is `docs/execution.md` — the entire document.** Read it cover to cover before implementing.

Key sections to translate into the skill prompt:

| What to implement | Reference |
|-------------------|-----------|
| 5-phase lifecycle (setup, parallel work, checkpoint, failure handling, completion) | `docs/execution.md` → "Workflow: Step-by-Step" |
| Dynamic team composition + cost estimates | `docs/execution.md` → "Dynamic Team Composition" |
| Spawn prompt templates per role | `docs/execution.md` → "Context Bridge" |
| 4 role-separated task lists + promotion flow | `docs/execution.md` → "Role-Separated Task Lists" |
| Task classification (Full/Standard/Trivial) | `docs/execution.md` → "Task Classification" |
| Shared memory protocol | `docs/execution.md` → "Shared Memory Pattern" |
| Checkpoint triggers + content | `docs/execution.md` → "Checkpoint Architecture" |
| Error recovery (task failure, teammate crash, session death) | `docs/execution.md` → "Error Recovery" |
| Mid-execution plan changes | `docs/execution.md` → "Mid-Execution Plan Changes" |
| Lead intervention points | `docs/execution.md` → "Lead Intervention Points" |
| Teammate completion protocol + IDLE | `docs/execution.md` → "Teammate Completion Protocol" |
| Session resume from checkpoint | `docs/execution.md` → "Session Resume" |
| Hook integration during execution | `docs/execution.md` → "Hook Integration" |
| Required permissions | `docs/execution.md` → "Required Permissions" |

The skill prompt is essentially a translation of `docs/execution.md` into actionable instructions for the Lead (main Claude session). It must include spawn prompt templates for each role — these are the most critical part since teammates start with blank context.

### Phase 4 Verification

- Reads plan and presents team composition + cost estimate
- User confirmation spawns correct teammates
- Teammates self-claim tasks, work in parallel
- Task promotion: research → impl → review → test
- Shared memory works (per-role files, read-all-before-claim)
- Checkpoint saves and resume works
- Failures re-queue correctly (max 2 retries)
- Final test suite gate runs before completion
- Summary report produced

---

## Implementation Notes

### Ordering Rationale
- **Phase 1** → skills reference agents, templates, and hooks — these must exist first
- **Phase 2** → all planning modes depend on plan-enhancer; Feature Mode depends on docs-manager
- **Phase 3** → planning modes are simpler than execution and produce plans Phase 4 consumes
- **Phase 4** → execution depends on everything: agents, hooks, support skills, and real plans

### Key Decisions
All in `docs/decisions.md`. Most critical for implementation: D1, D6, D9-D14, D15-D17.
