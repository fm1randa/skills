---
name: feedback
description: >-
  Drafts a short, low-jargon findings message in Brazilian Portuguese as raw
  HTML, following a fixed template with hyperlinked PRs. Use when the user
  wants to summarize what changed and how a task was approached, or mentions
  "feedback" / a findings message.
---

draft a short & concise message in ptbr explaining our findings and how we approached the task. no need to be too descriptive, people just need to read and understand quickly. Avoid technical terms but no need to be too non-technical - balance it.

Follow this template:  ```md
#### Como estava antes …
#### O que mudamos …
#### Onde se aplica …
#### PRs
* beta: #1859
* develop: #1860
```

Add hyperlink to PRs. Note for PRs: We use branches as environment. `beta` or `develop` (and also: `staging` and `main`) refer to specific environments. Output in raw HTML.
