# Fresh Init

Full initialization pipeline for a project with no existing Ultra Claude structure.

## Prerequisite References

Before starting, read these reference files:
- `${CLAUDE_PLUGIN_ROOT}/skills/docs-manager/SKILL.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/docs-manager/references/standard.md`

## Process

Execute these phases in order: Safety Check -> Explore -> Plan -> Execute.

---

### Phase 0: Safety Check

Warn the user:

> This skill may create directories, write configuration files, and move documentation. I recommend committing your current changes before proceeding so you can easily revert if needed. Should I continue?

Options: "Continue — I've committed (or don't need to)" / "Wait — let me commit first"

Only proceed after user confirms.

---

### Phase 1: Explore (read-only research)

Gather all information before proposing anything. Do not write any files in this phase.

#### 1a — Quick scan

Do a top-level scan (Glob + ls) to understand project size and structure:
- Count top-level directories and total files
- Identify if `documentation/`, `context/`, `.claude/` already exist
- Get a sense of project scale (small / medium / large / monorepo)

#### 1b — Spawn surveyor pairs

Read `${SKILL_DIR}/references/surveyor-prompts.md` for the exact subagent prompts.

Spawn Code Surveyor and Doc Surveyor subagents in parallel, scaled to project size:

- **Small project** (few top-level dirs, <50 files): 1 Code Surveyor + 1 Doc Surveyor covering the whole project
- **Medium project**: 2-3 pairs, each scoped to a subset of top-level directories
- **Large project / monorepo**: Up to 5 pairs, each scoped to a major area (e.g., `packages/auth`, `services/`, `libs/`)

Wait for all surveyors to complete. Merge results into unified code + doc reports.

#### 1c — Ask questions

For anything that couldn't be determined from the surveys, ask the user using AskUserQuestion:

- Can't determine project purpose/domain -> ask "What does this project do?"
- No test framework detected -> ask "What testing setup does this project use? (or 'skip')"
- No environment info found -> ask "How do developers set up locally? (or 'skip')"
- Ambiguous document classification -> ask "Where should `docs/X.md` go?" with options mapped to canonical structure
- Multiple valid interpretations -> ask the user to clarify

Only ask questions that are genuinely unresolvable from the survey data. Don't ask about things you can reasonably infer. Never assume or fabricate the user's answers — always wait for their actual response via AskUserQuestion.

---

### Phase 2: Plan

Using all survey findings + user answers, produce a comprehensive plan covering everything you intend to do. Present the complete plan in chat for user approval.

Read these references for Phase 2:
- `${SKILL_DIR}/references/claude-md-template.md` — the CLAUDE.md section to inject
- `${SKILL_DIR}/references/config-specs.md` — `.claude/ultra/` file specs, standards signals table, and migration mapping rules
- `${SKILL_DIR}/references/readme-promo.md` — the promo footer to add to the project README

The plan includes these task groups, in order:

#### Group 1 — Scaffold canonical structure

- Create each missing directory in the canonical `documentation/` tree (see Docs Manager for the full layout)
- Copy documentation templates from `${CLAUDE_PLUGIN_ROOT}/skills/docs-manager/references/` (use embedded templates from each reference) and plan/task templates from `${CLAUDE_PLUGIN_ROOT}/templates/` where no file exists yet
- Generate `documentation/README.md` index if missing
- Create `context/` directory if missing
- Create `.claude/ultra/` directory
- Only create what doesn't already exist — never overwrite

#### Group 2 — Configure project CLAUDE.md and `.claude/ultra/` files

Apply the CLAUDE.md template from `references/claude-md-template.md`. Derive `.claude/ultra/` config files per specs in `references/config-specs.md`.

#### Group 2.5 — Standards and System Test Planning

Compile candidate standards from the Code Surveyor's Standards Signals. Present approval table to user per format in `references/config-specs.md` (Standards Signals Table section).

For any topic where user selects "Create (I'll add context)" — follow up with AskUserQuestion to collect their additional context before proceeding to Phase 3.

User must approve before any Explore agents spawn. Only an explicit approval counts — empty, blank, or ambiguous responses must be re-asked.

#### Group 3 — Bootstrap/migrate documentation

Determine the action based on what Phase 1 found:

| Canonical docs exist? | Non-canonical docs exist? | Action |
|---|---|---|
| No | No | **Greenfield**: draft architecture doc from code survey |
| No | Yes | **Migration**: map all found docs to canonical locations |
| Yes | Yes | **Mixed**: draft for gaps + migrate misplaced docs |
| Yes | No | **Already set up**: note what exists, skip this group |

For **greenfield** (no existing docs):
- Draft `documentation/technology/architecture/README.md` from Code Surveyor findings (system components, data flow, tech stack, external integrations)
- Draft any other documentation that can be reasonably derived from the survey

For **migration** (existing docs in non-standard locations):
- Present a mapping table: current location -> target location -> action (move)
- Use migration mapping rules from `references/config-specs.md`
- Flag ambiguous docs with the user's answers from Phase 1c
- Move files to canonical locations (delete originals after successful move)
- Clean up empty directories left behind after moves

