# Efficient communication — compressing resident text

Scope: when and how to compress harness text using the caveman engine; the house style for agent-to-agent protocols. (For description frontmatter specifically, `description-writing.md` owns the budgets.)

## The economics — where compression pays

Token cost splits into **ephemeral** (one conversation) and **resident** (loaded every session or every turn: descriptions, agent prompt bodies, CLAUDE.md, protocol message formats, journals, memory files). Compressing resident text is a one-time cost that pays every future session. Compressing ephemeral output pays once and can cost clarity. **Default target: resident text only.**

## The engine: caveman, installed dormant

The caveman plugin (https://github.com/JuliusBrussee/caveman) is the compression engine. It is installed **hooks-off / dormant** — `defaultMode: off` in `~/.config/caveman/config.json`, so the SessionStart hook activates nothing and removes any stale flag. Sessions are normal prose unless explicitly opted in.

[MEASURED, upstream, 2026] ~65% output-token reduction (range 22–87%); `/caveman-compress` cuts ~46% from memory-style files. [COMMUNITY] The always-on variant costs ~1–1.5k input tokens/turn and degrades complex explanation — that is why we never enable it globally. Upstream's own numbers: `docs/HONEST-NUMBERS.md` in the caveman repo.

### Three sanctioned enablement patterns

1. **Per-session opt-in** — `/caveman [lite|full|ultra]` when a terse working session is wanted. Level dies with the session.
2. **File compression** — invoke the `caveman-compress` skill on a resident file (CLAUDE.md section, journal, memory file). The workhorse pattern. Always review the diff before committing; run the key-term check below.
3. **Per-artifact review** — spawn the `caveman-reviewer` agent (this plugin) on just-written persistent harness text. It returns a proposition; the parent decides.

### Never

- Auto-enable hook / always-on caveman.
- Compressing user-facing prose, teaching material, or complex explanations (measured weakness).
- Touching code, commands, identifiers, error messages — byte-for-byte exact, always.
- Copying caveman's ruleset into our files — invoke the installed engine (non-negotiable #2). If caveman is absent on a machine, the house rules below stand alone; say so rather than failing.

## House rules layered on top of the engine

Caveman optimizes for brevity; the harness also needs **routing safety**. Any compression of harness text must additionally satisfy:

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
