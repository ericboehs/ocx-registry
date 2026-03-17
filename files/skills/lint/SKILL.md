---
name: lint
description: Run all configured linters across the full project, including whole-project-only linters. Use when user says "/lint", "lint project", or "run linters".
tools: Bash, Read
---

# Lint

Run configured linters across the full project. Includes whole-project-only linters (brakeman, clippy) that don't run in the PostToolUse hook.

## Usage

- `/lint` — Run all enabled linters on the full project
- `/lint ruby` — Run only Ruby linters
- `/lint reek` — Run only the reek linter
- `/lint --fix` — Run autofix on all files first, then lint

Arguments after `/lint` are parsed as:
- A language name (ruby, javascript, python, go, rust, markdown, html, shell) → filter to that language
- A linter name (rubocop, reek, eslint, ruff, etc.) → filter to that specific linter
- `--fix` → run autofix commands before linting

## Step 1: Load Config

```bash
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PROJECT_HASH=$(echo "$PROJECT_DIR" | tr '/' '-' | sed 's/^-//')
CONFIG_FILE="$HOME/.claude/code-lint/$PROJECT_HASH/config.json"
```

If no config exists, tell the user to run `/setup-lint` first.

Read and parse the config JSON.

## Step 2: Determine Scope

Parse arguments to determine what to run:
- No args → all enabled languages, all enabled linters
- Language arg → only that language's linters
- Linter arg → only that specific linter
- `--fix` → enable autofix mode

## Step 3: Run Linters

For each enabled linter in scope:

### Single-file linters

Find all matching files (using `file_patterns`), excluding paths that match `exclude_patterns`. Run the linter on all matching files at once (most linters accept multiple files or directories).

```bash
cd "$PROJECT_DIR"

# If --fix mode, run autofix first
bundle exec rubocop -A --fail-level=error .

# Then run the lint check
bundle exec rubocop .
```

### Whole-project-only linters

Run these against the project root:

```bash
cd "$PROJECT_DIR"
bundle exec brakeman -q
cargo clippy -- -D warnings
```

### Collect results

For each linter, capture:
- Exit code (0 = pass, non-zero = issues found)
- stdout/stderr output
- File count checked
- Issue count (parse from output where possible)

## Step 4: Present Results

Group results by language and linter:

```
## Lint Results

**Project:** /path/to/project

### Ruby (42 files)

**rubocop** — 3 issues
  app/models/user.rb:15:5 Style/GuardClause: Use guard clause
  app/models/user.rb:28:3 Metrics/MethodLength: Method too long (15/10)
  app/services/auth.rb:8:1 Layout/EmptyLines: Extra blank line

**reek** — 1 issue
  app/models/user.rb:10 FeatureEnvy: process refers to config more than self

**brakeman** — No issues

### Shell (5 files)

**shellcheck** — No issues

---

**Summary:** 4 issues found (3 rubocop, 1 reek)
```

## Step 5: Offer Fixes

If issues were found and autofix is available:

1. Ask if the user wants to auto-fix fixable issues
2. Run autofix commands
3. Re-run lint to show remaining (non-auto-fixable) issues
4. For remaining issues, offer to fix them using the reference docs for guidance

Read the relevant reference docs for fix patterns:
- Ruby: `${CLAUDE_PLUGIN_ROOT}/references/ruby-patterns.md`
- JS/TS: `${CLAUDE_PLUGIN_ROOT}/references/js-ts-patterns.md`
- Python: `${CLAUDE_PLUGIN_ROOT}/references/python-patterns.md`
- Go: `${CLAUDE_PLUGIN_ROOT}/references/go-patterns.md`
- Rust: `${CLAUDE_PLUGIN_ROOT}/references/rust-patterns.md`
- Markdown: `${CLAUDE_PLUGIN_ROOT}/references/markdown-patterns.md`
- HTML: `${CLAUDE_PLUGIN_ROOT}/references/html-patterns.md`
- Shell: `${CLAUDE_PLUGIN_ROOT}/references/shell-patterns.md`

If `CLAUDE_PLUGIN_ROOT` is not set, find references relative to this SKILL.md (two directories up: `../../references/`).

## Behavior

1. Always cd to project root before running linters
2. Respect timeout settings from config
3. If a linter times out, report it and continue with others
4. Present results in a readable, grouped format
5. Count total issues and offer summary
6. If no issues found, say so concisely
7. If no config exists, suggest `/setup-lint`
