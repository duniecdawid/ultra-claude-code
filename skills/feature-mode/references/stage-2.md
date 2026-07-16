# Feature Mode — Stage 2: Research

Before applying the rules below, read the base rules:
`${CLAUDE_PLUGIN_ROOT}/references/planning-framework/stage-2.md`

The instructions below extend the base rules with feature-mode-specific behavior.
**Precedence:** base first, then extensions. If they conflict, the extension wins.

## Mode Extensions

Use the base research skills (code-surveyor, doc-surveyor, research) to understand how the feature fits into the existing system. Scope the surveyors with these focal points:

- **Code** — What components will this feature build on, extend, or interact with?
- **Documentation** — What architecture, product description, and requirements docs are relevant?
- **External libraries** — Are there new dependencies or integrations to investigate? Invoke `/uc:research` whenever the answer is yes — it's cache-first, so repeated lookups across plans are free.

If the surveyors reveal **cross-component complexity** (a feature touching multiple subsystems with non-obvious interactions) or **undocumented patterns** (code conventions that need to be understood before extending), spawn additional Explore agents to do deeper investigation (same one-shot fan-out config as the surveyors — no `name`, explicit `run_in_background: true`; Mode F per `${CLAUDE_PLUGIN_ROOT}/references/agent-spawn-modes.md` — collect every completion notification before moving on). The base surveyors give you a structural map; Explore gives you the line-by-line context for the parts that matter.

**Tech Stack sweep input for feature mode:** the base framework's mandatory Tech Stack sweep needs an in-scope file set. For feature mode, that's the Files list from your draft task breakdown. Track the library-to-draft-task mapping as you sweep — Stage 4 Step 5b turns it into each `task.md`'s `**Research:**` section.

## Stage Transition

When the base verification gates pass and you have synthesized findings you can discuss, announce:

> **▶ PROCEED TO STAGE 3: DISCUSS**

Then read:
`${CLAUDE_PLUGIN_ROOT}/skills/feature-mode/references/stage-3.md`
