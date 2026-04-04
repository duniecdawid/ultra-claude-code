---
name: vscode-launch
description: Generate VS Code launch.json debug configurations for Node.js/TypeScript projects. Use when setting up debugging, the user says "debug in vscode", "launch config", "vscode debugging", "F5 config", wants to run services with breakpoints, or when a project has no .vscode/launch.json. Also use when the user has a working setup and wants to add new services or fix broken debug configs. Proactively suggest when you notice a project lacks debug configuration.
---

# VS Code Launch Config Generator

Generate `.vscode/launch.json` with proper debug configurations for Node.js and TypeScript projects. The goal is debugger-attached runs where breakpoints work, output is visible, and multi-service projects can launch together.

## When to Use

- Project has no `.vscode/launch.json`
- User wants to debug with VS Code (breakpoints, step-through)
- Setting up a new service in a monorepo
- Existing launch config is broken or incomplete

## Process

### Step 1: Scan the Project

Understand what needs to run:

1. **Find package.json files** — root and any workspace packages
2. **Identify services** — look for `dev`, `start`, `serve` scripts in each package.json
3. **Detect TypeScript runtime** — check for `tsx`, `ts-node`, or `ts-node-dev` in dependencies
4. **Check for monorepo** — `workspaces` field in root package.json, or `packages/` directory
5. **Find entry points** — what each `dev`/`start` script actually runs (e.g., `tsx watch server.ts`, `next dev`, `node dist/index.js`)
6. **Check for existing configs** — read `.vscode/launch.json` if it exists

### Step 2: Classify Each Service

Each service falls into one of these categories:

| Type | Signals | Runtime |
|------|---------|---------|
| **Long-running server** | `server.ts`, `next dev`, `express`, `fastify`, web frameworks | tsx or node |
| **Background daemon** | `start` command, CLI with `start` subcommand, watcher processes | tsx or node |
| **One-shot CLI** | CLI tools, scripts, migrations, login flows | tsx or node |
| **Next.js app** | `next dev` in scripts | next CLI (special handling) |

### Step 3: Generate Configurations

Build the launch.json following these rules:

#### Base Config for Every Service

Every configuration MUST include these fields. They are the result of hard-won debugging experience — each one solves a specific problem:

```json
{
  "type": "node",
  "request": "launch",
  "sourceMaps": true,
  "skipFiles": ["<node_internals>/**", "**/node_modules/**"]
}
```

- `sourceMaps: true` — without this, breakpoints in TypeScript files won't hit
- `skipFiles` — without this, the debugger constantly steps into Node internals and node_modules, making step-through debugging unusable

#### Output Routing

There are two options for where process output appears. Choose based on the service type:

**`internalConsole`** — for long-running servers and daemons. Output goes to the Debug Console panel. The debugger can show output from multiple sessions (switch via dropdown). Requires `outputCapture: "std"` or you get no output at all.

```json
{
  "console": "internalConsole",
  "outputCapture": "std"
}
```

**`integratedTerminal`** — for interactive/one-shot commands that need stdin (login flows, prompts, REPL). Output goes to a Terminal tab.

```json
{
  "console": "integratedTerminal"
}
```

The reason `outputCapture: "std"` is needed with `internalConsole`: VS Code's Debug Console only shows `console.log` by default. Most servers (pino, winston, raw stdout) write to stdout/stderr directly. Without `outputCapture: "std"`, the Debug Console is empty and the user thinks nothing is running.

Do NOT use `outputCapture` with `integratedTerminal` — the terminal captures output natively.

#### TypeScript Projects (tsx)

When the project uses `tsx` (check `devDependencies` or `dependencies`):

```json
{
  "runtimeExecutable": "${workspaceFolder}/node_modules/.bin/tsx",
  "args": ["watch", "server.ts"]
}
```

- Use the local tsx binary, not a global one — ensures version consistency
- `watch` mode for dev servers (auto-reload on file changes)
- No `watch` for one-shot commands

When the project uses `ts-node`:

```json
{
  "runtimeExecutable": "${workspaceFolder}/node_modules/.bin/ts-node",
  "args": ["src/index.ts"]
}
```

#### Plain Node.js Projects

```json
{
  "runtimeExecutable": "node",
  "args": ["dist/index.js"]
}
```

Or if using `program` instead of `runtimeExecutable`:

```json
{
  "program": "${workspaceFolder}/dist/index.js"
}
```

#### Next.js Projects

Next.js needs `NODE_OPTIONS` for the debugger to attach:

```json
{
  "name": "Next.js Dev",
  "type": "node",
  "request": "launch",
  "runtimeExecutable": "${workspaceFolder}/node_modules/.bin/next",
  "args": ["dev"],
  "cwd": "${workspaceFolder}",
  "console": "internalConsole",
  "outputCapture": "std",
  "sourceMaps": true,
  "skipFiles": ["<node_internals>/**", "**/node_modules/**"],
  "env": { "NODE_OPTIONS": "--inspect" }
}
```

If the project uses a custom server (e.g., `tsx watch server.ts` that calls `next()`), use the tsx pattern instead — the custom server entry point IS the debug target.

#### Monorepo / Multi-Service

When a project has multiple services, create:

1. **Individual configs** for each service
2. **A compound config** that launches them together

```json
{
  "compounds": [
    {
      "name": "All Services",
      "configurations": ["Web App", "Worker", "Agent"],
      "stopAll": true
    }
  ]
}
```

