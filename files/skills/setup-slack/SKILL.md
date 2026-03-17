---
name: setup-slack
description: Install and configure slk CLI (Slack Gem) for Slack access. Use when user asks to set up Slack CLI, install slk, or says "/setup-slack".
tools: Bash
---

# Setup Slack CLI (slk)

Guided installation and configuration of `slk` (Slack Gem) for Slack access from the command line.

## Step 1: Check Prerequisites

```bash
which slk && slk --version
```

If installed, check for configured workspaces:

```bash
slk workspaces
```

If `slk` is installed and workspaces are configured, tell the user their Slack CLI is already set up and suggest `/slack`.

## Step 2: Install slk

slk is a Ruby gem. Install via mise (preferred) or gem:

```bash
# Via mise (preferred — manages Ruby version automatically)
mise use ruby@latest
gem install slk

# Or directly if Ruby is available
gem install slk
```

Verify installation:

```bash
slk --version
```

## Step 3: Initial Configuration

Run the interactive setup:

```bash
slk config setup
```

This will prompt for:
- Workspace name (e.g., "oddball", "dsva")
- Slack tokens (user token for full access, or bot token for limited access)

User tokens (xoxc/xoxs) provide full access including search. Bot tokens have limited capabilities.

## Step 4: Add Workspaces

Add additional workspaces as needed:

```bash
slk workspaces add
```

Common workspaces:
- `oddball` — Oddball team Slack
- `dsva` — VA Digital Service Slack
- `boehs` — Personal workspace

## Step 5: Build Cache

Build the user/channel cache for faster lookups:

```bash
slk cache build
slk cache build --all  # For all workspaces
```

## Step 6: Set Up Presets (Optional)

Create status presets for quick switching:

```bash
slk preset add
```

Common presets: `meeting`, `focus`, `lunch`, `ooo`

## Step 7: Verify

```bash
# Check workspaces
slk workspaces

# Check unread
slk unread

# Test reading a channel
slk messages #general -n 5
```

## Behavior

1. Run through steps sequentially, checking what's already done
2. Don't reinstall if already present
3. If slk is installed but no workspaces configured, skip to Step 3
4. After setup, suggest running `/slack` to check unread messages
