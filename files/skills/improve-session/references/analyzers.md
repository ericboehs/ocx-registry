# Analyzer Reference

How to interpret each finding type from the parser output.

## linter_loops

A linter loop occurs when Claude edits a file, a linter hook rejects it, and Claude has to re-edit — often multiple times for the same smell.

**Fields:**
- `linter` — Which linter (reek, rubocop, eslint, etc.)
- `smell` — The specific rule/smell that fired (e.g., `FeatureEnvy`, `Metrics/MethodLength`)
- `iterations` — How many times this smell fired in the session
- `files` — Which files triggered it
- `error_samples` — Example error messages

**What to recommend:**
- A CLAUDE.md rule teaching Claude how to avoid this specific smell
- Include a BAD/GOOD code example so Claude learns the pattern
- If the smell fires on >3 different files, it's a systemic pattern — put the rule in project or global CLAUDE.md
- If the smell is project-specific (custom thresholds), put it in project CLAUDE.md

## tool_failures

A tool failure occurs when Claude calls a tool, it errors, and Claude retries with similar input.

**Fields:**
- `tool` — Which tool failed (usually Bash)
- `input_summary` — Simplified version of the command/input
- `retry_count` — Total attempts
- `error_count` — How many were errors
- `error_sample` — Example error output

**What to recommend:**
- If it's a CI/test command failing repeatedly: suggest running individual linters/tests first before the full suite
- If it's a bash command with a typo: suggest a CLAUDE.md note about correct syntax
- If it's a permission issue: suggest a settings.local.json permission rule

## repeated_sequences

A repeated sequence is a workflow pattern (3+ distinct tool calls) that occurs 3+ times.

**Fields:**
- `sequence` — The tool call pattern, e.g., `["Read(.rb)", "Edit(.rb)", "Bash(bundle exec)"]`
- `count` — How many times it repeated
- `length` — Number of steps in the sequence

**What to recommend:**
- If it's Read→Edit→Lint: this is normal development flow, skip unless there's something to automate
- If it's Edit→Fail→Read→Edit: suggest a CLAUDE.md rule to read before editing
- If it includes manual formatting: suggest a PostToolUse hook for auto-format

## large_reads

Files that were read 3+ times in a single session, suggesting Claude keeps re-reading instead of retaining context.

**Fields:**
- `file` — File path
- `times_read` — Read count

**What to recommend:**
- If >5 reads: this is a token waste pattern. Suggest Claude use `/compact` less aggressively, or that the file is large and should use offset/limit
- If it's a test file read repeatedly while editing source: normal, skip
- If it's a config file: suggest adding key details to CLAUDE.md so Claude doesn't need to keep re-reading

## hook_failures

Hooks that failed repeatedly, suggesting either misconfiguration or Claude not adapting to the hook's expectations.

**Fields:**
- `hook_name` — Hook identifier (e.g., `PostToolUse:Edit`)
- `count` — Number of failures
- `error_samples` — Example errors

**What to recommend:**
- If the hook runs a linter and fails: combine with linter_loops analysis
- If the hook is a formatter: check if it's running correctly
- If failures are from a PreToolUse guard: check if it's too strict

## permission_events

Tools that required human approval, adding friction.

**Fields:**
- `tool` — Tool name
- `input_pattern` — Simplified input
- `count` — How many times approval was needed

**What to recommend:**
- If it's a safe, repeatable command: add to `settings.local.json` allow list
- If it's a Bash command: add the specific pattern to allowed bash commands
- Format: `"Bash(<command-pattern>:*)"` in the `allow` array
