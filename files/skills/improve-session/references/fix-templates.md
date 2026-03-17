# Fix Templates

Ready-to-use templates for each type of fix the session improver can recommend.

## CLAUDE.md Rule (Linter Pattern)

Add to the project's `CLAUDE.md` under a `## Code Style` or `## Linting` section:

```markdown
## <LinterName>: <SmellName>

When writing Ruby code, avoid <smell description>. <Brief explanation of why>.

BAD:
```ruby
<code that triggers the smell>
```

GOOD:
```ruby
<refactored code that avoids it>
```
```

**Placement logic:**
- If the smell is from a project-specific linter config (custom thresholds) → project CLAUDE.md
- If it's a universal pattern Claude gets wrong everywhere → global `~/.claude/CLAUDE.md`
- If the project already has a Code Quality section in CLAUDE.md → append there

## PostToolUse Hook (Auto-format)

Add to `.claude/settings.json` under `hooks`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit",
        "hooks": [
          {
            "type": "command",
            "command": "<formatter-command> \"$CLAUDE_FILE_PATH\"",
            "timeout": 10000
          }
        ]
      }
    ]
  }
}
```

Common formatters:
- Ruby: `rubocop -A --fail-level=error "$CLAUDE_FILE_PATH"`
- JavaScript/TypeScript: `prettier --write "$CLAUDE_FILE_PATH"`
- Python: `ruff format "$CLAUDE_FILE_PATH"`

**Note:** The hook receives JSON on stdin with `tool_input.file_path`. Use a shell script if you need to parse it:

```bash
#!/bin/bash
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ "$FILE_PATH" =~ \\.rb$ ]] || exit 0
cd "$(git -C "$(dirname "$FILE_PATH")" rev-parse --show-toplevel)" || exit 0
bundle exec rubocop -A --fail-level=error "$FILE_PATH" 2>&1
```

## Permission Rule (Auto-approve)

Add to `.claude/settings.local.json` (user-local, not committed):

```json
{
  "permissions": {
    "allow": [
      "Bash(<command-pattern>:*)"
    ]
  }
}
```

Examples:
- `"Bash(bundle exec rake test:*)"` — allow all test runs
- `"Bash(rubocop:*)"` — allow rubocop
- `"Bash(git status:*)"` — allow git status
- `"Bash(bin/ci:*)"` — allow CI script

## Hookify Rule (Behavioral Guard)

Create `.claude/hookify.<rule-name>.local.md`:

```markdown
---
event: file_edit
pattern: "\\.rb$"
action: warn
---

## <Rule Title>

<Message shown to Claude when the pattern matches>

### Examples

BAD:
```ruby
<code pattern to avoid>
```

GOOD:
```ruby
<preferred pattern>
```
```

## Skill Stub

Create `.claude/skills/<name>/SKILL.md`:

```markdown
---
name: <skill-name>
description: <when to invoke this skill>
tools: Bash, Read, Edit
---

# <Skill Name>

<Instructions for Claude to follow when this skill is invoked>

## Steps

1. <step 1>
2. <step 2>
```

## CLAUDE.md Rule (Workflow Automation)

For repeated manual workflows, add an instruction:

```markdown
## After Editing Ruby Files

After editing any `.rb` file in `lib/`, always:
1. Run `bundle exec rubocop -A <file>` to auto-fix style issues
2. Run `bundle exec reek <file>` to check for code smells
3. Only run `bin/ci` after individual checks pass
```

## CLAUDE.md Rule (File Reading)

For files read too many times:

```markdown
## Key File Reference: <filename>

<Summary of the file's structure and key details so Claude doesn't need to re-read it>
- Main class: `<ClassName>`
- Key methods: `<method1>`, `<method2>`
- Config format: <brief description>
```
