# Debug Mode — Stage 1: Understand

Before applying the rules below, read the base rules:
`${CLAUDE_PLUGIN_ROOT}/references/planning-framework/stage-1.md`

The instructions below extend the base rules with debug-mode-specific behavior.
**Precedence:** base first, then extensions. If they conflict, the extension wins.

## Mode Extensions

Parse the bug report and extract:

1. **Symptoms** — What is the observed behavior?
2. **Expected behavior** — What should happen instead?
3. **Reproduction context** — Environment, steps to reproduce, frequency (always, intermittent, once).
4. **Impact** — Who/what is affected? Severity?

If any of these are missing or unclear, ask the user via AskUserQuestion. A vague bug report produces vague fixes. If you think they're describing a symptom rather than the root problem, say so — bugs that look obvious are the ones most likely to be misdiagnosed.

The base rule "ask at least 3 questions" still applies. Even when the user provides a detailed report, your questions are about what they didn't realize they missed: unstated assumptions, environmental factors, second-order effects.

## Stage Transition

When you have satisfied the base Stage 1 rules and extracted symptoms / expected / repro / impact (or explicitly noted what you couldn't get), announce:

> **▶ PROCEED TO STAGE 2: RESEARCH**

Then read:
`${CLAUDE_PLUGIN_ROOT}/skills/debug-mode/references/stage-2.md`
