# The review brief

The brief is where the loop earns or wastes a round. A vague brief gets generic
findings back. A specific one found a real data leak in round 1 of the run this
skill comes from.

Write the brief fresh every round. It is one prompt, sent with
`agent prompt reviewer-r<n> '<brief>' --wait`.

## What every brief carries

1. **The target, exactly.** Repository, branch, current commit SHA, base ref,
   and the literal `git diff` command the reviewer should run. Name the base
   yourself — a reviewer left to infer it picks a different one than you did.
2. **What the change is for**, and the acceptance criteria it must satisfy,
   **quoted verbatim**. A paraphrase drops the clause the defect hides behind.
3. **The settled decisions.** Recorded architecture decisions, deliberate
   language or API choices, tradeoffs you already accepted, and every finding
   you rejected in an earlier round with the reason. This list is what stops the
   reviewer re-litigating an accepted design every round while the loop fails to
   converge.
4. **From round 2 on: the history.** What each earlier round found, how you
   fixed it, and an instruction to **verify those fixes rather than assume
   them**. This is what makes the later rounds worth their cost.
5. **The closing instruction.** Report findings ranked most severe first, each
   with `file:line`, why it is wrong, and a concrete failing scenario. Say so
   plainly if nothing is found. **Report only — change no file.**

Point 5 is not a formality. A reviewer that edits files races your own fixes,
and afterwards you cannot tell which change came from where.

## Shape

```
Review the change on <repo> branch <branch>, commit <sha>, against <base>.

  git diff <base>...<sha>

What it is for:
  <one paragraph>

Acceptance criteria, verbatim:
  <quoted AC list>

Settled already — treat these as decided, not as findings:
  - <ADR / decision> — <why>
  - <rejected finding from round N> — <why it is not a defect>

Rounds so far:
  - r1 found <finding>; fixed by <change> at <sha>. Verify the fix holds rather
    than assuming it.
  - r2 found <finding>; fixed by <change> at <sha>. Same instruction.

Use the code-review-pyramid skill.

Report findings ranked most severe first. For each: file:line, why it is wrong,
and a concrete scenario in which it fails. If you find nothing, say so plainly.
Report only — change no file.
```

## Traps

- **Quoting.** The brief is a single shell argument. Wrap it in single quotes and
  keep single quotes out of the text, or write it to a file and pass the file's
  contents. A broken quote sends half a brief, and the reviewer answers it
  anyway.
- **Ask for a file report only after a read comes back truncated**, never up
  front. See `herdr --skill`.
- **State the problem, not your intended fix.** A brief that names the fix you
  have in mind gets that fix reviewed instead of the defect.
