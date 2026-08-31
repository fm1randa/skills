# The validator briefing

The validator is fresh, disposable, and has not watched the slice get built.
That is the point: the implementer believes the feature works, and so does any
session that helped write it.

It exercises the product and reports **evidence**. It does not fix anything - a
validator that edits races the implementer's commits, and you lose both.

## What to give it

- The slice's acceptance criteria, one by one, as the checklist to work through.
- How to reach a running environment: URL or host, credentials, which services
  must be up, the seed or fixture data it needs.
- Which route to drive the product with. Name what the project already provides
  rather than inventing one: the `browser-control` skill for a web UI, the
  project's own smoke script, a purpose-built Electron capture script, `curl`
  for an endpoint.
- The flag state to test in - and, when the epic has a flag, that it must also
  check the old path with the flag **off** and confirm it is unchanged.

## What to demand back

Evidence per criterion, not a claim. A screenshot, a captured response body, a
recorded frame. "Works as expected" is not a result.

Four defects on one redesign were invisible to 916 tests and a green smoke run,
and visible immediately in captured frames: a snippet rendering as a block, a
missing separator, initials taken from an email address, a column vanishing in
the split view. Evidence is what makes that class of defect reachable.

## What you do with it

Verify the report yourself before acting. Evidence that does not actually show
the criterion is a failed validation, not a pass - and a validator reporting a
pass with no artifact attached is the most common way this gate goes hollow.

Send real findings back to the implementer, then kill the validator's pane. If a
second pass is needed after the fix, spawn a new validator; do not wake the old
one.
