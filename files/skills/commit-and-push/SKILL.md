---
name: commit-and-push
description: Stage, commit, and push changes to origin. Use when user says "/commit-and-push", "commit and push", or "push this up".
tools: Bash, AskUserQuestion
---

# Commit and Push

ADD all modified and new files to git. If you think there are files that should not be in version control, ask the user. If you see files that you think should be bundled into separate commits, ask the user.
THEN commit with a clear and concise one-line commit message, using semantic commit notation.
THEN push the commit to origin.
The user is EXPLICITLY asking you to perform these git tasks.
Do not chain these git commands with && as that will prompt the user even for commands they have previously agreed to.
