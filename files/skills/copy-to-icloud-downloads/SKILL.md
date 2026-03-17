---
name: copy-to-icloud-downloads
description: Copy files to iCloud Downloads for reading on iPhone/iPad. Use when user says "/copy-to-icloud-downloads", "put in icloud downloads", "copy to icloud", or "send to my phone".
tools: Bash
---

# Copy to iCloud Downloads

Can you put a copy in my iCloud Downloads so I can read it on my phone?

The iCloud Downloads path is `~/Library/Mobile Documents/com~apple~CloudDocs/Downloads/`.

Use conversation context to determine which file the user wants copied. If it's ambiguous, ask.
