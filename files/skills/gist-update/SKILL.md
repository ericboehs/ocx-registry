---
name: gist-update
description: Update an existing GitHub Gist from a local file. Use when user says "/gist-update", "update the gist", or "sync gist".
tools: Bash, Read
---

# Update an existing GitHub Gist

Update an existing GitHub Gist from a local file: $ARGUMENTS

Arguments can be:
- Just a file path (will search for existing gist by filename)
- A file path and gist ID/URL

## Steps

1. If no gist ID provided, try to find an existing gist:
   - `gh gist list --limit 100` and search for the filename
   - Or ask the user for the gist ID/URL
2. Update the gist file: `gh gist edit <gist_id> <filepath>`
3. Update the README comment if it exists:
   - Get the comment ID: `gh api /gists/<gist_id>/comments --jq '.[0].id'`
   - Update it: `gh api -X PATCH /gists/<gist_id>/comments/<comment_id> -f body='<updated_readme>'`
   - If no comment exists, create one with the README
4. The README should reflect any new features or changes in the updated file
5. Report the gist URL when complete

Note: Use single quotes around the body and escape any single quotes in the content with '\''
