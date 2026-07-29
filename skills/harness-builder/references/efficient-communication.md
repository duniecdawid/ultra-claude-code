# Efficient communication — compressing resident text

Scope: when and how to compress harness text using the caveman engine; the house style for agent-to-agent protocols. (For description frontmatter specifically, `description-writing.md` owns the budgets.)

## The economics — where compression pays

Token cost splits into **ephemeral** (one conversation) and **resident** (loaded every session or every turn: descriptions, agent prompt bodies, CLAUDE.md, protocol message formats, journals, memory files). Compressing resident text is a one-time cost that pays every future session. Compressing ephemeral output pays once and can cost clarity. **Default target: resident text only.**

## The engine: caveman, installed dormant

The caveman plugin (https://github.com/JuliusBrussee/caveman) is the compression engine. It is installed **hooks-off / dormant** — `defaultMode: off` in `~/.config/caveman/config.json`, so the SessionStart hook activates nothing and removes any stale flag. Sessions are normal prose unless explicitly opted in.

[MEASURED, upstream, 2026] ~65% output-token reduction (range 22–87%); `/caveman-compress` cuts ~46% from memory-style files. [COMMUNITY] The always-on variant costs ~1–1.5k input tokens/turn and degrades complex explanation — that is why we never enable it globally. Upstream's own numbers: `docs/HONEST-NUMBERS.md` in the caveman repo.

### Three sanctioned enablement patterns

1. **Per-session opt-in** — `/caveman [lite|full|ultra]` when a terse working session is wanted. Level dies with the session.
2. **File compression** — invoke the `caveman-compress` skill on a resident file (CLAUDE.md section, journal, memory file). The workhorse pattern. It rewrites the file in place, so review the diff before committing and run the key-term check below; the behaviours in "Invoking the engine safely" apply here too — in particular it will not touch frontmatter, and it refuses filenames that look sensitive.
3. **Per-artifact review** — spawn the `uc:caveman-reviewer` agent (this plugin) on persistent harness text, two stages: structural findings first (user confirms the structural work), then the engine pass, consumed item by item. **Not optional:** this is SKILL.md's mandatory gate — batched when the change set settles, not per intermediate revision. Spawn form, stages, and the only sanctioned no-op are in SKILL.md § "Mandatory gate".

### Invoking the engine safely

[MEASURED 2026-07-27, against the installed checkout] `caveman-compress` is a CLI — `python3 -m scripts <abs file>` from the dir holding its SKILL.md — that compresses via a Claude call, then runs `scripts/validate.py` (code-block byte-equality, URL set equality, inline-code occurrence counts, heading count, bullet-count drift) and retries with a targeted fix prompt, restoring the original if validation never passes. That validator and retry loop are the reason to **invoke** rather than re-apply the rules by hand.

It overwrites the file it is given, so the only safe way to use it for review is on a **scratch copy**. Six behaviours that change your result:

1. **Frontmatter is split off and re-prepended verbatim.** A `description:` field is therefore untouched by an in-file run — exit 0, "Validation passed", zero change. Descriptions are not an engine job; they belong to `description-writing.md`. Forced through as a body-only file the engine produced `token-compressed` → `token-small` (6% saving, discriminating term destroyed) — routing-hostile by construction.
2. **The filename denylist hard-refuses anything that looks secret** — basename containing `token`, `secret`, `credential`, `password`, `key`, or living under `.ssh`/`.aws`/`.gnupg`/`.kube`/`.docker`. Measured: `token-efficiency.md` is refused. For a token-compression tool, harness filenames trip this constantly — copy to a neutral scratch name (`artifact.md`) and it never fires.
3. **Extension gate:** only `.md`, `.txt`, `.markdown`, `.rst`, `.typ`, `.typst`, `.tex` and extensionless files are compressed; `.ejs`, `.json`, `.py`, `.yaml` and friends are skipped. Copy the artifact into a `.md` scratch file to review non-markdown resident text.
4. **Backups are out-of-tree and collide.** `~/.local/share/caveman-compress/backups/<parent-dir-name>/<stem>.original.md` — keyed on the parent directory *name*, not the full path — and the engine **aborts** if that backup already exists. Use a fresh scratch dir per run; a second run in a same-named dir refuses until you clear it.
5. **The trailing newline at EOF is dropped.** The validator does not check it. Restore it before adopting any output.
6. **Model:** with `ANTHROPIC_API_KEY` set it uses the SDK and defaults to `claude-sonnet-4-5` — below the Opus floor (non-negotiable #1); export `CAVEMAN_MODEL=claude-opus-5`. Without the key it shells out to `claude --print`, which runs the machine's configured default model.

Yields, same date: 4.0% on a reference doc that is roughly half URLs/quotes/tables, 6.8% on an agent prompt body. Hand-applying the rules to the identical reference doc yielded 2.4% — the engine's exit code carries a validator pass instead of an eyeballed assertion, so reviewing is copy → invoke → diff with no separate checking step.

[MEASURED 2026-07-29, docs-manager overhaul] 16 engine runs on harness artifacts yielded 5–12.5% whole-file, while the structural pass on the same directory saved −68% on the SKILL.md and −32% overall. Consequences (supersedes the earlier engine-first framing): the engine is **stage 2** of the review protocol — structural optimisation (`structural-optimization.md`) always runs first — and engine output is consumed **per item** (adopt clean cuts, adopt fixable ones in repaired form, skip harmful ones), never accepted or rejected wholesale on yield percentage.

### Never

- Auto-enable hook / always-on caveman.
- Compressing user-facing prose, teaching material, or complex explanations (measured weakness).
- Touching code, commands, identifiers, error messages — byte-for-byte exact, always.
- Copying caveman's ruleset into our files — invoke the installed engine (non-negotiable #2). Re-applying its rules by hand when the CLI is reachable is the same mistake wearing a lazier hat: it forfeits the validator and the retry loop, and drifts as upstream changes. If caveman is absent on a machine, the house rules below stand alone; say so rather than failing.

## House rules layered on top of the engine

Caveman optimizes for brevity; the harness also needs **routing safety**. Any compression of harness text must additionally satisfy:

0. **Structural review precedes lexical compression, always** — run the `structural-optimization.md` catalogue first; compressing text that should be deleted or merged wastes the pass.
1. **Discriminating-key-term preservation.** Key terms are the routing surface. Diff the before/after noun+verb set; every dropped discriminator is a risk flag, not a silent cut.
2. **Budgets from `description-writing.md`** apply to descriptions regardless of engine output.
3. **Protocol formats stay parseable.** When compressing agent-to-agent message formats, field names and structure are contract — compress the prose around them, never the fields.
4. **Fragments yes, ambiguity no.** "New object ref each render. Wrap in `useMemo`." is the target register: dropped filler, intact meaning.

## House style for agent-to-agent protocols

When designing messages agents exchange (status pulses, signals, review verdicts):

- Fixed, named fields over free prose; one line per message where possible.
- No pleasantries, hedging, or restating what the recipient already knows.
- Reserve prose for the one thing that is genuinely new information.
- Put the machine-readable part first, the human-readable remainder after.
