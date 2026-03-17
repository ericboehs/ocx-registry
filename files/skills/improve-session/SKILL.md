---
name: improve-session
description: Analyze a Claude Code session and recommend improvements to reduce token waste, prevent linter loops, and automate repetitive workflows. Use when user says "improve session", "analyze session", "optimize session", or "/improve-session".
tools: Read, Write, Edit, Bash, Glob, Grep
---

# Session Improver

Analyze Claude Code session transcripts and generate actionable recommendations to reduce token waste, prevent linter loops, and automate repetitive workflows.

## Usage

- `/improve-session` — Analyze the most recent session
- `/improve-session <session-id>` — Analyze a specific past session
- `/improve-session --current` — Analyze the current live session

## Workflow

### Phase 1: Parse the session

Run the parser script to extract a structured summary:

```bash
ruby "${CLAUDE_SKILL_DIR}/scripts/parse-session.rb" <session-id-or-path>
```

If `CLAUDE_SKILL_DIR` is not set, fall back to the skill's location relative to this file. You can detect it by looking at the directory containing this SKILL.md.

The argument is either:
- A session UUID (found in `~/.claude/history.jsonl`)
- `--current` for the most recent session
- A direct path to a `.jsonl` file

The script outputs JSON with these sections:
- `linter_loops` — Linter smells that triggered multiple edit cycles
- `tool_failures` — Tools that failed and were retried
- `repeated_sequences` — Workflow patterns that repeated 3+ times
- `large_reads` — Files read 3+ times in the session
- `hook_failures` — Hooks that failed repeatedly
- `permission_events` — Tools that needed human approval

### Phase 2: Read context

For each finding, read relevant project files to understand what's already configured:
- The project's `CLAUDE.md` (if the session had a project path)
- The project's `.claude/settings.json` and `.claude/settings.local.json`
- The project's `.claude/hooks/` directory
- Any `.reek.yml`, `.rubocop.yml`, `eslint.config.*`, etc.
- The global `~/.claude/CLAUDE.md`
- The global `~/.claude/settings.json`

### Phase 3: Generate recommendations

Read the reference files for patterns and templates (relative to this SKILL.md):
- `references/analyzers.md` — What each finding type means
- `references/fix-templates.md` — Templates for each fix type
- `references/ruby-linter-patterns.md` — Ruby-specific patterns

For each finding, generate a specific recommendation:

1. **Describe the problem** — What happened, how many iterations, estimated token waste
2. **Propose a fix** — Concrete code/config to add
3. **Specify placement** — Where the fix should go:
   - `project CLAUDE.md` — Rules specific to this repo
   - `global CLAUDE.md` — Rules that apply everywhere
   - `project settings.json` — Hooks/permissions for this repo
   - `global settings.json` — Hooks/permissions everywhere
   - `hookify rule` — Behavioral guard
   - `skill` — Reusable workflow
4. **Rank by impact** — Most iterations/tokens saved first

### Phase 4: Present and apply

Present findings in this format:

```
## Session Analysis: <session-id>

**Project:** <path>
**Duration:** X min | **Turns:** N | **Edits:** N | **Tool calls:** N

---

### Finding 1: <title> (N iterations)
**Impact:** ~Nk estimated wasted tokens
**Pattern:** <what happened>

**Recommendation:** Add to <location>:
```<config/code>```

**Apply this fix?**
```

Use AskUserQuestion to offer choices for each finding:
- **Apply** — Write the fix to the specified location
- **Skip** — Move to next finding
- **Edit first** — Show the fix, let user modify, then apply

When applying:
- For CLAUDE.md additions: append to the appropriate section, or create a new section
- For settings.json hooks: read the current file, merge the new hook config
- For hookify rules: create the `.claude/hookify.<name>.local.md` file
- For skills: create the `.claude/skills/<name>/SKILL.md` file stub

## Important Notes

- Never remove existing configuration — only add to it
- If a fix already exists (e.g., the CLAUDE.md already has the rule), note it and skip
- For linter loop findings, check the project's linter config first — if it's already configured to ignore the smell, skip it
- Prefer CLAUDE.md rules over hooks for code style guidance (cheaper, no tool overhead)
- Prefer hooks over manual CLAUDE.md instructions for actions that should always run (formatting, linting)
