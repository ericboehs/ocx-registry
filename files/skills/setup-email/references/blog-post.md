# CLI Email on macOS: Setup Reference

Condensed reference from [boehs.com/blog/2026/03/01/cli-email-macos](https://boehs.com/blog/2026/03/01/cli-email-macos).

## Stack

| Tool | Role |
|------|------|
| **mbsync** (isync) | Two-way IMAP sync to local Maildir |
| **himalaya** | Fast CLI for listing, reading, flagging |
| **neomutt** | Full TUI with sidebar, vim keys, colors |
| **goimapnotify** | IMAP IDLE → triggers sync on new mail |
| **qmd** | Full-text search across all indexed email |

## Install

```bash
brew install isync himalaya neomutt w3m
go install github.com/chmouel/goimapnotify@latest
```

## App Passwords in Keychain

```bash
# Store
security add-generic-password -a '<email>' -s '<service-name>' \
  -w '<app-password>' ~/Library/Keychains/login.keychain-db

# Verify
security find-generic-password -a '<email>' -s '<service-name>' -w
```

Fastmail: Settings > Privacy & Security > App Passwords
Google: https://myaccount.google.com/apppasswords

## mbsync Config (`~/.mbsyncrc`)

```
# =============================================================================
# Account: <name>
# =============================================================================

IMAPAccount <name>
Host <imap-host>
Port 993
User <email>
PassCmd "security find-generic-password -a '<email>' -s '<service-name>' -w"
AuthMechs LOGIN
TLSType IMAPS
CertificateFile /etc/ssl/cert.pem

IMAPStore <name>-remote
Account <name>

MaildirStore <name>-local
Path ~/Mail/<name>/
Inbox ~/Mail/<name>/INBOX
SubFolders Verbatim

Channel <name>
Far :<name>-remote:
Near :<name>-local:
Patterns *
Create Both
Expunge Both
SyncState *
CopyArrivalDate yes
```

For Gmail, add to Patterns: `!"[Gmail]/Important" !"[Gmail]/Starred"`

Key notes:
- `AuthMechs LOGIN` — required on macOS (avoids SASL "Unable to find a callback" error)
- `SubFolders Verbatim` — preserves folder names as-is
- `Create Both` + `Expunge Both` — full two-way sync
- `CopyArrivalDate yes` — preserves original email dates

Initial sync:
```bash
mkdir -p ~/Mail/<name>
mbsync -a
```

## himalaya Config (`~/.config/himalaya/config.toml`)

```toml
[accounts.<name>]
default = true  # only on the default account
email = "<email>"
display-name = "<Your Name>"

backend.type = "maildir"
backend.root-dir = "~/Mail/<name>"

message.send.backend.type = "smtp"
message.send.backend.host = "<smtp-host>"
message.send.backend.port = 465
message.send.backend.encryption.type = "tls"
message.send.backend.login = "<email>"
message.send.backend.auth.type = "password"
message.send.backend.auth.cmd = "security find-generic-password -a '<email>' -s '<service-name>' -w"
```

Common SMTP hosts:
- Fastmail: `smtp.fastmail.com`
- Gmail/Google Workspace: `smtp.gmail.com`

## neomutt Config (`~/.config/neomutt/neomuttrc`)

```bash
# =============================================================================
# Accounts
# =============================================================================

set mbox_type = Maildir
set realname = "<Your Name>"

# Default account
set folder = "~/Mail/<default-account>"
set spoolfile = "+INBOX"
set record = "+Sent"
set postponed = "+Drafts"
set trash = "+Trash"
set from = "<default-email>"
set smtp_url = "smtps://<default-email>@<smtp-host>:465"
set smtp_pass = "`security find-generic-password -a '<default-email>' -s '<service-name>' -w`"

# Mailboxes for each account
named-mailboxes \
  "INBOX" +INBOX \
  "  Sent" +Sent \
  "  Drafts" +Drafts \
  "  Archive" +Archive \
  "  Trash" +Trash

# folder-hook for auto-switching account settings
folder-hook "~/Mail/<account>" "\
  set from = '<email>'; \
  set smtp_url = 'smtps://<email>@<smtp-host>:465'; \
  set smtp_pass = \"\`security find-generic-password -a '<email>' \
    -s '<service-name>' -w\`\"; \
  set record = '+Sent'; set postponed = '+Drafts'; set trash = '+Trash'; \
  macro index,pager A '<save-message>+Archive<enter>' 'Archive message'"

# Gmail archive = delete from INBOX (removes Inbox label; stays in All Mail)
folder-hook "~/Mail/<gmail-account>" "\
  set from = '<email>'; \
  set smtp_url = 'smtps://<email>@smtp.gmail.com:465'; \
  set smtp_pass = \"\`security find-generic-password -a '<email>' \
    -s '<service-name>' -w\`\"; \
  set record = '~/Mail/<gmail-account>/[Gmail]/Sent Mail'; \
  set postponed = '~/Mail/<gmail-account>/[Gmail]/Drafts'; \
  set trash = '~/Mail/<gmail-account>/[Gmail]/Trash'; \
  macro index,pager A '<delete-message>' 'Archive message (Gmail)'"

# =============================================================================
# Display
# =============================================================================

set index_format = "%4C %Z %{%b %d} %-20.20L  %s"
set sort = reverse-date
set sort_aux = last-date-received
set date_format = "%Y-%m-%d %H:%M"
set pager_index_lines = 10
set pager_context = 3
set pager_stop = yes
set tilde = yes
set markers = no
set wrap = 0
alternative_order text/plain text/html
auto_view text/html

# =============================================================================
# Sidebar
# =============================================================================

set sidebar_visible = yes
set sidebar_width = 24
set sidebar_format = "%D%?F? [%F]?%* %?N?%N?"
set sidebar_short_path = no
set mail_check_stats = yes

bind index,pager \Cp sidebar-prev
bind index,pager \Cn sidebar-next
bind index,pager \Co sidebar-open
bind index,pager B sidebar-toggle-visible

# =============================================================================
# Vim keys
# =============================================================================

bind index j next-entry
bind index k previous-entry
bind index g noop
bind index gg first-entry
bind index G last-entry
bind pager j next-line
bind pager k previous-line
bind pager g noop
bind pager gg top
bind pager G bottom

# =============================================================================
# Macros
# =============================================================================

# Switch inboxes
macro index gp "<change-folder>+INBOX<enter>" "Go to personal inbox"
macro index gw "<change-folder>~/Mail/work/INBOX<enter>" "Go to work inbox"

# Manual sync
macro index S "<shell-escape>mail-sync -a<enter>" "Sync all mail"

# Archive (overridden per-account by folder-hooks above)
macro index,pager A "<save-message>+Archive<enter>" "Archive message"

# =============================================================================
# Compose
# =============================================================================

set editor = "nvim"
set edit_headers = yes
set fast_reply = yes
set include = yes
```

## mailcap (`~/.mailcap`)

```
text/html; w3m -I %{charset} -T text/html -dump; copiousoutput;
```

## goimapnotify Configs (`~/.config/goimapnotify/`)

One JSON file per account:

```json
{
  "host": "<imap-host>",
  "port": 993,
  "tls": true,
  "username": "<email>",
  "passwordCmd": "security find-generic-password -a '<email>' -s '<service-name>' -w",
  "onNewMail": "/Users/<you>/.local/bin/mail-sync <account-name>",
  "boxes": ["INBOX"]
}
```

Common IMAP hosts:
- Fastmail: `imap.fastmail.com`
- Gmail: `imap.gmail.com`

## mail-sync Script (`~/.local/bin/mail-sync`)

```bash
#!/bin/sh
# Full mail sync: pull from IMAP, convert to text, update search index
LOCKFILE="${HOME}/.mbsync.lock"
if ! mkdir "$LOCKFILE" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCKFILE"' EXIT

/opt/homebrew/bin/mbsync "$@"
/Users/<you>/.local/bin/maildir-to-text
qmd update -c email
```

## maildir-to-text Script (`~/.local/bin/maildir-to-text`)

Ruby script (stdlib only, macOS system Ruby 2.6+) that converts Maildir MIME messages to plain text for search indexing. Handles multipart MIME, base64/quoted-printable encoding, RFC 2047 headers, HTML-to-text. Incremental (compares mtimes). Skips Spam and Trash.

Output goes to `~/Mail/.index/<account>/<folder>/<hash>.txt`.

See the full script in the blog post source at `~/Code/ericboehs/boehs.com/blog/2026-03-01-cli-email-macos/index.md`.

## launchd Plists (`~/Library/LaunchAgents/`)

### goimapnotify (one per account)

`com.example.goimapnotify-<account>.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.example.goimapnotify-<account></string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/<you>/go/bin/goimapnotify</string>
        <string>-conf</string>
        <string>/Users/<you>/.config/goimapnotify/<account>.json</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/Users/<you>/Library/Logs/goimapnotify-<account>.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/<you>/Library/Logs/goimapnotify-<account>.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
```

### mbsync timer (fallback every 15 minutes)

`com.example.mbsync.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.example.mbsync</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/<you>/.local/bin/mail-sync</string>
        <string>-a</string>
    </array>
    <key>StartInterval</key>
    <integer>900</integer>
    <key>StandardOutPath</key>
    <string>/Users/<you>/Library/Logs/mbsync.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/<you>/Library/Logs/mbsync.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
```

Load:
```bash
launchctl load ~/Library/LaunchAgents/com.example.goimapnotify-personal.plist
launchctl load ~/Library/LaunchAgents/com.example.goimapnotify-work.plist
launchctl load ~/Library/LaunchAgents/com.example.mbsync.plist
```

## Email Search Indexing (qmd)

```bash
# Register the email text files as a collection
qmd collection add ~/Mail/.index --name email --mask '**/*.txt'

# Initial index build
qmd update -c email

# Search
qmd search "keywords" -c email            # Fast BM25 keyword search
qmd query "natural language" -c email -n 5 # Semantic search with reranking
```

The `mail-sync` wrapper runs `maildir-to-text` and `qmd update -c email` automatically on every sync.

## Adding More Accounts

1. Store app password in Keychain
2. Add IMAPAccount/IMAPStore/MaildirStore/Channel to `~/.mbsyncrc`
3. Add `[accounts.name]` section to himalaya `config.toml`
4. Add `named-mailboxes` and `folder-hook` to `neomuttrc`
5. Create goimapnotify JSON config and launchd plist
6. Run `mbsync <name>` then `maildir-to-text`
