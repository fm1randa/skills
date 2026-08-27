---
name: review-loop
description: >-
  Run rounds of local code review on a branch or a diff before anyone else
  looks at it. Each round is a fresh, disposable reviewer agent in its own
  Herdr pane running /code-review-pyramid; the caller reads the findings, fixes
  the real ones, and starts the next round in a brand new pane. Use when the
  user asks to loop the review, to review a change in rounds, to keep reviewing
  until it is clean, to "run the review loop", or when an implementation is
  finished and needs a hard local review before a pull request. Do not use for
  a single one-shot review — that is code-review-pyramid on its own. Requires
  HERDR_ENV=1.
---

# Review loop

A pre-merge review that runs on this machine only, before a bot or a person
looks at the pull request. You are the **orchestrator**: you own the code, the
fixes, and the commits. Each round you hire a reviewer, read its report, fix
what is real, and let it go.

## Why a new reviewer each round

The reviewer is never reused between rounds. A clean context each round is the
whole point: an agent that already argued a finding is dead is not the agent you
want to check whether the fix works. A reviewer that keeps its history defends
its earlier verdicts, and the loop stops finding things.

A quiet round is partly luck. In one measured run of eleven rounds, round 9
reported 0 findings and round 10 reported 20 findings on the **same commit**. So
one clean round is not proof. That is why the stop condition below accepts two
quiet rounds, not one.

## Before the first round

1. Run `test "${HERDR_ENV:-}" = 1`. If it fails, say you are not inside Herdr
   and stop. The loop has no fallback.
2. Know the target: repository, branch, base ref, and the current commit SHA.
3. Have the change **committed**. The reviewer reads a diff, not your editor.
4. Assemble the brief material — see
   [references/review-brief.md](references/review-brief.md). Do this before
   round 1, not during it. A vague brief wastes the round.
5. Make a todo list with one item per round, so a long loop does not drop a
   finding.

## One round

Repeat this, with `<n>` counting up from 1:

1. **Split a pane** and start a reviewer named `reviewer-r<n>` in it. Model:
   Sonnet 5, medium effort. Exact commands, ID handling, and the traps are in
   [references/herdr-mechanics.md](references/herdr-mechanics.md).
2. **Send the brief** with `agent prompt --wait`. The brief tells the reviewer
   to run the `code-review-pyramid` skill against the diff and to **report
   only**.
3. **Read the report** from the tail of the pane.
4. **Triage each finding yourself.** Keep the ones you can tie to real code.
   Reject the others out loud, with the reason — an unexplained rejection looks
   the same as an unread finding. A finding you reject becomes a line in the
   next round's brief, so it is not raised again.
5. **Fix the real ones**, run the checks the repository asks for, then amend or
   add a commit. Force-push only if the branch is already pushed.
6. **Close the reviewer**: interrupt it, then close only the pane you created.
7. **Report the round** to the user in a few lines: how many findings, which
   were real, what you changed, and the new SHA.
8. If the stop condition is not met, go to round `<n>+1` with a **new** pane and
   a **new** name.

## Stop condition

Stop when either of these is true:

- a round reports **zero findings**; or
- **two consecutive rounds** report nothing blocking.

Do not stop because the findings became boring, and do not stop mid-round with a
fix uncommitted.

## What the loop must not do

- **Do not open the pull request.** The user approves the pull request.
- **Do not move the tracker task** to a review step. That is also the user's
  call.
- **Do not let the reviewer edit files.** The brief must forbid it. A reviewer
  that writes races your own fixes, and you lose both.
- **Do not close panes you did not create.**

When the loop stops, say the branch is ready and let the user decide what
happens next.

## Expect these

- Severity falls across rounds, and each round tends to find the previous
  round's blind spot. That shape is the loop working.
- A round that only repeats a design decision you already accepted means the
  brief's not-again list is too short. Fix the brief, not the reviewer.
- `agent prompt --wait` outlives a foreground tool timeout, moves to the
  background, and notifies you when it finishes. That is normal. Do not poll it,
  and do not treat it as a hang.
- Green gates and many quiet rounds still miss a broken feature. The loop reads
  code; it does not run the product. If the change has a screen or an endpoint a
  person can exercise, exercise it before you call the branch ready.

## Worked example

Three rounds on one pull request in `agidesk-cms`, a small feature behind a
feature gate:

- **Round 1** — one blocking finding. The gate closed the aggregate and the UI,
  but not the per-tenant rows of the JSON response, so an allowlisted user could
  read the gated view straight out of the network tab. Fixed by moving the gate
  into the pure function that builds the data, closed by default.
- **Round 2** — nothing blocking, one important finding: the logic added in
  round 1 had no test. Fixed by extracting it into a pure module and testing it.
- **Round 3** — clean. Loop stopped on the two-quiet-rounds arm.

Note the shape: the severity fell each round, and each round found what the
previous round had just created.
