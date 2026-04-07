# Plan: Documentation Site

> **Execute:** `/uc:plan-execution 001`
> Created: 2026-04-07
> Status: Approved
> Source: Feature Mode

## Objective

Build a new documentation website for Ultra Claude using Express + EJS, deployed on Railway, replacing the old static HTML docs with a workflow-oriented site structured around startup-building phases.

## Context

- **Current state:** Old HTML docs were accidentally deleted in commit 490b6f5 (dashboard extraction), recovered but severely stale (35+ discrepancies vs current code). README.md directory tree is stale (lists 13 skills, 22 exist).
- **Verification report:** Full doc-code verification completed in this conversation — all discrepancy details are in conversation context.
- **Brainstorm decisions:** Index page = who/what/why (not feature-listing). Getting started = single path assuming existing project. Documentation = sidebar layout, workflow-oriented pages. Progressive disclosure via `<details>` elements.
- **Content sources:** Skill SKILL.md files are the source of truth. help/SKILL.md has ready-made 3-sentence descriptions for the reference page.

## Tech Stack

- Express.js (web server)
- EJS (templating — partials for nav, sidebar, head, footer)
- Railway (deployment)

## Scope

### In Scope

- Express + EJS server in `docs-site/` directory
- Shared partials: head (with SEO meta tags), top nav, sidebar, footer
- Shared CSS file
- Pages: index, getting-started, and 7 documentation pages (discovery, feature-planning, plan-execution, debugging, verification, standards, reference)
- Progressive disclosure on doc pages (`<details><summary>` for expandable sections)
- Nano Banana prompt file for workflow cycle diagram
- Railway deployment config (railway.toml)
- Updated README.md (standalone, accurate, links to ultra-claude.dev)
- Delete old `docs/*.html` files
- Update .gitignore for node_modules

### Out of Scope

- Help skill content fixes (internal accuracy, separate effort)
- CHANGELOG seq fix (internal, separate effort)
- Skill file edits
- Custom domain DNS changes (handled manually after deployment)
- CI/CD pipeline
- Analytics or tracking
- The workflow diagram image itself (Nano Banana produces it from the prompt)

## Success Criteria

- [ ] `npm start` in `docs-site/` serves all pages locally on port 3000
- [ ] All 10 pages render correctly with shared nav, sidebar (on doc pages), and consistent styling
- [ ] Doc pages have progressive disclosure sections that expand/collapse
- [ ] Each page has proper SEO meta tags (title, description, Open Graph)
- [ ] `railway.toml` is present and configured for Node.js deployment
- [ ] Old `docs/*.html` files are deleted (CNAME preserved if needed for transition)
- [ ] README.md accurately reflects current project state and links to documentation site
- [ ] Site is visually clean, responsive, and matches the existing purple/gray design language

## Task List

### Task 1: Express + EJS scaffold with shared partials and CSS <!-- status:pending -->
- [ ] **Complete**
- **Description:** Create the `docs-site/` directory with Express server, EJS view engine, shared partials (head, nav, sidebar, footer), shared CSS, and public assets directory. The server should serve all routes with proper partial includes. Head partial must accept page-specific title and description for SEO meta tags (including Open Graph). Sidebar partial renders only on documentation pages. Nav highlights the active section. CSS should use the existing purple/gray design language from the old HTML docs. Add `node_modules/` and `docs-site/node_modules/` to root `.gitignore`.
- **Product context:** Old `docs/index.html` and `docs/getting-started.html` for design language reference (CSS variables, color palette, typography, card styles)
- **Files:** `docs-site/package.json`, `docs-site/server.js`, `docs-site/views/partials/head.ejs`, `docs-site/views/partials/nav.ejs`, `docs-site/views/partials/sidebar.ejs`, `docs-site/views/partials/footer.ejs`, `docs-site/public/css/styles.css`, `.gitignore`
- **Patterns:** None identified
- **Success criteria:** `npm install && npm start` serves a skeleton page at localhost:3000 with working nav, sidebar placeholder, and consistent styling. All partials render without errors.
- **Dependencies:** None

