# Layer: Implementation Semantics

**Second from the base — scrutinize hard.** This is correctness and robustness: does the code actually do the right thing, safely, under the inputs and conditions it will really see? Read the changed files in full and follow the call sites. This agent also reads the **git blame/history** of the modified regions, because some correctness bugs are only visible in light of what the code used to do and why it changed.

## Questions to ask

These are the canonical questions from the [Code Review Pyramid](https://www.morling.dev/blog/the-code-review-pyramid/) (see [code-review-pyramid.svg](code-review-pyramid.svg)):

- Does it satisfy the original requirements?
- Is it logically correct?
- Is there no unnecessary complexity?
- Is it robust (no concurrency issues, proper error handling, etc.)?
- Is it performant?
- Is it secure (e.g. no SQL injections, etc.)
- Is it observable (e.g. metrics, logging, tracing, etc.)?
- Do newly added dependencies pull their weight? Is their license acceptable?

## Notes for the reviewer

- **Requirements.** Anchor on the stated intent (PR description, linked issue, commits). The first question is always *does this do what it was supposed to?*
- **Logical correctness.** Walk the edge cases yourself: boundaries, empty/null inputs, error paths, the off-by-one. A green diff can still be wrong.
- **Unnecessary complexity.** Is it reinventing something the codebase, framework, or stdlib already provides? In Agidesk, check for a re-implemented helper/model method that already exists before flagging *or* praising.
- **Robustness.** Concurrency/race safety, resource cleanup, and error handling that isn't silently swallowed. A caught exception that's logged-and-ignored on a critical path is a finding.
- **Performance red flags.** N+1 queries (very common in CodeIgniter model loops), work inside hot loops, unbounded memory growth. Don't micro-optimize, but call out the structural ones.
- **Security.** SQL/command injection, missing authorization checks, unsafe deserialization, secrets in code or logs, unescaped user input. These usually land at [Blocking].
- **Observability.** Important paths should have the logging/metrics/tracing that lets someone debug them in production. Missing it on a critical new path is worth a note; absence on trivial code is not.
- **Dependencies.** A newly added dependency should pull its weight, and its license should be acceptable for the project.

## Severity ceiling for this layer

Findings here can reach **[Blocking]** (correctness/data-loss bugs, security holes, serious robustness failures), **[Important]**, or **[Suggestion]**. This and API Semantics are the *only* two layers that can produce a [Blocking] finding.
