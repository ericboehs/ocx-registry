---
name: gist-create
description: Create a GitHub Gist from a file path. Use when user says "/gist-create", "create a gist", or "gist this file".
tools: Bash, Read
---

# Create a GitHub Gist

Create a GitHub Gist from the file path provided: $ARGUMENTS

## Steps

1. Read the file to understand what it does
2. Create a gist using: `gh gist create <filepath> --desc "<description>" --public`
   - If the user requests a private gist, omit the `--public` flag (gists default to private)
3. Generate a comprehensive README as a gist comment using the GitHub API:
   ```
   gh api -X POST /gists/<gist_id>/comments -f body='<markdown_readme>'
   ```
4. The README comment should include:
   - Title and description
   - Features list
   - Installation instructions (curl from raw gist URL)
   - Dependencies
   - Usage examples
   - Configuration details (if applicable)
5. Report the gist URL to the user when complete

Note: Use single quotes around the body and escape any single quotes in the content with '\''
