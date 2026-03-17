---
name: setup-email
description: Install and configure CLI email stack (mbsync, himalaya, neomutt, goimapnotify, qmd). Use when user asks to set up email, install himalaya, configure mbsync, or says "/setup-email".
tools: Bash, Read, Write
---

# Setup CLI Email Stack

Guided installation and configuration of CLI email on macOS. Based on the reference guide at `references/blog-post.md` (read it for full config templates and details).

## Overview

The stack:
- **mbsync** (isync) — two-way IMAP sync to local Maildir
- **himalaya** — fast CLI for listing, reading, flagging
- **neomutt** — full TUI with sidebar, vim keys, colors
- **goimapnotify** — IMAP IDLE for push notifications
- **qmd** — full-text search across all indexed email

## Step 1: Check Prerequisites

Check what's already installed:

```bash
# Check each tool
which himalaya && himalaya --version
which mbsync && mbsync --version
which neomutt && neomutt --version
which w3m
which goimapnotify || ls ~/go/bin/goimapnotify
which qmd
which mail-archive
which mail-sync
which maildir-to-text
```

Report what's installed and what's missing. If everything is installed, tell the user their email stack is already set up and suggest `/check-email`.

## Step 2: Install Tools

```bash
brew install isync himalaya neomutt w3m
go install github.com/chmouel/goimapnotify@latest
```

Note: `goimapnotify` requires Go. If `go` is not installed: `brew install go`.

## Step 3: Store App Passwords

Guide the user to create app-specific passwords and store them in the macOS Keychain.

**Fastmail:** Settings > Privacy & Security > App Passwords
**Google:** https://myaccount.google.com/apppasswords

```bash
# Store in Keychain (user provides the actual password)
security add-generic-password -a '<email>' -s '<service-name>' \
  -w '<app-password>' ~/Library/Keychains/login.keychain-db
```

The service names will be used in all config files for password retrieval:
```bash
security find-generic-password -a '<email>' -s '<service-name>' -w
```

## Step 4: Configure mbsync

Create `~/.mbsyncrc` — see `references/blog-post.md` for the full template.

Key settings per account:
- `AuthMechs LOGIN` — required on macOS (avoids SASL errors)
- `SubFolders Verbatim` — preserves folder names
- `Create Both` + `Expunge Both` — full two-way sync
- `CopyArrivalDate yes` — preserves email dates
- Gmail: exclude `Important` and `Starred` (virtual labels)

```bash
mkdir -p ~/Mail/personal ~/Mail/work
mbsync -a
```

## Step 5: Configure himalaya

Create `~/.config/himalaya/config.toml` — see `references/blog-post.md` for the full template.

Himalaya reads from local Maildir (fast, offline) and sends via SMTP.

## Step 6: Configure neomutt

Create `~/.config/neomutt/neomuttrc` — see `references/blog-post.md` for the full template.

Also create `~/.mailcap`:
```
text/html; w3m -I %{charset} -T text/html -dump; copiousoutput;
```

## Step 7: Install Scripts

Install `mail-archive`, `mail-sync`, and `maildir-to-text` to `~/.local/bin/`:

```bash
mkdir -p ~/.local/bin

# mail-archive is bundled with the plugin — copy it
cp "$(dirname "$(dirname "$(dirname "$0")")")/scripts/mail-archive" ~/.local/bin/mail-archive
chmod +x ~/.local/bin/mail-archive
```

For `mail-sync` and `maildir-to-text`, see `references/blog-post.md` for the scripts.

Ensure `~/.local/bin` is in PATH.

## Step 8: Set Up IMAP IDLE (goimapnotify)

Create one config per account in `~/.config/goimapnotify/`:

- `personal.json` — Fastmail IMAP IDLE config
- `work.json` — Gmail IMAP IDLE config

See `references/blog-post.md` for templates.

Test:
```bash
~/go/bin/goimapnotify -conf ~/.config/goimapnotify/personal.json
~/go/bin/goimapnotify -conf ~/.config/goimapnotify/work.json
```

## Step 9: Create launchd Plists

Three plists in `~/Library/LaunchAgents/`:
1. `com.example.goimapnotify-personal.plist` — IDLE watcher for personal
2. `com.example.goimapnotify-work.plist` — IDLE watcher for work
3. `com.example.mbsync.plist` — 15-minute fallback sync timer

See `references/blog-post.md` for templates.

```bash
launchctl load ~/Library/LaunchAgents/com.example.goimapnotify-personal.plist
launchctl load ~/Library/LaunchAgents/com.example.goimapnotify-work.plist
launchctl load ~/Library/LaunchAgents/com.example.mbsync.plist
```

## Step 10: Set Up Email Search Indexing

Register the email text files as a qmd collection:

```bash
qmd collection add ~/Mail/.index --name email --mask '**/*.txt'
qmd update -c email
```

The `mail-sync` wrapper runs `maildir-to-text` and `qmd update -c email` automatically on every sync.

## Behavior

1. Run through steps sequentially, checking what's already done at each step
2. Don't reinstall tools that are already present
3. Don't overwrite existing config files without asking
4. Ask the user for their email addresses and service names before creating configs
5. Customize config templates with the user's actual details
6. Test each component after configuration before moving to the next step
