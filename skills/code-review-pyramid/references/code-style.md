# Layer: Code Style

**The apex — skim, and mostly defer to tooling.** This is what a formatter, linter, and typechecker should be checking instead of a human. A style nit is fixed in one second and must never outrank a correctness problem. Spend the least effort here.

## Questions to ask

These are the canonical questions from the [Code Review Pyramid](https://www.morling.dev/blog/the-code-review-pyramid/) (see [code-review-pyramid.svg](code-review-pyramid.svg)):

- Is the project's formatting style applied?
- Does it adhere to agreed on naming conventions
- Is it DRY?
- Is the code sufficiently "readable" (method lengths, etc.)

## Notes for the reviewer

- **Assume a formatter, linter, and typechecker run in CI.** If a tool would catch it, say nothing. Formatting, import order, type errors, and lint rules are not your job here — they are owned by automation. In Agidesk that means Prettier/ESLint (React), php-cs-fixer + PHPStan (PHP), all wired into pre-commit/pre-push and CI.
- **Only raise style when both are true:** there's no automation for it, *and* it genuinely hurts readability — or it violates a convention explicitly written in `CLAUDE.md`/`CONTRIBUTING`. A naming choice the project's `CLAUDE.md` calls out by name is a legitimate finding; one that merely differs from your taste is not.
- **DRY with judgment.** Duplicated business logic is worth a note; two superficially similar lines that aren't actually the same concept are not.
- **Readability.** Excessive method length or nesting that obscures intent can be flagged, generously — but a senior engineer's "I'd let that slide" is the bar.

## Severity ceiling for this layer

Findings here cap at **[Note]** — never blocking — and only when they survived the "would a linter catch this?" filter above. A style finding only rises higher if a project convention file explicitly mandates the rule, in which case treat it as the convention violation it is.
