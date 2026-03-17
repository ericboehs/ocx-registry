---
name: merge-and-cleanup
description: Merge the current branch's PR (squash) and clean up — delete branch, switch to default branch, pull, remove worktree if applicable. Use when user says "/merge-and-cleanup", "merge and cleanup", or "merge this PR".
tools: Bash, AskUserQuestion
---

# Merge and Cleanup

Merge the current branch's PR via squash merge, delete the remote branch, switch to main, pull, and clean up the worktree if applicable.

## Workflow

### Step 1: Detect context

Run these commands to understand the current state:

```bash
# Get current branch
BRANCH=$(git branch --show-current)
echo "Branch: $BRANCH"

# Check if on main/master
DEFAULT_BRANCH=$(git remote show origin | sed -n 's/.*HEAD branch: //p')
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
fi
echo "Default branch: $DEFAULT_BRANCH"

# Check for uncommitted changes
git status --porcelain

# Check if in a worktree
GIT_DIR=$(git rev-parse --git-dir)
GIT_COMMON_DIR=$(git rev-parse --git-common-dir)
echo "git-dir: $GIT_DIR"
echo "git-common-dir: $GIT_COMMON_DIR"
```

- If `DEFAULT_BRANCH` is empty, report "Could not determine the default branch — check that the `origin` remote is configured" and stop.
- If `BRANCH` equals `DEFAULT_BRANCH` (main/master), report "Already on the default branch, nothing to merge" and stop.
- If `git status --porcelain` has output, warn the user about uncommitted changes and ask whether to proceed.
- If `GIT_DIR` != `GIT_COMMON_DIR`, we're in a worktree. Note the current worktree path (`pwd`) and the main repo path (parent of `GIT_COMMON_DIR`).

### Step 2: Find and merge the PR

```bash
# Look up PR for this branch
gh pr view --json state,number,title,mergeStateStatus,statusCheckRollup
```

- If no PR exists, tell the user and suggest creating one with `gh pr create`. Stop.
- If the PR state is not `OPEN`, tell the user the PR is already closed/merged. Stop.
- If `mergeStateStatus` is `BLOCKED` or status checks are failing, warn the user and ask whether to proceed anyway.
- If everything looks good, merge:

```bash
gh pr merge --squash --delete-branch
```

If the merge fails, report the error and stop. Note: when in a worktree, `--delete-branch` may warn about failing to delete the local branch (since it's checked out). This is expected — the local branch will be cleaned up when the worktree is removed in Step 4. Only treat it as a failure if the merge itself fails.

### Step 3: Switch to default branch and pull

**If NOT in a worktree:**

```bash
git checkout $DEFAULT_BRANCH
git pull
```

**If in a worktree:**

Do NOT try to checkout inside the worktree. Instead, note that cleanup will happen next.

### Step 4: Worktree cleanup (if applicable)

If we detected a worktree in Step 1:

Use `git -C` to operate on the main repo without relying on `cd` (which does not persist across Bash tool calls). Run these as a single chained command:

```bash
WORKTREE_PATH=$(pwd)
MAIN_REPO=$(git rev-parse --git-common-dir | sed 's|/\.git$||')

git -C "$MAIN_REPO" checkout "$DEFAULT_BRANCH" && \
git -C "$MAIN_REPO" pull && \
git -C "$MAIN_REPO" worktree remove "$WORKTREE_PATH" && \
git -C "$MAIN_REPO" worktree prune
```

Report the worktree path that was removed.

### Step 5: Summary

Report what was done:
- PR number and title that was merged
- Branch that was deleted
- Whether we switched to the default branch and pulled
- Whether a worktree was cleaned up (and its path)

## Edge Cases

- **Already on main** — report nothing to do, stop
- **No PR for branch** — suggest `gh pr create`, stop
- **Uncommitted changes** — warn and ask before proceeding
- **PR merge fails** — report error, stop
- **Worktree removal fails** — report error but note the manual cleanup command
- **CI checks failing** — warn and ask before merging

## Behavior

1. Always squash merge (not regular merge or rebase)
2. Always delete the remote branch via `--delete-branch`
3. Default branch detection is automatic (works with main, master, or other names)
4. Be explicit about each step so the user sees progress
5. If a critical step fails (merge, checkout), stop and report clearly. For cleanup steps (worktree removal, prune), report the error and provide the manual recovery command
