---
name: review-loop
description: >-
  Review a branch or a diff in rounds, each round a disposable reviewer in its
  own Herdr pane, until a round comes back clean. Use when the user asks to loop
  the review or to run rounds of review on a change, and when an implementation
  is finished and needs a hard local review before a pull request. For a single
  review pass, code-review-pyramid is the skill. Requires HERDR_ENV=1.
---

# Review loop

A pre-merge review that runs on this machine only, before a bot or a person
looks at the pull request. You are the **orchestrator**: you own the code, the
fixes, and the commits. Each round you hire a **disposable** reviewer, read its
report, fix what is real, and let it go.

## Why the reviewer is disposable

A disposable reviewer arrives with no memory of the last round. That is the
whole point: an agent that already argued a finding is dead defends that verdict
instead of checking whether your fix works, and the loop stops finding things.

A quiet round is partly luck. In one measured run of eleven rounds, round 9
reported 0 findings and round 10 reported 20 findings on the **same commit**. So
one clean round is not proof — which is why the stop condition accepts two quiet
rounds, not one.

## Before round 1

1. Run `test "${HERDR_ENV:-}" = 1`. If it fails, say you are not inside Herdr
   and stop — the loop has no fallback.
2. Know the target: repository, branch, base ref, and the current commit SHA.
3. Commit the change. The reviewer reads a diff, not your editor.
4. Assemble the brief material — see
   [references/review-brief.md](references/review-brief.md). Do this before
   round 1, not during it: a vague brief wastes the round.
5. Track the loop in a todo list, adding one item per round as you go. The round
   count is unknown until the loop stops.

## One round

Repeat this, with `<n>` counting up from 1:

1. **Split a pane and start the reviewer** named `reviewer-r<n>`. Commands,
   model, ID handling, and the traps live in
   [references/herdr-mechanics.md](references/herdr-mechanics.md). Done when
   `agent start` reports the agent ready.
2. **Send the brief.** It runs the `code-review-pyramid` skill against the diff
   and asks for a report, not edits — a reviewer that writes races your own
   fixes and you lose both. Done when the wait settles.
3. **Read the report** from the tail of the pane. Done when you hold every
   finding the reviewer raised, each with its `file:line`. A truncated read is
   not a report; recover it before you move on.
4. **Triage every finding.** Each one ends as either a fix you will make or a
   rejection with a written reason. Done when no finding is left unaccounted
   for — a finding with no verdict is this loop's most common silent failure.
5. **Fix the real ones**, run the checks the repository asks for, then amend or
   add a commit. Force-push only if the branch is already pushed.
6. **Release the reviewer**: interrupt it and close the pane this round created.
7. **Report the round** in a few lines: findings raised, which were real, what
   you changed, and the new SHA.
8. Carry every rejection into the next round's brief as a settled decision, then
   start round `<n>+1` in a new pane under a new name — unless the stop
   condition holds.

## Stop condition

Stop when either is true:

- a round reports **zero findings**; or
- **two consecutive rounds** report nothing blocking.

Boring findings are not a stop condition, and a round ends only once its fix is
committed.

## Guardrails

Two decisions belong to the user, and the loop leaves both alone:

- **Do not open the pull request.** The user approves it.
- **Do not move the tracker task** to a review step.

When the loop stops, report that the branch is ready and let the user decide
what happens next.

## Expect these

- Severity falls across rounds, and each round tends to find the previous
  round's blind spot. That shape is the loop working.
- A round that re-raises a decision you already settled means the brief's
  settled-decision list is too short. Fix the brief, not the reviewer.
- Green gates and many quiet rounds still miss a broken feature. The loop reads
  code; it does not run the product. If the change has a screen or an endpoint a
  person can exercise, exercise it before you call the branch ready.
