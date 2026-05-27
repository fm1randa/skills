# Layer: Documentation

**Middle of the pyramid — moderate attention.** Docs matter, but a doc gap is cheaper to fix later than a bad API or a correctness bug. Give this a solid but not exhaustive pass.

## Questions to ask

These are the canonical questions from the [Code Review Pyramid](https://www.morling.dev/blog/the-code-review-pyramid/) (see [code-review-pyramid.svg](code-review-pyramid.svg)):

- New features reasonably documented?
- Are the relevant kinds of docs covered: README, API docs, user guide, reference docs, etc.?
- Are docs understandable, are there no significant typos and grammar mistakes?

## Notes for the reviewer

- **Reasonably, not exhaustively.** New features and new public API should be documented enough that a reader can use them. Don't demand docs for internal refactors that change nothing user-facing.
- **The right kind for this change.** Match the doc type to the change: a README/user-guide update for a customer-facing feature, API/reference docs for a new endpoint, a changelog entry where the project keeps one. In Agidesk, a new REST endpoint generally implies a Swagger/OpenAPI annotation; user-facing strings imply the four-language translation requirement (PT-BR, EN, ES, PT-PT) — but treat the latter as Implementation/Style unless a doc file is the artifact in question.
- **Understandable.** Flag typos/grammar only when they would genuinely confuse a reader. A single misspelling in a comment is not worth a finding.

## Severity ceiling for this layer

Findings here cap at **[Important]** (missing docs for new public API) and below — typically **[Suggestion]**. Documentation gaps are never [Blocking].
