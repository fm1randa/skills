---
name: open-pr
description: Opens a pull request with a short, high-level, non-technical description following a fixed convention. Confirms the base branch before proceeding, and links the related task as "Fixes" (bug fix), "Closes"/"Addresses" (feature), asking the user when the branch or task reference is unclear. Use whenever the user asks to open, create, or raise a PR.
---

open a PR.
before proceeding, determine the target base branch from the conversation context and ask the user to confirm it. if it cannot be inferred, ask the user to provide it. do not continue until the branch is confirmed.
write the PR description as one short and concise sentence explaining what was done and why at a high level. do not include markdown titles, test plan, or "summary of changes". keep it simple and not overly technical.
no need to be so technical and descriptive in the PR description. keep it short and just explain what happened in a high level so people understand it quickly.
determine from the context whether this is a bug fix or a feature:
* if it is a bug fix, include "Fixes X" with a link to the related task
* if it is a feature, include "Closes X" (or “Addresses X” if it doesn’t close but is related) with a link to the related task
* if there is no clear related task in the context, ask the user whether to include one and which reference to use before proceeding
use backticks (`) to highlight code pieces in the PR description when relevant.
When asking, use question tool.
