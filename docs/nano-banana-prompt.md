# Workflow Cycle Diagram — Ultra Claude

## Purpose
This diagram appears on the Ultra Claude documentation homepage (ultra-claude.dev) as the primary visual explaining how the system works. It needs to communicate the core development cycle at a glance.

## The Cycle
A circular/loop diagram with four stages connected by arrows:

1. **Define Standards** — Write coding standards as documentation (conventions, patterns, anti-patterns)
2. **Plan Feature** — AI challenges scope, researches codebase, produces structured plan with tasks
3. **Execute** — Agent team per task: Executor (writes code) + Reviewer (enforces standards) + Tester (validates)
4. **Verify** — Check that code still matches documentation, detect drift, fix discrepancies

The arrow from Verify loops back to Define Standards, completing the cycle.

## Entry Points
Three entry points into the cycle (shown as arrows from outside pointing into the appropriate stage):
- **Discovery** → enters before Plan Feature (for greenfield projects that need product research first)
- **Feature Mode** → enters at Plan Feature (most common — adding features to existing projects)
- **Debug Mode** → enters at Plan Feature (for bug investigation, produces fix plans)

## Agent Team Detail
Inside or adjacent to the Execute stage, show the three-agent structure:
- **Executor** (Opus) — writes code
- **Reviewer** (Sonnet) — enforces standards
- **Tester** (Sonnet) — validates against requirements

These three work as a team per task. Show them as connected nodes or stacked roles.

## Style Guide
- **Color palette**: White/light gray background, purple (#8B5CF6) as the primary accent color, dark gray/near-black (#1F2937) for text and borders
- **Aesthetic**: Clean, minimal, shadcn-inspired — subtle borders, no gradients, no heavy shadows. Professional and restrained.
- **Typography**: Sans-serif (Geist or Inter style), clean weights
- **Format**: SVG preferred for web embedding, with PNG fallback
- **Size**: Should work at 960px wide on desktop and scale down to mobile

## What NOT to include
- No screenshots of the tool
- No code snippets
- No detailed feature lists
- Keep it abstract/diagrammatic — this is a conceptual overview, not a technical schematic
