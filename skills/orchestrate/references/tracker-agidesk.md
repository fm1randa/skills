# Tracker: Agidesk

Board mechanics and API traps for orchestrating an epic on Agidesk. Everything
here is what the API does not confess.

## Moving a slice

A move needs **two** things: the `status_id` **and** a workflowstep pivot. The
pivot is not an update - POST the new pivot, then DELETE the old one. Change the
status alone and the board shows the slice in one place while the workflow
believes another.

Steps do not walk backwards the way the numbers suggest: `back` from step 310
lands on 308, not 309. Reaching 309 takes two forwards.

Moving a slice to the **Code Review** step is what fires the auto-review bot; the
bot does not watch the pull request. When the step move is not an option,
dispatch it directly:

```bash
gh workflow run auto-code-review.yml -f task_id=<ticket>
```

The bot lands roughly five minutes later. It does not review every repository -
one outside its allowlist gets no bot review at all, and the slice needs a human
reviewer instead.

## Writes that lie

- **A refused write still returns HTTP 200**, with the refusal in
  `error_message`. Read the body; the status code proves nothing.
- **A duplicate write surfaces as `unexpected_error`**, not as a duplicate.
- **DELETE also refuses with HTTP 200.** Same rule.
- **Idempotency keys are mandatory on every write** - and a key is cached for an
  hour without being invalidated by a delete. Reusing a key after deleting what
  it created returns the old result, not a new write.
- **Pagination is driven by the returned length**, not by a total.
- A `hidden` field with no flag gate arrives empty and MySQL stores 0 in the
  TINYINT. Drop the key from the payload instead of sending it empty.

## Comments

An internal HTML comment is a **two-step** write: create the comment with plain
content, then `PUT` its `htmlcontent`. One-step creation loses the markup.

## Closing a slice

Move to **Concluído**, restore `responsible_id` to whoever owned the slice before
you, and check the epic's To Do item for it.

## Follow-up work never becomes a task

Work discovered while implementing a slice does not get its own ticket on this
board. It goes on the epic's To Do checklist and on `plans/<epic>/TODO.md`. This
is a standing convention of the team, not a preference - a sibling ticket for a
follow-up gets bounced.

## Language

Ticket content is pt-BR. Code artifacts - branch names, commit messages, pull
request title and body, code comments - are English.

In pt-BR, a pull request is masculine on this team: *o PR*, never *a PR*.
