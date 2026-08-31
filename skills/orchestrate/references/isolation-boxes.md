# Isolation boxes and collisions

Two implementers in one checkout overwrite each other's branch. A **box** is a
separate clone of the repository, one per slice, so each session gets its own
working tree, its own branch, and its own running services.

```
~/Workspace/boxes/<slice>/<repo>
```

Use one when the main checkout is busy, or when the frontier holds slices that
touch nothing in common. Default to a single slice at a time: parallelism buys
wall-clock and costs the collisions below, and the trade only pays when the
slices are genuinely independent.

Set the box path as the implementer's `<cwd>` slot in its briefing, and remember
that its transcript lives under that path's slug, not the main checkout's.

## The collision list

Independent slices still collide on the shared, monotonic things. Say so in
every briefing that goes to a box:

- **ADR numbers.** Three parallel sessions each wrote `0006`. Whoever rebases
  last renumbers - on one epic the same ADR was renumbered three times. Check
  `docs/adr/` immediately before opening the pull request, not when you write
  the file.
- **Migration numbers.** Same shape, worse consequence: two migrations with one
  number reach staging and one is skipped silently.
- **Shared registry files** - a context map, an index, a barrel export, a
  translations file. Each slice appends a line and every rebase conflicts.
- **Herdr agent names are global across sessions.** Another session took
  `reviewer-r1` mid-loop. Name workers after the slice, not after the round
  alone.
- **Feature-flag keys**, when two slices sit behind the same epic flag and both
  add it to a config.

## After a rebase in a box

```bash
git fetch                                # the base moved, possibly twice
git diff --diff-filter=D origin/<base>   # did the rebase delete a sibling's files?
```

Then run the formatter. Resolving conflicted CSS or config by concatenating both
hunks splits a rule in half, and only the formatter or the next reviewer notices.

## Retiring a box

Delete it when the slice merges, in the same step that kills the pane. A stale
box is a checkout that will one day be mistaken for the live one, and its
services keep holding ports and memory.
