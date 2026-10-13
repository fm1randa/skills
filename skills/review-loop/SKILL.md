---
name: review-loop
description: >-
  Review a branch or a diff in rounds, each round a disposable reviewer
  sub-agent, until a round comes back clean. Use when the user asks to loop the
  review, and when an implementation is finished and needs a hard local review
  before a pull request. For a single review pass, code-review-pyramid is the
  skill.
---

# Review loop

A pre-merge review that runs on this machine only, before a bot or a person
looks at the pull request. You are the **orchestrator**: you own the code, the
fixes, and the commits. Each round you hire a **disposable** reviewer
sub-agent, read its report, fix what is real, and let it go.

## Why the reviewer is disposable

A disposable reviewer arrives with no memory of the last round. That is the
whole point: an agent that already argued a finding is dead defends that verdict
instead of checking whether your fix works, and the loop stops finding things.
So every round is a **fresh** `Agent` call.

A quiet round is partly luck. In one measured run of eleven rounds, round 9
reported 0 findings and round 10 reported 20 findings on the **same commit**. So
one clean round is not proof — which is why the stop condition accepts two quiet
rounds, not one.

## Before round 1

1. Know the target: repository, branch, base ref, and the current commit SHA.
2. Commit the change. The reviewer reads a diff, not your editor.
3. Assemble the brief material — see
   [references/review-brief.md](references/review-brief.md). Do this before
   round 1, not during it: a vague brief wastes the round.
4. Track the loop in a todo list, adding one item per round as you go. The round
   count is unknown until the loop stops.

## One round

Repeat this, with `<n>` counting up from 1:

1. **Start the reviewer** with the `Agent` tool, per [Sub-agents](#sub-agents)
   below, described as `reviewer-r<n> <branch>`. The prompt is the brief.
2. **Wait for its notification.** The reviewer runs in the background; spend the
   time on another loop's triage, or end the turn.
3. **Read the report** — it is the sub-agent's final message. Done when you hold
   every finding the reviewer raised, each with its `file:line`. A report that
   ends mid-list or summarises "and N more" is not a report: start a fresh
   reviewer for the same round asking for the full list.
4. **Confirm the tree is untouched.** `git status --porcelain` is clean and
   `HEAD` is still the SHA you briefed. If either moved, discard the reviewer's
   change and restate report-only in the next brief.
5. **Triage every finding.** Each one ends as either a fix you will make or a
   rejection with a written reason. Done when no finding is left unaccounted
   for — a finding with no verdict is this loop's most common silent failure.
6. **Fix the real ones**, run the checks the repository asks for, then amend or
   add a commit. Force-push only if the branch is already pushed.
7. **Report the round** in a few lines: findings raised, which were real, what
   you changed, and the new SHA.
8. Carry every rejection into the next round's brief as a settled decision, then
   start round `<n>+1` with a new `Agent` call — unless the stop condition
   holds.

## Sub-agents

- **Sonnet at medium effort**, held constant across rounds: pass `model:
  "sonnet"` and leave `effort` unset unless the user asked for one. Changing the
  model mid-loop changes what a quiet round means.
- **`subagent_type: "general-purpose"`.** The reviewer runs `code-review-pyramid`,
  which fans out its own sub-agents, so it needs the Agent tool; a read-only
  type such as Explore cannot spawn them. Report-only is enforced by the brief
  and checked in step 4, not by the tool list.
- **`run_in_background: true`.** You are notified when it finishes. This is also
  what lets several loops — one per branch — run at the same time from one
  orchestrator.
- **A checkout that holds still.** If you fix a branch while its reviewer is
  still reading, the diff shifts under it. Wait for the report before touching
  the branch; for loops running side by side, give each its own worktree and
  put that path in the brief.
- **One `Agent` call per question.** A follow-up, a truncated report, a re-check
  after a fix: each is a fresh reviewer with a fresh brief, because continuing
  one with `SendMessage` hands it back the history the loop exists to drop.

## Stop condition

Stop when either is true:

- a round reports **zero findings**; or
- **two consecutive rounds** report nothing blocking.

Boring findings are not a stop condition, and a round ends only once its fix is
committed.

## Guardrails

Two decisions belong to the user, and the loop leaves both alone unless the user
has said otherwise for this run:

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
