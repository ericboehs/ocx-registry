---
name: check-email
description: Check and manage email using himalaya CLI. Use when user asks to check email, read email, list unread, archive messages, or says "/check-email".
tools: Bash
---

# CLI Email (himalaya)

Manage email from the command line using `himalaya` with local Maildir sync via mbsync.

## Accounts

| Name | Provider | Usage |
|------|----------|-------|
| `personal` | Fastmail (default) | Personal email |
| `oddball` | Google Workspace | Work/VA email |

The default account is `personal`. Use `-a oddball` for work email.

## Prerequisites

`himalaya` must be installed and configured. If any command fails with "command not found", suggest running `/setup-email`.

Email is synced to local Maildir (`~/Mail/`) via mbsync + IMAP IDLE (near-instant). Himalaya reads from local Maildir — no network needed for reading.

## Commands

### List inbox (unread envelopes)

```bash
# Personal inbox (default)
himalaya envelope list

# Work inbox
himalaya envelope list -a oddball

# List a specific folder
himalaya envelope list -f Sent
himalaya envelope list -f "[Gmail]/Sent Mail" -a oddball
```

### Read a message

```bash
# Read by ID (from envelope list output)
himalaya message read <id>

# Read from work account
himalaya message read <id> -a oddball
```

### Mark as read

```bash
himalaya flag add <id> seen
himalaya flag add <id> seen -a oddball
```

### Archive messages

Use the `mail-archive` script (not raw himalaya move) — it handles UID stripping for mbsync compatibility:

```bash
# Archive from personal (moves to Archive folder)
mail-archive <id> [id...]

# Archive from work/Gmail (moves to [Gmail]/All Mail)
mail-archive -a oddball <id> [id...]
```

### Sync email manually

```bash
# Sync all accounts
mbsync -a

# Sync a single account
mbsync personal
mbsync work

# Full pipeline (sync + text extraction + search index update)
mail-sync -a
```

### Search email

Use `qmd` for full-text search across all indexed email:

```bash
# Fast keyword search (BM25)
qmd search "quarterly report" -c email

# Semantic search with reranking (slower, more relevant results)
qmd query "emails about the server migration timeline" -c email -n 5

# Search across everything — email, wiki, notes
qmd query "meeting with Alex about deployment"
```

### Send email

```bash
# Compose in editor
himalaya message write

# Quick send (pipe content)
echo "Message body" | himalaya message write --to "recipient@example.com" --subject "Subject"
```

## Behavior

1. When the user says "check email" or "check my email", list both inboxes (personal first, then work) and summarize unread
2. Present unread messages in a clean, readable format — show sender, subject, and date
3. When reading messages, extract the key content and summarize if lengthy
4. Offer follow-up actions: archive, mark as read, reply
5. Use `mail-archive` for archiving (never use raw `himalaya message move` — it causes mbsync UID conflicts)
6. When searching, prefer `qmd query` for natural language queries and `qmd search` for specific keywords
7. If himalaya is not installed, suggest running `/setup-email` to set up the full email stack
