---
name: code-review-pyramid
description: >-
  Structured code review organized by Gunnar Morling's Code Review Pyramid.
  Concentrates review attention where it pays off — API semantics and
  implementation correctness — while letting linters own formatting and style.
  Runs the review as a parallel multi-agent fan-out (one agent per pyramid
  layer) and confidence-scores every finding, dropping low-confidence noise
  before it reaches you. Use whenever the user asks to review code, a diff, a
  branch, or a pull request, especially when they want a prioritized,
  severity-ranked review instead of a flat list of nitpicks, or when they
  mention the "code review pyramid" or reviewing "by priority". Auto-detects
  whether to review a GitHub PR or the local diff and reports findings layer by
  layer, most important first.
---

# Code Review Pyramid

Review code the way the [Code Review Pyramid](https://www.morling.dev/blog/the-code-review-pyramid/) prescribes: put your effort where mistakes are expensive to undo and impossible to automate away.

The pyramid ranks five concerns by how much human attention they deserve. The base is where you spend most of your time; the apex is what a tool should be checking instead of you:

```
        ╱  Code Style  ╲          ← automate this; barely worth a human's time
       ╱     Tests       ╲
      ╱   Documentation    ╲
     ╱ Implementation Sem.   ╲
    ╱      API Semantics       ╲   ← focus your review here; costly to change later
   ╱────────────────────────────╲
```

Gunnar Morling's original diagram is bundled at [references/code-review-pyramid.svg](references/code-review-pyramid.svg) (CC BY-SA 4.0, © @gunnarmorling). Each layer's canonical "Questions to ask" from that diagram, plus deeper reviewer guidance, lives in its own file under `references/` — the fan-out in Step 3 hands each agent the file for its layer.

**Why this ordering.** A bad public API or a subtle correctness bug ships forever and is painful to walk back once people depend on it. A misplaced brace gets fixed by a formatter in one second. Reviewers instinctively pile onto style because it's easy to spot — and starve the parts that actually matter. This skill exists to fight that instinct: read the base layers slowly and carefully, skim the apex, and never let a style nit outrank a correctness problem.

## How this review runs

The review is a pipeline. The middle of it fans out across parallel agents so a large diff gets read deeply on every layer at once instead of one reviewer skimming everything serially:

1. **Detect** the target (PR vs. local diff).
2. **Set up** — eligibility + context, gathered by fast agents.
3. **Fan out** — one capable agent per pyramid layer reviews in parallel.
4. **Score** — a fast agent confidence-rates each finding; drop the low-confidence ones.
5. **Report** — a pyramid-ordered terminal report, most important first.
6. **(PR only) Offer to post** the report back as a GitHub comment.

Two scoring axes run through this and they are **orthogonal — don't conflate them:**
- **Confidence** answers *"is this finding real, or a false positive?"* (Step 4). It gates what survives.
- **Severity** answers *"how much does it matter?"* (the [Severity model](#severity-model-pyramid-weighted) below). It ranks what's left, capped by pyramid layer.

A finding must clear the confidence bar first, then it's ranked by severity. The confidence gate is deliberately aggressive (≥80 to survive), which means it naturally suppresses nitpicks and unverifiable hunches — that *reinforces* the pyramid's anti-style-noise stance rather than fighting it.

**Make a todo list** before you start so the phases don't get dropped on a big review.

**When to fan out vs. stay inline.** Spawning ~10 agents for a five-line change is slower and costlier than just reading it. Use the full parallel fan-out for non-trivial diffs and PRs. For a small or obviously simple diff — or when no subagent tool is available — run the whole thing inline in a single pass instead: same layers, same severity model, same confidence gate (self-assessed), just no delegation. Don't apologize for this; it's the right call on small changes.

## Step 1 — Detect what you're reviewing (auto-detect)

Work out the target without asking the user unless it's genuinely ambiguous:

- **The user named a PR** (number, URL, or "the PR for X") → use `gh pr view <n> --json title,body,headRefName,baseRefName` and `gh pr diff <n>`.
- **No PR named, but the current branch has one** → `gh pr view --json number,title,body,baseRefName` (this targets the current branch; if it errors, there's no PR).
- **No PR** → review locally. If there are uncommitted changes, review `git diff` (and `git diff --staged`). If the tree is clean, review the branch against its base: find the base with `git merge-base HEAD origin/HEAD` (fall back to `main`/`master`/`develop`), then `git diff <base>...HEAD`.

Capture the **diff** and the **list of changed files**. State in one line what you ended up reviewing (e.g. "Reviewing PR #214 (feat/export-api), 6 files") so the user can correct you if you guessed wrong.

## Step 2 — Set up: eligibility and context (fast agents)

These tasks are cheap and independent, so for a PR run them as parallel **fast (Sonnet) agents** rather than doing them serially yourself:

- **Eligibility (PR only).** Check whether the PR (a) is closed, (b) is a draft, (c) doesn't warrant a review — an automated/bot PR, or something so small and obviously fine that a review adds nothing — or (d) already carries a review comment from you. If any of these hold, **stop and say so** instead of producing a review. For a local diff there's nothing to gate; skip this.
- **Project conventions.** Get the file *paths* (not contents) of the relevant convention files: the root `CLAUDE.md`/`CONTRIBUTING`, plus any `CLAUDE.md` in the directories the change touched. These define what "follows our conventions" means for the style and API layers — but they're guidance written for code authors, not a checklist to litigate, so not every line applies during review.
- **Change summary.** A short summary of what the change does and *why* (from the PR description, linked issue, or commit messages). This anchors the top question of every semantic layer — *does this do what it was supposed to?* If there's no stated intent and it's unclear, ask the user briefly.

## Step 3 — Fan out: review layer by layer, base first (parallel agents)

Launch the layer reviews as **parallel capable (Opus) agents** — one per pyramid layer — so every layer gets a deep, dedicated read at once. Spend effort in proportion to the pyramid: the two bottom layers deserve the bulk of the thinking; the top gets a quick, generous pass.

Give every layer agent the diff, the changed-file list, the convention-file paths and change summary from Step 2, and **the [Severity model](#severity-model-pyramid-weighted) and [What not to flag](#what-not-to-flag) sections below** — they apply the layer cap and the false-positive filter themselves. Tell each agent to read enough surrounding code (not just the hunks) to judge its layer, and to return a list of findings where each finding carries: `layer`, proposed `severity`, `file:line`, a tight *what / why / fix*, and the **reason it was flagged** (bug, `CLAUDE.md` says "…", git history, prior-PR comment, code comment).

Spawn one agent per layer and **give each the path to its layer file** — the file carries that layer's canonical "Questions to ask" (verbatim from the diagram) plus the deeper reviewer notes and the layer's severity ceiling. The agent reads its file and works only its layer:

| Agent | Layer file | Attention |
| :--- | :--- | :--- |
| API Semantics | [references/api-semantics.md](references/api-semantics.md) | *the foundation; scrutinize hardest* |
| Implementation Semantics | [references/implementation-semantics.md](references/implementation-semantics.md) | *correctness/robustness; scrutinize hard* — also reads git blame/history |
| Documentation | [references/documentation.md](references/documentation.md) | *moderate* |
| Tests | [references/tests.md](references/tests.md) | *moderate; don't merely count coverage* |
| Code Style | [references/code-style.md](references/code-style.md) | *apex; skim, defer to tooling* |

**Prior-review agent (PR only).** Alongside the layer agents, launch one more to read the review comments on previous PRs that touched these files, and flag recurring guidance the current change repeats. Bucket its findings into whichever layer they belong to.

## Severity model (pyramid-weighted)

Severity is capped by layer: a problem can only be as serious as its place in the pyramid allows. This is what keeps style from outranking correctness.

- **[Blocking]** — must fix before merge. Reachable *only* from **API** or **Implementation** semantics: correctness/data-loss bugs, security holes, breaking changes, serious robustness failures.
- **[Important]** — should be addressed; reviewer should weigh in. Non-blocking API/impl concerns; missing tests for risky logic; missing docs for new public API.
- **[Suggestion]** — worth considering. Minor implementation improvements; test/doc gaps on low-risk code.
- **[Note]** — never blocking. Style and readability only — and only when it survived the "would a linter catch this?" filter above.

## What not to flag

Reviews lose trust fast when they cry wolf. Stay silent on:
- Pre-existing issues on lines this change didn't touch.
- Anything CI already owns: formatting, import order, type errors, lint rules, failing builds. Don't run builds/typechecks yourself; assume they run separately.
- Pedantic nits a senior engineer would let slide.
- Issues flagged from `CLAUDE.md` that are explicitly silenced in the code (e.g. a lint-ignore comment).
- General code-quality gripes (sparse coverage, broad security posture, thin docs) unless a convention file explicitly requires otherwise.
- Changes that are plainly intentional or part of the stated scope.
- Speculative concerns you can't tie to real code — verify before raising, and if you're unsure, say so rather than asserting.

## Step 4 — Confidence-score every finding, drop the weak ones

Pool the findings from Step 3 and confidence-score each one with a **parallel fast (Sonnet) agent** — one per finding. Give the agent the change, the finding's description, and the convention-file paths, and ask it to rate its confidence that the issue is **real (not a false positive)** on a 0–100 scale. For a finding flagged because of a `CLAUDE.md` rule, the agent must double-check that the `CLAUDE.md` actually calls out that issue specifically. Use this rubric verbatim:

- **0** — Not confident at all. This is a false positive that doesn't stand up to light scrutiny, or is a pre-existing issue.
- **25** — Somewhat confident. This might be a real issue, but may also be a false positive. The agent wasn't able to verify that it's a real issue. If the issue is stylistic, it is one that was not explicitly called out in the relevant `CLAUDE.md`.
- **50** — Moderately confident. The agent was able to verify this is a real issue, but it might be a nitpick or not happen very often in practice. Relative to the rest of the change, it's not very important.
- **75** — Highly confident. The agent double checked the issue, and verified that it is very likely a real issue that will be hit in practice. The existing approach in the change is insufficient. The issue is very important and will directly impact the code's functionality, or it is an issue that is directly mentioned in the relevant `CLAUDE.md`.
- **100** — Absolutely certain. The agent double checked the issue, and confirmed that it is definitely a real issue, that will happen frequently in practice. The evidence directly confirms this.

**Drop every finding scored below 80.** If nothing clears the bar, don't manufacture findings — report a clean result (see below). The surviving findings keep their layer-capped severity from Step 3; the score was only a gate to get here, so don't print it in the report.

## Step 5 — Report (terminal, pyramid-ordered)

Print a terminal report, most important first. Lead with a verdict so the reader knows the stakes in one line, then layers in base-to-apex order. Omit a layer that's clean rather than padding it, but always confirm you looked.

```
# Code review — <target>

**Verdict:** <one line — e.g. "1 blocking issue: the export endpoint drops the
last record. Implementation is otherwise solid; tests are thin around errors.">

## API Semantics
- **[Blocking]** `path/file.ext:120` — <what's wrong> · <why it matters> · <suggested fix>
- **[Important]** `path/file.ext:88` — ...

## Implementation Semantics
- **[Blocking]** `path/file.ext:54` — ...

## Documentation
- **[Suggestion]** `README.md` — ...

## Tests
- **[Important]** `path/test.ext` — ...

## Code Style
- No blocking style concerns; assuming formatter/linter run in CI.

---
**Totals:** 1 blocking · 2 important · 1 suggestion · 0 notes
```

Cite `file:line` for every finding so it's clickable, keep each finding to a tight what / why / fix, and skip emojis. If the change is clean, say so plainly — "No issues across the pyramid; checked API, implementation, docs, tests, and style" — rather than inventing problems to look thorough.

## Step 6 — Offer to post to the PR (PR only)

After printing, if the target was a PR, **ask** whether to post the review back as a comment (e.g. "Want me to post this to PR #214?"). Don't post unprompted — publishing to a PR is outward-facing and the user may just want the terminal read. Skip this entirely for local diffs.

If they say yes, re-run the Step 2 eligibility check first (state may have changed since you started), then comment with `gh pr comment`. The posted comment keeps the pyramid grouping, but because `file:line` isn't clickable in a GitHub comment, **every cited line must be a full-SHA permalink**:

```
https://github.com/<owner>/<repo>/blob/<full-sha>/path/to/file#L<start>-L<end>
```

- Get `<owner>/<repo>` and the head `<full-sha>` from `gh` (e.g. `gh pr view <n> --json headRepository,headRepositoryOwner,headRefOid`). The repo must match the one you're reviewing.
- Use the **full** 40-char SHA — not `$(git rev-parse HEAD)` interpolation; the comment renders as static Markdown, so a command won't run.
- Note the `#` after the filename and the `L<start>-L<end>` range. Provide at least one line of context on each side (to comment on line 120, link `#L119-L121`).

Keep the comment brief, cite/link every finding, no emojis except the footer. End with:

```
🤖 Generated with [Claude Code](https://claude.ai/code)

```

If no findings survived Step 4, the comment is simply:

```
### Code review

No issues found. Checked for bugs and CLAUDE.md compliance across the review pyramid.

🤖 Generated with [Claude Code](https://claude.ai/code)
```
