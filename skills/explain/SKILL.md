---
name: explain
description: >-
  Produce a rich, self-contained interactive HTML explanation that builds real
  understanding of something the reader does not yet grasp: a concept or
  technique, a domain, a system or surface, or a code change (diff, branch, or
  PR). Use when the user asks you to explain X, says they do not understand X,
  or wants intuition, background, diagrams, and a comprehension quiz for a
  subject, saved as a dated HTML file outside the repo.
argument-hint: "[what to explain]"
---

# Explain

Understanding is the bottleneck. As agents generate more than anyone can read, the scarce resource is a human's grasp of what a system does — and that grasp is built not to rubber-stamp the work but **to participate**: to propose the next move, notice what is wrong, and stay a creative partner in the loop. Turn a subject the reader does not yet grasp into a page that leaves them able to reason about it and act on it.

Two principles run through everything below: **intuition before detail**, and a quiz that acts as a **speed regulator** — the reader earns their understanding before moving on.

## Workflow

1. **Pin down the subject and its scope.** The subject is `$1` if given, otherwise the thing the user asked about. Classify it — concept, domain, system/surface, or code change — because that decides what you investigate and how the walkthrough is shaped (see the mapping in Page structure). If the target is ambiguous, pick the most likely reading and state that assumption on the page.
2. **Investigate before explaining.** Read the real evidence: for code, the diff plus surrounding callers, tests, data models, and config; for a concept or domain, the authoritative sources, checked-in examples, and how it is actually used here. Trace far enough to explain *behavior and essence*, not a surface tour. Completion: every claim the page will make traces to something you actually read, not a guess.
3. **Build the mental model before writing HTML.** Draft, for yourself, the narrative arc: what problem or question motivates the subject; the smallest useful model of how it works; how the details realize that model; the edge cases, trade-offs, and consequences that follow. If you cannot yet tell that story plainly, investigate more — do not paper over gaps with prose.
4. **Write the output as one self-contained HTML file.** Inline all CSS and JavaScript; depend on no external fonts, CDNs, images, packages, or network. Save it outside the code repository at a dated path like `/tmp/YYYY-MM-DD-explanation-<slug>.html` (today's date, `YYYY-MM-DD`) so the files stay time-sorted and out of version control.
5. **Validate the artifact before handoff.** Confirm the file exists and is a complete HTML document; that it loads no external assets; that every quiz question reveals correct/incorrect feedback on click; that every code block's CSS carries `white-space: pre` or `pre-wrap`; and that the quiz passes the balance check below.

## Page structure

One continuous page (no top-level tabs) with a title, a one-paragraph summary, and a table of contents linking these sections in order:

1. **Background** — only the context the change or subject needs. Open with an optional beginner-friendly mental model that a knowledgeable reader can skip, then narrow to the exact pieces, contracts, and prior state involved.
2. **Intuition** — the core idea before any implementation detail, on small concrete toy inputs and outputs. Where a comparison sharpens it, show before and after.
3. **Walkthrough** — the substance, in conceptual groups ordered by how things flow, not by file order or arbitrary sequence. Shape it to the subject:
   - **code change** — the changes grouped by execution or dependency flow, with precise file and line references; explain the diff, do not dump it.
   - **concept / technique** — how it works from first principles, each layer building on the last.
   - **domain** — the map: the entities, their relationships, and the vocabulary, so the reader can navigate the space.
   - **system / surface** — the components, boundaries, and contracts, and how data or control moves across them.
4. **Quiz** — exactly five interactive multiple-choice questions (rules below).
5. **Where this leads** — close by pointing at what the reader can now *do*: the decisions this understanding unlocks, plausible next moves, and the open questions worth their judgment. This is the participation payoff — understanding exists to feed ideation.

Use plain, precise, systems-oriented prose with smooth transitions; explain jargon on first use; use callouts for definitions, invariants, edge cases, and consequences; and keep it readable on a phone with responsive CSS.

## Diagrams and micro-worlds

Reach for a small, reusable set of HTML/CSS patterns rather than ornamental graphics: flow diagrams for requests/data/control, before/after panels for changes, labeled component cards for boundaries, and compact tables for mappings and toy data. Build every diagram from semantic HTML and CSS — never ASCII art — label arrows, include example values whenever a diagram shows data moving, and give each a caption so the point survives without close visual inspection.

When the subject has behavior a reader learns best by *poking at it* — a formula, a state machine, an algorithm, a UI interaction — add a small interactive **micro-world**: a self-contained widget where they change an input and watch the output respond. A playground builds intuition that a static figure cannot.

## Quiz quality rules

The quiz is the speed regulator: it only works if answering demands real understanding. Inspect all five questions as a set before emitting the page.

- Ask about behavior, causality, contracts, edge cases, or trade-offs — things a reader can answer only by understanding the subject, not by copying one phrase off the page.
- Make every distractor plausible and tied to a real misunderstanding. Keep options comparable in length, grammar, specificity, and confidence, so the correct one is never the conspicuously longer or more precise choice. Skip joke answers, "all/none of the above," and trivia the page never covers.
- Decouple the visible option order from the order you authored the options in, with a genuine per-page shuffle, so the answer is never betrayed by an authoring habit (correct-answer-first, correct-answer-longest). Natural clustering from an honest shuffle is fine; do not hand-tune the layout toward an even spread, which only trades one predictable pattern for another.
- Reveal feedback only after selection, and keep the answer and explanation in the page's JavaScript or DOM so it works offline. On click, mark the choice and explain both the right reasoning and, when useful, the misconception behind the distractor.
- Keep correctness invisible before selection — not leaked through styling, source order, `title` attributes, or accessibility text. Accessibility labels describe the option, never its correctness.

## HTML and code-block constraints

- Escape any code- or user-derived text for its HTML and JavaScript context, and preserve meaningful whitespace in examples.
- Put code in `<pre><code>...</code></pre>`, and give `pre` an explicit `white-space: pre` or `pre-wrap`; check every block in the saved source before delivery.
- Keep JavaScript small, namespaced, and dependency-free, using event listeners over inline handlers and handling repeated quiz cards without fragile global selectors.
- Include visible focus states and sufficient contrast; keep meaning legible without relying on color alone.
- Ground every claim in what you actually inspected, and mark reasonable interpretation as interpretation rather than stated fact.

## Handoff

Return the absolute path to the file as a clickable local-file link, say briefly what you inspected, and name any assumptions or validation limits. Keep the deliverable outside the code repository unless the user asks otherwise.
