---
name: setup-calendar
description: Install and configure the ical CLI for Apple Calendar management. Use when user asks to set up calendar, install ical, or says "/setup-calendar".
tools: Bash, Read, Write
---

# Setup Apple Calendar CLI

Guided installation of the `ical` CLI tool for managing Apple Calendar from the command line.

## Step 1: Check Prerequisites

```bash
which ical && ical version
```

If `ical` is already installed, tell the user their calendar CLI is ready and suggest `/calendar`.

## Step 2: Install ical

```bash
curl -fsSL https://ical.sidv.dev/install | bash
```

This installs the `ical` binary to `/usr/local/bin/ical`.

## Step 3: Grant Calendar Access

The first time `ical` runs, macOS will prompt for Calendar access. Run a test command to trigger the permission dialog:

```bash
ical calendars
```

If the user sees a permissions error, guide them to:
1. Open System Settings > Privacy & Security > Calendars
2. Enable access for the terminal app they're using (Terminal, iTerm2, Ghostty, etc.)
3. Re-run `ical calendars`

## Step 4: Verify

```bash
# List calendars
ical calendars

# Show today's events
ical today -o json
```

If both commands succeed, the setup is complete. Suggest the user try `/calendar`.

## Behavior

1. Run through steps sequentially, checking what's already done
2. Don't reinstall if `ical` is already present and working
3. If `ical` is installed but calendar access is denied, focus on the permissions step
4. After successful setup, suggest `/calendar` to start using it