`stopAll: true` is important — when the user hits Stop, ALL services stop. Without it, orphan processes accumulate.

Set `cwd` correctly for each service in a monorepo:

```json
{
  "cwd": "${workspaceFolder}/packages/web"
}
```

#### Environment Variables

Add `env` when the service needs specific variables:

```json
{
  "env": {
    "NODE_ENV": "development",
    "PORT": "3000"
  }
}
```

Check `.env.local`, `.env.development`, or `dotenv` usage to know what's needed. Most frameworks (Next.js, Vite) auto-load `.env*` files, so you usually only need `NODE_ENV`.

#### User Inputs

For values that change between runs (URLs, ports, flags), use VS Code input variables:

```json
{
  "inputs": [
    {
      "id": "serverUrl",
      "type": "promptString",
      "description": "Server URL",
      "default": "https://localhost:3000"
    }
  ]
}
```

Reference in args: `"${input:serverUrl}"`

Use sparingly — only for values that genuinely vary. Don't make the user confirm things that are always the same.

### Step 4: Write the File

1. Create `.vscode/` directory if it doesn't exist
2. Write `launch.json`
3. If there's an existing launch.json, read it first and merge — don't overwrite user's custom configs

### Step 5: Verify

After writing, confirm it's valid:
- All referenced paths exist
- `runtimeExecutable` binary exists in node_modules
- `cwd` directories exist
- No duplicate configuration names

## Ultra Claude Integration

When the project uses Ultra Claude (check for `.claude/ultra/` directory):

1. **Document the setup** — after generating launch.json, update `documentation/technology/testing/environments.md` with how to run services via VS Code debugger. Use `/uc:docs-manager` to route correctly.
2. **Update CLAUDE.md** — add a "Dev Environment" section noting how Claude should start/stop services (via `scripts/dev.sh`) and how VS Code debugging works (via launch.json). This prevents Claude from starting duplicate processes when the user is already debugging in VS Code.
3. **Process management script** — if the project has multiple services, generate a `scripts/dev.sh` that manages PIDs and kills by process pattern. This script is for Claude/CLI use. VS Code manages its own processes through the debugger. The script should:
   - Track PIDs in a shared location (e.g., `~/.claude/ultra/dashboard/`)
   - Kill by process pattern (not just PID) to catch orphans from any source
   - Have `start`, `stop`, `restart`, `status` commands
   - Use `nohup` for background mode (Claude), foreground `exec` for interactive use

## Anti-Patterns

Things that don't work and why — learned from experience:

| Don't | Why |
|-------|-----|
| Use `preLaunchTask` for killing processes | Tasks hang waiting to "complete", blocking the launch indefinitely |
| Use `bash -c "stop; exec tsx"` as runtimeExecutable | VS Code injects NODE_OPTIONS into bash, which doesn't understand them |
| Background processes with `&` in shell tasks | Output disappears — the terminal shows nothing |
| `isBackground` tasks without `problemMatcher.background` | VS Code waits forever for the task to "finish" |
| `console: "internalConsole"` without `outputCapture: "std"` | Debug Console stays completely empty |
| Global tsx/ts-node (`runtimeExecutable: "tsx"`) | Version mismatch, may not be installed on all machines |

## Examples

### Simple Express + TypeScript

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Dev Server",
      "type": "node",
      "request": "launch",
      "runtimeExecutable": "${workspaceFolder}/node_modules/.bin/tsx",
      "args": ["watch", "src/server.ts"],
      "cwd": "${workspaceFolder}",
      "env": { "NODE_ENV": "development" },
      "console": "internalConsole",
      "outputCapture": "std",
      "sourceMaps": true,
      "skipFiles": ["<node_internals>/**", "**/node_modules/**"]
    }
  ]
}
```

### Monorepo with Web + Worker + CLI

```json
{
  "version": "0.2.0",
  "compounds": [
    {
      "name": "All Services",
      "configurations": ["Web", "Worker"],
      "stopAll": true
    }
  ],
  "configurations": [
    {
      "name": "Web",
      "type": "node",
      "request": "launch",
      "runtimeExecutable": "${workspaceFolder}/node_modules/.bin/tsx",
      "args": ["watch", "server.ts"],
      "cwd": "${workspaceFolder}/packages/web",
      "env": { "NODE_ENV": "development" },
      "console": "internalConsole",
      "outputCapture": "std",
      "sourceMaps": true,
      "skipFiles": ["<node_internals>/**", "**/node_modules/**"]
    },
    {
      "name": "Worker",
      "type": "node",
      "request": "launch",
      "runtimeExecutable": "${workspaceFolder}/node_modules/.bin/tsx",
      "args": ["src/worker.ts"],
      "cwd": "${workspaceFolder}/packages/worker",
      "console": "internalConsole",
      "outputCapture": "std",
      "sourceMaps": true,
      "skipFiles": ["<node_internals>/**", "**/node_modules/**"]
    },
    {
      "name": "CLI: Migrate",
      "type": "node",
      "request": "launch",
      "runtimeExecutable": "${workspaceFolder}/node_modules/.bin/tsx",
      "args": ["src/cli.ts", "migrate"],
      "cwd": "${workspaceFolder}/packages/shared",
      "console": "integratedTerminal",
      "sourceMaps": true,
      "skipFiles": ["<node_internals>/**", "**/node_modules/**"]
    }
  ]
}
```