For **mixed**: apply both greenfield (for gaps) and migration (for misplaced docs) as appropriate.

#### Group 4 — Regenerate index

- Update `documentation/README.md` to reflect final state after all creates/moves

#### Group 5 — Migrate dependencies to backlog

If `documentation/dependencies/` exists with markdown files (excluding README.md):
1. For each file, extract open items (### headings with **Priority:** and **Blocks:** fields)
2. Create backlog items in `documentation/backlog/questions.json` with Q-NNN IDs, priority from field, notes=blocks field, source="migrated"
3. Create the `documentation/backlog/` directory if needed
4. Move `documentation/dependencies/` to `documentation_archive/dependencies/`
5. Report: "Migrated N dependency items to backlog"

If the directory is empty or doesn't exist, skip silently.

#### Group 6 — README promo footer

Add the Ultra Claude promo footer to the project's root `README.md` per
`${SKILL_DIR}/references/readme-promo.md`. Idempotent and marker-guarded: skip if the
`<!-- ultra-claude:promo -->` marker is already present, append the footer if a README exists without
it, or create a minimal README if none exists.

Ask for approval via AskUserQuestion: "Review the initialization plan above. Proceed?" Options: "Approve" / "Reject with feedback" / "Approve with changes". Only an explicit "Approve" counts — empty, blank, or ambiguous responses must be re-asked.

---

### Phase 3: Execute (after plan approval)

Phase 3 runs in three stages. Stages A and B run in parallel; Stage C waits for Stage B to complete.

#### Stage A: Core Execution (Groups 1-4)

Create `documentation/technology/standards/` directory inline before spawning.

Spawn Task Executor agent(s) (subagent_type `uc:Task Executor`) to carry out Groups 1-4 from the approved plan. Provide the agent with:
- The full approved plan (Groups 1-4)
- The merged survey results for reference
- The canonical structure definition from Docs Manager
- Clear instructions for each task group

The agent executes: create directories, write config files, copy templates, move documentation, clean up empty directories, generate/update index.

For very large projects (many files to move, 4+ task groups with significant work), spawn multiple Task Executor agents in parallel — one per task group.

#### Stage B: Research Phase (parallel with Stage A)

Read `${SKILL_DIR}/references/explore-prompts.md` for the exact subagent prompts.

For each approved standard topic + testing config, spawn an Explore agent (subagent_type `Explore`, thoroughness: `very thorough`). Run up to 5 agents in parallel; batch if more.

#### Stage C: Standards Writing (after Stage B completes)

Read `${SKILL_DIR}/references/executor-prompts.md` for the exact subagent prompts.

Wait for all Stage B Explore agents to finish. Then, for each approved standard + testing config, spawn a Task Executor (subagent_type `uc:Task Executor`). Run up to 5 executors in parallel; batch if more.

Pass the Explore agent results directly into the executor spawn prompt — no intermediate research file needed since Explore agents return results inline.

#### Parallelism Summary

- **Stage A + Stage B**: Run in parallel (write to different paths)
- **Stage C**: Waits for Stage B to complete (needs exploration results)
- **Within Stage B**: All Explore agents run in parallel (up to 5 at a time, batch if more)
- **Within Stage C**: All Executors run in parallel (up to 5 at a time, batch if more)

After all stages complete, verify results and report.

---

### Summary

End with a concise report:

- **Scaffolded**: directories created/verified
- **Configured**: CLAUDE.md updated with Ultra Claude section, which `.claude/ultra/` files were populated (and which skipped)
- **Promo footer**: Ultra Claude footer added to `README.md` (appended / created / skipped — already present)
- **Documented**: architecture/docs bootstrapped or migrated
- **Migrated**: files moved to canonical locations (originals removed)
- **Standards created**: {list of files with core principle for each}
- **Testing config**: `documentation/technology/testing/` with 6 files — {N} security categories, {N} tester rules, final-gate instructions
- **Standards gaps**: topics where evidence was thin (flagged with NOTE sections in the standard files)
- **Gaps remaining**: canonical sections still using placeholders
- **Next steps**:
  - Review generated standards and refine based on team preferences
  - Add project-specific code examples to strengthen thin standards
  - `/uc:doc-code-verification-mode` — verify and improve documentation against actual code (recommended first)
  - `/uc:discovery-mode` — for product research and requirements
  - `/uc:feature-mode` — to plan the first feature
  - `/uc:help` — for guidance on any task

Then stamp the version marker and print the "What's New" summary (see main SKILL.md).

---

## Constraints

- Do NOT modify existing source code
- Do NOT overwrite existing `.claude/ultra/` config files without user approval in the plan
- Migration moves files (delete originals after successful move, clean up empty directories)
- Do NOT create files outside `CLAUDE.md`, `README.md`, `documentation/`, `context/`, and `.claude/`. The only permitted `README.md` write is the marker-guarded promo footer (append or create-if-missing) per `references/readme-promo.md` — never rewrite existing README content
- Ask questions in Phase 1 for anything ambiguous — don't guess
- Always present the full plan and get user approval before creating or moving files
