# Layer: Tests

**Upper-middle of the pyramid — moderate attention.** Don't merely count coverage; judge whether the *right* things are tested at the *right* level. A risky change with no guarding test is the finding that matters here.

## Questions to ask

These are the canonical questions from the [Code Review Pyramid](https://www.morling.dev/blog/the-code-review-pyramid/) (see [code-review-pyramid.svg](code-review-pyramid.svg)):

- Are all tests passing?
- Are new features reasonably tested?
- Are corner cases tested?
- Is it using unit tests where possible, integration tests where necessary?
- Are there tests for NFRs, e.g. performance?

## Notes for the reviewer

- **Passing.** Assume CI runs the suite — don't run it yourself. Only raise "tests passing" if the diff itself shows a test left broken or obviously stubbed out.
- **Meaningful coverage, not line coverage.** New/changed behavior should be tested for what it does, including the corner cases (empty, boundary, error). A test that asserts nothing meaningful is worse than none.
- **Right level.** Unit tests where the logic is pure; integration tests only where the interaction is the point. Flag a slow integration test written for logic that a unit test would cover faster. In Agidesk the stacks are Vitest (React + legacy JS) and PHPUnit (PHP helpers) — match the test to the unit under test.
- **The dangerous gap.** The highest-value finding: something risky changed and *no* test would catch its regression. Name the specific behavior left unguarded.
- **NFRs.** If the change has a performance or other non-functional requirement, is there a test that protects it where one is warranted?

## Severity ceiling for this layer

Findings here cap at **[Important]** (missing tests for genuinely risky logic) and below — otherwise **[Suggestion]**. Test gaps are never [Blocking] on their own; if the untested code is also wrong, that belongs to Implementation Semantics.
