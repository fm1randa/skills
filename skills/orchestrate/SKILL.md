---
name: orchestrate
description: >-
  Drive an epic to done by running one disposable implementer session per slice
  through Herdr - spawn, review, validate on screen, open the pull request,
  merge, and keep the tracker board honest - without the driving session ever
  writing code. Use when the user asks to orchestrate or drive an epic or its
  remaining slices, when one slice lands and the next must start, or when
  several tickets under one parent have to reach merge. For the review rounds of
  a single change, review-loop is the skill; for cutting work into slices,
  to-tickets. Requires HERDR_ENV=1.
---

# Orchestrate an epic

You are the **orchestrator**. You own the board, the panes, and the order of
work. You never write the code.

That boundary is absolute for a slice's repository: no edit, no commit, no push,
not a lint nit. A commit of yours lands in a branch whose owner is a session that
does not know about it, and races that session's next commit. You do write
elsewhere - `plans/<epic>/TODO.md`, tracker comments, your own notes.

## Roles

Every worker is **disposable**: one fresh session, one job, then the pane dies.
A session that already argued a verdict defends it instead of rechecking, and a
session that watched a feature get built sees what it expects to see.

| Role | Pane name | Model | Lives for |
| --- | --- | --- | --- |
| Implementer | `impl-<ticket>` | `--model opus --effort medium` | one slice |
| Reviewer | `reviewer-r<n>` | `--model sonnet --effort medium` | one review round |
| Validator | `validator-<ticket>` | `--model sonnet --effort medium` | one validation pass |

Those models are the default, not a law. When the user names a different model or
effort for a role, use it for the rest of the epic.

Read the pane footer after every `agent start`: an effort flag can fail silently,
and you find out three hours later from the quality of the work.

`herdr --skill` is the authority on splitting panes, `agent start`, `agent
prompt`, `send-keys`, and ID handling. Read it rather than deriving any of that
here. `$HERDR_PANE_ID` goes stale after a session resume - `herdr pane current
--current` resolves the calling pane and the variable does not.

## Before the first slice

1. `test "${HERDR_ENV:-}" = 1`. On failure, say you are not inside Herdr and
   stop - there is no fallback.
2. Get the epic id. It is the one fact you cannot derive; ask for it.
3. Read the epic and its slices from the tracker. **If the epic has no slices,
   stop and tell the user to cut them with `/to-tickets`.** Orchestration drives
   slices; it does not invent them.
4. Report the board state slice by slice before touching anything.

## The frontier

The **frontier** is every slice whose blockers are already merged and which no
session is working. It is the only queue you have.

Re-derive it from the tracker after **every** slice closes - never from your own
memory of the graph. A slice that no dependency edge mentions still gets
unblocked by the one that just landed, and reading the board is how you find it.

The board plus `herdr agent list` are the only durable state of this session.
They survive a compaction and a machine sleep; nothing you hold in context does.
Re-read them rather than trusting a note.

Default to **one slice at a time**. Escalate to parallel clone boxes when the
frontier holds slices that touch nothing in common - see
[references/isolation-boxes.md](references/isolation-boxes.md) for the boxes and
the collision list.

## Driving one slice

1. **Move the slice to the in-progress step** yourself, then split a pane and
   start `impl-<ticket>`. Done when `agent start` reports ready and the footer
   shows the model and effort you asked for.

2. **Send message 1: the briefing.** Read-only context and hard rules, with
   exactly one write allowed. Fill the template in
   [references/implementer-briefing.md](references/implementer-briefing.md).
   Done when the implementer answers that it has read and understood, having
   changed nothing.

3. **Send message 2: the slash command alone**, on its own, with no preamble -
   `/implement TRF-X`. `/implement` carries `disable-model-invocation: true`, so
   it loads only when it arrives as a typed command; wrapped in a sentence it
   lands as prose and the session improvises without the skill.

4. **Verify the command loaded.** Grep the implementer's transcript for the
   command name:

   ```bash
   ls -t ~/.claude/projects/<cwd-slug>/*.jsonl | head -1 | xargs grep -c command-name
   ```

   The slug is the implementer's working directory with every `/` turned into
   `-`. A zero count means the command arrived as text: kill the pane and
   respawn. Resending into a session that already read it as prose leaves the
   prose in its context. Done when the count is non-zero.

