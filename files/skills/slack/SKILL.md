---
name: slack
description: Manage Slack using slk CLI — read messages, search, check unread, set status/DND, and browse activity. Use when user asks about Slack, wants to check messages, set status, or says "/slack".
tools: Bash
---

# Slack (slk CLI)

Interact with Slack from the command line using `slk` (Slack Gem).

## Prerequisites

`slk` must be installed and authenticated. If any command fails with "command not found", suggest running `/setup-slack`.

## Usage

- `/slack` — Show unread messages across all workspaces
- `/slack unread` — Same as above
- `/slack messages #channel` — Read recent channel messages
- `/slack search "query"` — Search messages

Arguments after `/slack` map directly to `slk` subcommands.

## Commands

### Unread messages

```bash
# Show unread across all workspaces (default action)
slk unread

# Unread for a specific workspace
slk unread -w oddball

# Include muted channels
slk unread --muted

# Clear all unread
slk unread clear

# Clear unread for a specific channel
slk unread clear #channel
```

### Read channel/DM messages

```bash
# Channel messages
slk messages #general
slk messages #eert-teammates-internal

# DM messages
slk messages @alexteal

# From a Slack URL (message + thread context)
slk messages https://oddball-io.slack.com/archives/C123/p456

# Limit number of messages
slk messages #general -n 20

# Messages since a duration or date
slk messages #general --since 1d
slk messages #general --since 7d
slk messages #general --since 2026-02-28

# Include thread replies inline
slk messages #general --threads

# Specific workspace
slk messages #general -w oddball
```

### Read threads

Use the `messages` command with a Slack message URL — it returns the message and its thread:

```bash
slk messages https://oddball-io.slack.com/archives/C123ABC/p1234567890
```

### Search messages

Requires user token (xoxc/xoxs), not bot tokens.

```bash
# Basic search
slk search "deploy"

# Filter by channel
slk search "deploy" --in #platform-sre-team

# Filter by user
slk search "vtk" --from @alexteal

# Filter by date
slk search "outage" --after 2026-02-01 --before 2026-03-01
slk search "standup" --on 2026-02-28

# Combine filters
slk search "PR review" --in #eert-teammates-internal --from @tomwarren

# More results
slk search "deploy" -n 50

# Specific workspace
slk search "deploy" -w oddball
```

### Activity feed

```bash
# Recent activity (reactions, mentions, threads)
slk activity

# Include message content
slk activity -m

# Filter by type
slk activity --mentions
slk activity --reactions
slk activity --threads

# Limit results
slk activity -n 10
```

### Status

```bash
# Show current status (all workspaces)
slk status

# Set status with emoji
slk status "Working" :laptop:

# Set status with duration
slk status "In a meeting" :calendar: 1h

# Set status with presence and DND
slk status "Focus time" :headphones: 2h -p away -d 2h

# Clear status
slk status clear

# Set across all workspaces
slk status "OOO" :palm_tree: --all
```

### Presets

```bash
# List available presets
slk preset list

# Apply a preset
slk preset meeting
slk preset focus
slk preset lunch

# Apply to all workspaces
slk preset meeting --all
```

### Do Not Disturb

```bash
# Show DND status (all workspaces)
slk dnd

# Enable for a duration
slk dnd 1h
slk dnd 30m
slk dnd 1h30m

# Disable
slk dnd off

# Set across all workspaces
slk dnd 1h --all
```

### Emoji search

```bash
# Search emoji by name
slk emoji search "thumbs"
slk emoji search "party"
```

## JSON Output

Use `--json` when you need structured data for follow-up processing:

```bash
slk unread --json
slk messages #general --json
slk search "deploy" --json
slk activity --json
```

## Workspaces

slk supports multiple workspaces. Use `-w <name>` to target a specific workspace, or `--all` for commands that support it. Without `-w`, slk uses the primary workspace.

```bash
# List configured workspaces
slk workspaces
```

## Behavior

1. When the user says "/slack" with no arguments, show unread messages
2. Present messages in a clean, readable format — show sender, timestamp, and content
3. When reading long channels, use `--since` to limit to recent messages rather than fetching everything
4. For thread context, pass the Slack URL directly to `slk messages`
5. Use `--json` when you need to process output programmatically or extract specific data
6. Channel names use `#channel` format (not weechat `%channel` format)
7. Weechat logs (`~/.local/share/weechat/logs/`) and `qmd` remain useful for historical/indexed search — prefer `slk` for live data
8. When summarizing unread, group by workspace and highlight channels with the most activity
9. If a command fails with an auth error, suggest `slk config setup` or `/setup-slack`