### Task 2: Index page (Home) <!-- status:pending -->
- [ ] **Complete**
- **Description:** Build the index/landing page. Three sentences: who this is for, what problem it solves, how it works. Below that, a workflow map section with a placeholder for the Nano Banana diagram (use a styled placeholder div with alt text describing the cycle: Define Standards → Plan Feature → Execute with agents → Verify → loop back). Below the map, link cards into the documentation pages. Not a feature list — a bridge from "what is this" to "show me how." Keep the "Not a framework, library, or runtime" badge from the old design.
- **Product context:** Brainstorm decisions: audience is experienced devs/founders who want to ship production software faster with AI. One sentence who, one sentence problem, one sentence how. No manifesto.
- **Files:** `docs-site/views/index.ejs`
- **Patterns:** None identified
- **Success criteria:** Page loads at `/`, communicates the value proposition in under 10 seconds of reading, links into getting-started and documentation pages. Responsive on mobile.
- **Dependencies:** Task 1

### Task 3: Getting Started page <!-- status:pending -->
- [ ] **Complete**
- **Description:** Build the getting-started page with the quick-start flow: Install plugin → Run `/uc:setup` → Run `/uc:migrate` on your project → Review generated docs (with visual interstitial: "Take 5 minutes to review the generated architecture doc — everything that follows builds on it") → Plan first feature with `/uc:feature-mode` → Execute with `/uc:plan-execution`. Single path assuming existing project. Add a callout box after the install step: "Don't know exactly what to build? Run `/uc:discovery-mode` first to research and define your product." Mention `/uc:help` as the escape hatch ("Lost? Run `/uc:help` for guidance on which skill to use").
- **Product context:** Current `docs/getting-started.html` for structural reference (phase cards with numbered steps). Brainstorm decision: the one "stop and read" moment is after migrate, before feature-mode.
- **Files:** `docs-site/views/getting-started.ejs`
- **Patterns:** None identified
- **Success criteria:** Page loads at `/getting-started`, walks user from zero to first planned feature in a clear linear flow. The "review your docs" interstitial is visually distinct. Discovery callout is present but doesn't derail the main path.
- **Dependencies:** Task 1

### Task 4: Documentation pages — Discovery, Feature Planning, Debugging, Verification <!-- status:pending -->
- [ ] **Complete**
- **Description:** Build four documentation pages with sidebar layout. Each page has a concise overview (1-2 screens, ~300-500 words) visible by default, with expandable `<details><summary>` sections for deeper detail. Content sources: `skills/discovery-mode/SKILL.md` (discovery), `skills/feature-mode/SKILL.md` + plan-enhancer stages (feature planning), `skills/debug-mode/SKILL.md` (debugging), `skills/doc-code-verification-mode/SKILL.md` (verification). For each page: when to use it, what happens when you run it (user-facing narrative, not LLM instructions), what it produces, and how it connects to the next step. Feature Planning should end with "now run plan-execution." Debugging should explain the hypothesis-first approach. Verification should frame the two-dimension model (accuracy + structure).
- **Product context:** Skill SKILL.md files are the source of truth. The content surveyor summaries (in conversation context) identify what translates cleanly vs what needs rewriting.
- **Files:** `docs-site/views/docs/discovery.ejs`, `docs-site/views/docs/feature-planning.ejs`, `docs-site/views/docs/debugging.ejs`, `docs-site/views/docs/verification.ejs`
- **Patterns:** None identified
- **Success criteria:** All four pages render at `/docs/{name}` with sidebar, progressive disclosure works (sections expand/collapse), content accurately reflects current skill behavior, each page is self-contained but links to related pages.
- **Dependencies:** Task 1

