# The review brief

The brief is where the loop earns or wastes a round. A vague brief gets generic
findings back. A specific one found a real data leak in round 1 of the run that
this skill comes from.

Write the brief fresh every round. It is one prompt, sent with
`agent prompt reviewer-r<n> '<brief>' --wait`.

## What every brief carries

1. **The target, exactly.** Repository, branch, current commit SHA, base ref,
   and the literal `git diff` command the reviewer should run. Do not make the
   reviewer guess the base — it will pick a different one than you did.
2. **What the change is for**, and the acceptance criteria it must satisfy.
   **Quote them, do not paraphrase.** A paraphrase drops the clause that the
   defect hides behind.
3. **A not-again list.** Recorded architecture decisions, deliberate language or
   API choices, tradeoffs you already accepted, and every finding you rejected
   in an earlier round with the reason. Without this list the reviewer
   re-reports the same accepted design every round and the loop never converges.
4. **From round 2 on: the history.** What each earlier round found, how you
   fixed it, and an instruction to **verify those fixes rather than assume
   them**. This is what makes the later rounds worth their cost.
5. **The closing instruction.** Report findings ranked most severe first, each
   with `file:line`, why it is wrong, and a concrete failing scenario. Say so
   plainly if nothing is found. **Do not fix anything — report only.**

Point 5 is not a formality. A reviewer that edits files races your own fixes,
and you cannot tell afterwards which change came from where.

## Shape

```
Review the change on <repo> branch <branch>, commit <sha>, against <base>.

  git diff <base>...<sha>

Read enough surrounding code to judge it, not only the hunks.

What it is for:
  <one paragraph>

Acceptance criteria, verbatim:
  <quoted AC list>

Already decided — do not report these again:
  - <ADR / decision> — <why>
  - <rejected finding from round N> — <why it is not a defect>

Rounds so far:
  - r1 found <finding>; fixed by <change> at <sha>. Verify the fix holds, do
    not assume it.
  - r2 found <finding>; fixed by <change> at <sha>. Same instruction.

Use the code-review-pyramid skill.

Report findings ranked most severe first. For each: file:line, why it is wrong,
and a concrete scenario in which it fails. If you find nothing, say so plainly.
Do not fix anything and do not edit any file — report only.
```

## Traps

- **Quoting.** The brief is a single shell argument. Use single quotes around it
  and keep single quotes out of the text, or write the brief to a file and pass
  the file's contents. A broken quote sends half a brief and the reviewer
  answers it anyway.
- **Do not ask for a file report up front.** Ask the reviewer to write its
  report to a temp file only after a read actually comes back truncated. See
  [herdr-mechanics.md](herdr-mechanics.md).
- **Do not include the fix you have in mind.** The reviewer will find your fix
  instead of the defect.
