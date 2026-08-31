# Tracker: GitHub Issues

Board mechanics for orchestrating an epic whose slices are GitHub issues.

## The frontier query

The dependency graph is the board. After every close, ask GitHub which issues are
open, unblocked, and unattended:

```bash
gh issue list --json number,title,assignees --search 'is:open no:assignee'
```

then keep the ones whose `issue_dependencies_summary.blocked_by` is 0. Read it
from the API each time. Deriving the frontier from the graph in your head is how
a slice gets skipped - an unblocked issue was missed exactly that way after a
dependency merged.

## Labels as state

Slice state lives in labels (`ready-for-agent` and friends) alongside the issue's
open or closed state. Move the label when you spawn, and let closing the pull
request close the issue - a body with `Closes #<n>` does it.

## Merging

Rebase merge, and read the outcome rather than the exit code:

- `gh pr merge --delete-branch` **fails inside a worktree** with `main is already
  used by worktree`, *after* the merge has already landed. Only the local
  checkout and the branch delete failed. Check the remote before retrying, or
  you merge twice.
- `unable to update local ref` has the same shape: the remote merge succeeded.

## Rebase collisions

A slice that sat while siblings merged will collide on the things every slice
touches. After resolving conflicts, before pushing:

```bash
git diff --diff-filter=D origin/main    # did the rebase delete a sibling's files?
```

Concatenating conflicted CSS hunks silently splits a rule in half; run the
formatter afterwards. And refetch - the base branch can move twice inside one
session.

See [isolation-boxes.md](isolation-boxes.md) for the full collision list.

## Follow-up work

Unlike the Agidesk board, a follow-up here may become its own issue, blocked by
nothing, labelled and left on the frontier. Keep the `plans/<epic>/TODO.md`
mirror anyway - it is what survives when the session does not.