### Task 5: Documentation pages — Plan Execution, Standards, Reference <!-- status:pending -->
- [ ] **Complete**
- **Description:** Build the three remaining documentation pages. **Plan Execution** (highest writing effort): explain task pipeline structure, agent roles (Executor writes code, Reviewer enforces standards, Tester validates), lazy spawning of Tester, concurrency model, how to resume after interruption (checkpoints as a paragraph, not standalone feature), what the user sees during execution (dashboard, escalation questions, completion summary). Source: `skills/plan-execution/SKILL.md` + 5 reference files + agent .md files. **Technology Standards** (highest original writing): assemble the define → enforce → verify loop from three separate sources — standards live in `documentation/technology/standards/`, Code Reviewer reads and enforces them on every task, Verification mode audits for drift. Frame this as the differentiator: "This is what separates prototyping with AI from building production systems with AI." Source: `skills/docs-manager/SKILL.md`, `agents/code-review.md`, `skills/doc-code-verification-mode/SKILL.md`. **Reference**: skills table (all 22, with invocation command and one-liner) and agents table (all 10, with role and model). Use help/SKILL.md descriptions as the primary source. Include `/uc:help`, `/uc:backlog`, `/uc:checkpoint` descriptions here.
- **Product context:** Content surveyor identified these as the two hardest pages. Plan Execution needs abstraction from LLM instructions to user narrative. Standards needs original assembly — the loop concept exists only in pieces across files.
- **Files:** `docs-site/views/docs/plan-execution.ejs`, `docs-site/views/docs/standards.ejs`, `docs-site/views/docs/reference.ejs`
- **Patterns:** None identified
- **Success criteria:** All three pages render at `/docs/{name}` with sidebar and progressive disclosure. Plan Execution clearly explains what happens when you run it. Standards page frames the define/enforce/verify loop as a coherent narrative. Reference table lists all 22 skills and 10 agents accurately.
- **Dependencies:** Task 1

### Task 6: Nano Banana diagram prompt + Railway deployment + README update + cleanup <!-- status:pending -->
- [ ] **Complete**
- **Description:** Four deliverables: (1) Write a Nano Banana prompt file at `docs-site/nano-banana-prompt.md` describing the workflow cycle diagram needed for the index page — the cycle (Define Standards → Plan Feature → Execute with agent team → Verify → loop back), that execution involves Executor + Reviewer + Tester, that verification closes the loop, and multiple entry points (discovery for greenfield, feature-mode for existing, debug-mode for bugs). Include style guidance matching the site's purple/gray palette. (2) Create `docs-site/railway.toml` with Node.js build and start commands. Add a `.env.example` documenting PORT. (3) Update root `README.md` to reflect current state: accurate skill count, accurate agent list, accurate directory tree, link to ultra-claude.dev for detailed documentation. Keep it standalone. (4) Delete all old `docs/*.html` files. Keep `docs/CNAME` only if needed during DNS transition — otherwise delete `docs/` entirely.
- **Product context:** README currently lists 13 skills (22 exist), omits project-manager agent, undercounts planning modes, shows empty templates directory, links to nonexistent HTML docs. All of this needs fixing.
- **Files:** `docs-site/nano-banana-prompt.md`, `docs-site/railway.toml`, `docs-site/.env.example`, `README.md`, delete `docs/architecture.html`, `docs/components.html`, `docs/decisions.html`, `docs/execution.html`, `docs/getting-started.html`, `docs/index.html`, `docs/migration.html`, `docs/research.html`, `docs/system-overview.html`, `docs/workflows.html`
- **Patterns:** None identified
- **Success criteria:** Nano Banana prompt clearly describes the diagram requirements and style. `railway.toml` configures a working Node.js deployment. README is factually accurate — every claim matches the filesystem. Old HTML files are deleted.
- **Dependencies:** Tasks 1-5

## Documentation Changes

No project-level documentation changes — this is the plugin repo itself, not a target project.

| File | Action | Summary |
|------|--------|---------|
| N/A | — | Plugin repo has no `documentation/` structure to update |

Additional documentation gaps identified (not yet addressed):

| File | Needed Change |
|------|---------------|
| `skills/help/SKILL.md` | Missing vscode-launch entry, Plan Enhancer loader claim wrong, Code Reviewer spawn timing wrong, Tech Research description wrong, agent spawning model wrong, Backlog entry too long |
| `CHANGELOG.json` | Duplicate seq=96 entries |

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Content accuracy — doc pages may describe features that changed since skill files were last read | Medium | Medium | Each task executor reads skill files directly, not cached summaries |
| Railway deployment may need env-specific config not anticipated | Low | Low | Express server is trivial; PORT from env var is the only config |
| Progressive disclosure `<details>` styling may be inconsistent across browsers | Low | Low | Use CSS to style, test on Chrome/Firefox/Safari |
| DNS transition from GitHub Pages to Railway may cause downtime | Medium | Low | Keep CNAME during transition, update DNS after Railway is confirmed working |
