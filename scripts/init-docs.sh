#!/usr/bin/env bash
#
# init-docs.sh — Scaffold documentation/, context/, and .claude/ config files in a target project.
#
# Usage:
#   ./init-docs.sh [target-directory]
#
# If no target directory is specified, uses the current directory.
# Idempotent — will not overwrite existing files.

set -euo pipefail

# Resolve paths
TARGET_DIR="${1:-.}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$PLUGIN_ROOT/templates"

echo "Initializing Ultra Claude documentation structure in: $TARGET_DIR"

# ── Create documentation/ directory tree ──

DIRS=(
  "documentation/technology/architecture"
  "documentation/technology/standards"
  "documentation/technology/rfcs"
  "documentation/product/description"
  "documentation/product/requirements"
  "documentation/plans"
  "documentation/dependencies"
  "context"
  ".claude"
)

for dir in "${DIRS[@]}"; do
  if [ ! -d "$TARGET_DIR/$dir" ]; then
    mkdir -p "$TARGET_DIR/$dir"
    echo "  Created: $dir/"
  else
    echo "  Exists:  $dir/"
  fi
done

# ── Copy templates as placeholders (don't overwrite existing) ──

copy_template() {
  local template="$1"
  local dest="$2"

  if [ ! -f "$dest" ]; then
    if [ -f "$TEMPLATES_DIR/$template" ]; then
      cp "$TEMPLATES_DIR/$template" "$dest"
      echo "  Copied:  $template -> ${dest#$TARGET_DIR/}"
    fi
  else
    echo "  Exists:  ${dest#$TARGET_DIR/}"
  fi
}

copy_template "architecture.md" "$TARGET_DIR/documentation/technology/architecture/README.md"
copy_template "requirement.md" "$TARGET_DIR/documentation/product/requirements/README.md"
copy_template "context.md" "$TARGET_DIR/context/README.md"
copy_template "dependency.md" "$TARGET_DIR/documentation/dependencies/README.md"
copy_template "rfc.md" "$TARGET_DIR/documentation/technology/rfcs/README.md"
copy_template "plan.md" "$TARGET_DIR/documentation/plans/README.md"
copy_template "task.md" "$TARGET_DIR/documentation/plans/task-template.md"

# ── Generate documentation index ──

INDEX_FILE="$TARGET_DIR/documentation/README.md"
if [ ! -f "$INDEX_FILE" ]; then
  cat > "$INDEX_FILE" << 'EOF'
# Documentation Index

Navigable index of the project documentation tree.

## Technology

- [Architecture](technology/architecture/) — System design, components, data flow, tech stack
- [Standards](technology/standards/) — Coding conventions, patterns, quality bars, security rules
- [RFCs](technology/rfcs/) — Structured reviews for ambiguous/high-risk decisions

## Product

- [Description](product/description/) — Vision, discovery outputs, market research
- [Requirements](product/requirements/) — Formal requirements (FR-xxx, NFR-xxx)

## Plans

- [Plans](plans/) — One directory per initiative, each with README.md (plan + task list), research/, and shared/

## Dependencies

- [Dependencies](dependencies/) — Blocking questions, external dependencies
EOF
  echo "  Created: documentation/README.md (index)"
else
  echo "  Exists:  documentation/README.md"
fi

# ── Create .claude/ config file placeholders ──

create_config() {
  local file="$1"
  local content="$2"

  if [ ! -f "$TARGET_DIR/.claude/$file" ]; then
    echo "$content" > "$TARGET_DIR/.claude/$file"
    echo "  Created: .claude/$file"
  else
    echo "  Exists:  .claude/$file"
  fi
}

create_config "docs-format" "markdown"

create_config "app-context-for-research.md" "# App Context for Research

Provide domain-specific context that helps Researcher agents understand this project.

## Project Overview

{Describe your project in 2-3 sentences}

## Domain

{What domain does this project operate in?}

## Key Technologies

{List the main technologies, frameworks, and services used}

## External Integrations

{List external systems this project integrates with}"

create_config "system-test.md" "# System Test Instructions

Instructions for the System Tester agent on how to test this project.

## Environment Setup

{How to set up the test environment}

## Running Tests

{Commands to run the test suite}

## Test Data

{Where test data lives or how to generate it}

## Known Limitations

{Any testing limitations or gotchas}"

create_config "environments-info" "# Environment Information

How to access dev/staging/prod environments.

## Development

{Local development setup}

## Staging

{Staging environment details}

## Production

{Production environment details — read-only access only}"

echo ""
echo "Done. Documentation structure initialized."
echo ""
echo "Next steps:"
echo "  1. Edit .claude/app-context-for-research.md with your project details"
echo "  2. Edit .claude/system-test.md with testing instructions"
echo "  3. Add architecture docs to documentation/technology/architecture/"
echo "  4. Add product requirements to documentation/product/requirements/"
