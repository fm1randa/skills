# Layer: API Semantics

**The base of the pyramid — scrutinize hardest.** A bad public API ships forever: once callers depend on it, walking it back is expensive and disruptive. This is where review effort pays off the most, so read slowly and read the surrounding code, not just the diff.

## Questions to ask

These are the canonical questions from the [Code Review Pyramid](https://www.morling.dev/blog/the-code-review-pyramid/) (see [code-review-pyramid.svg](code-review-pyramid.svg)):

- API as small as possible, as large as needed?
- Is there one way of doing one thing, not multiple ones?
- Is it consistent, does it follow the principle of least surprises?
- Clean split of API/internals, without internals leaking in the API?
- Are there no breaking changes to user-facing parts (API classes, configuration, metrics, log formats, etc.)?
- Is a new API generally useful and not overly specific?

## Notes for the reviewer

- **Surface area.** Anything that could be private should be. A smaller API is cheaper to keep stable. Flag newly-public surface that has no external caller.
- **One obvious way.** Watch for a new entry point that duplicates an existing one — two ways to do the same thing splits callers and invites drift.
- **Consistency / least surprise.** Names, argument order, return shapes, and error conventions should match the rest of the codebase. A method that returns `null` where its siblings throw, or orders args differently, is a real finding even if it "works."
- **No leaking internals.** Implementation types, internal state, or mutable internals exposed through the API are a long-term liability — callers will couple to them.
- **Breaking changes are almost always [Blocking].** Function/method signatures, config keys, CLI flags, serialized/persisted formats, metric names, and log formats are all contracts. In Agidesk this includes REST API controller responses, webhook payload shapes, and anything a customer integration or saved automation depends on. If a change alters one of these without a compatibility path, say so plainly.
- **General vs. overfit.** A new API shaped around exactly one caller's needs usually shouldn't be public yet.

## Severity ceiling for this layer

Findings here can reach **[Blocking]** (breaking changes, contract violations, leaked internals that will bite), **[Important]** (non-blocking shape/consistency concerns), or **[Suggestion]**. This and Implementation Semantics are the *only* two layers that can produce a [Blocking] finding.