5. **Wait on a Monitor, not on a sleep.** See [Observability](#observability).

6. **Review to the tier.** Read the slice's size field:
   - **XS / S**: one `/code-review` pass inside the implementer's own session. No
     reviewer pane.
   - **M and up**: the `review-loop` skill, which owns the rounds, the reviewer
     brief, and the stop condition. One thing it does not cover, because it
     assumes the orchestrator owns the code: here the reviewer reads the
     **implementer's** branch and the **implementer** fixes and commits. You
     carry findings between them and you triage - every finding ends as a fix or
     as a written rejection, and every rejection goes into the next round's brief
     as settled.

   Done when the tier's stop condition holds and the fix is committed.

7. **Validate on screen.** Spawn `validator-<ticket>` fresh and brief it from
   [references/validator-briefing.md](references/validator-briefing.md). It
   exercises the product and reports evidence per acceptance criterion. **You
   verify that report** - evidence that does not show the criterion is not a
   pass - and send anything real back to the implementer. Done when every
   criterion has evidence you have read.

   This gate is not optional for a slice with a screen or an endpoint a person
   can exercise. Green gates and quiet review rounds miss broken features: 99
   tests missed two bugs, 916 tests plus a smoke run missed four, seven review
   rounds and five green gates missed a feature that threw on every save. Only
   the screen caught them.

8. **Ask the user to approve the pull request.** Then have the implementer run
   `/open-pr`. See [Approvals](#approvals) for what you may answer on its behalf.

9. **Move the slice to the review step** to fire the auto-review bot, then have
   the implementer run `/babysit` until the PR is clean.

10. **Merge by observation.** Watch what actually happened rather than assuming:
    some repositories are merged by the bot, others wait for a person. Ask the
    user for a manual merge only once the PR is approved and still open.

11. **Close the books**: the implementer drafts the findings comment
    (`/feedback` -> `/humanizer` -> `/no-ai-slop`) and hands you the HTML; you
    post it, move the slice to its done step, and do the tracker's own
    bookkeeping. Per-tracker mechanics live in
    [references/tracker-agidesk.md](references/tracker-agidesk.md) and
    [references/tracker-github.md](references/tracker-github.md).

12. **Kill the pane**, then re-derive the frontier.

## Observability

Start one persistent edge-triggered **Monitor** per live worker, polling
`herdr agent get <name>`. Report only the transitions - `idle`, `blocked`,
`done` - and suppress `working`, which says nothing and arrives constantly. Kill
the Monitor with the pane.

Wait on that Monitor rather than on `herdr agent wait`, which dies when the
machine sleeps, and rather than on a sleep loop, which burns the turn.

Read a worker's **report from its transcript jsonl**, not from the pane. A pane
tail truncates and reflows, and a truncated report reads exactly like a complete
one. The pane is for two things only: inspecting a blocked UI before you answer
it, and reading the input line before you send Enter - text nobody sent has
appeared in a worker's input, so discard anything you did not write.

## Approvals

One human approval per outward act: opening a pull request, merging, creating or
cancelling a task. Ask before each.

Once the user has approved an act, clear the **plumbing** for that same act
yourself with `herdr agent send-keys`: the base-branch confirmation, the task
reference, the `gh pr create` permission prompt. Those re-ask a question already
answered. A prompt that asks something new goes back to the user.

## Recovery

A worker dies - API error, machine sleep, tokens gone, a pane closed by hand.
Never resume its context. Read the slice's real state from git (branch, commits,
whether it is pushed) and from the board, then spawn a fresh worker with a
briefing that names what already landed.

## Epic closeout

After the last slice merges:

1. Run the frontier query once more, to prove nothing is unblocked and
   unattended. This is where a slice gets forgotten.
2. If the epic sits behind a feature flag, ask the user whether it ships on or
   off. Every slice shipped with it off; this is the one place the answer
   changes.
3. Report what remains at the epic level - joint QA, cancelled slices, the
   follow-ups on `plans/<epic>/TODO.md` - and hand the epic back.

## Reporting

One terse block per transition: spawned, round closed, validated, PR open,
merged, board moved. Between transitions, say nothing. Lean prose, hyphens for
bullets, no restating of the plan.
