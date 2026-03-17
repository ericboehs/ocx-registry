---
name: reminders
description: Manage Apple Reminders using remindctl CLI. Use when user asks about reminders, todos, tasks, or says "/reminders". Handles listing, creating, completing, editing, and deleting reminders and reminder lists.
tools: Bash
---

# Apple Reminders (remindctl)

Manage Apple Reminders from the command line using `remindctl`.

## Prerequisites

`remindctl` must be installed. If any command fails with "command not found", tell the user to install it:

```bash
brew install steipete/tap/remindctl
```

After install, they may need to grant Reminders access: `remindctl authorize`

## Usage

- `/reminders` — Show today's reminders
- `/reminders list` — Show all reminder lists
- `/reminders add Buy milk` — Quick add to default list
- `/reminders add Buy milk --list Groceries --due tomorrow` — Add with options

Arguments after `/reminders` are passed directly to `remindctl`.

## Commands

Always use `--no-color --no-input` flags to ensure clean output without ANSI codes or interactive prompts.

### Show reminders

```bash
# Today's reminders (default)
remindctl show today --no-color --no-input

# Other filters
remindctl show tomorrow --no-color --no-input
remindctl show week --no-color --no-input
remindctl show overdue --no-color --no-input
remindctl show upcoming --no-color --no-input
remindctl show completed --no-color --no-input
remindctl show all --no-color --no-input

# Specific date
remindctl show 2026-03-01 --no-color --no-input

# Filter by list
remindctl show today --list "Work" --no-color --no-input
```

### List management

```bash
# Show all lists
remindctl list --no-color --no-input

# Show reminders in a specific list
remindctl list "Groceries" --no-color --no-input

# Create a new list
remindctl list "Groceries" --create --no-color --no-input

# Rename a list
remindctl list "Old Name" --rename "New Name" --no-color --no-input

# Delete a list
remindctl list "Old Name" --delete --force --no-color --no-input
```

### Add reminders

```bash
# Simple add
remindctl add "Buy milk" --no-color --no-input

# Add with list, due date, priority, and notes
remindctl add "Call dentist" --list "Personal" --due "tomorrow 9am" --priority high --notes "Reschedule appointment" --no-color --no-input
```

Due date accepts: `today`, `tomorrow`, `YYYY-MM-DD`, `YYYY-MM-DD HH:mm`, ISO 8601.
Priority accepts: `none`, `low`, `medium`, `high`.

### Edit reminders

Use the index or ID prefix from `show` output:

```bash
remindctl edit 1 --title "New title" --no-color --no-input
remindctl edit 1 --due tomorrow --no-color --no-input
remindctl edit 1 --priority high --notes "Updated notes" --no-color --no-input
remindctl edit 1 --clear-due --no-color --no-input
remindctl edit 1 --list "Work" --no-color --no-input  # Move to different list
```

### Complete reminders

```bash
remindctl complete 1 --no-color --no-input
remindctl complete 1 2 3 --no-color --no-input  # Multiple at once
```

### Delete reminders

```bash
remindctl delete 1 --force --no-color --no-input
remindctl delete 1 2 3 --force --no-color --no-input
```

## Behavior

1. If the user just says `/reminders` with no arguments, show today's reminders
2. If arguments are provided, pass them to `remindctl` as a subcommand
3. Always use `--no-color --no-input` for clean non-interactive output
4. Use `--force` on destructive operations (delete) to skip confirmation prompts
5. When showing reminders, format the output cleanly for the user — don't just dump raw CLI output
6. If a list doesn't exist when adding a reminder, suggest creating it first
7. When the user asks to "check my reminders" or "what's on my todo list", use `show today` or `show upcoming`
