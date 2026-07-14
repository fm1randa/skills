---
name: recon
description: >-
  Runs recon on an Agidesk task: fans out one researcher agent per source —
  Agidesk, Slack, Google Drive, and (for bugs) Datadog — and consolidates their
  findings into one context brief. Use when the user wants to gather context on,
  research, or get up to speed on a task before working it, or gives a task ID
  and wants background pulled from every source.
---

# Recon

Sweep every source for everything known about a task before you touch it. Recon is done when the picture is complete: every source swept, every attachment and image and video in the task actually opened and seen, every related task noted, and anything you could not retrieve flagged to the user rather than silently skipped.

## How recon runs

One researcher agent per source. Hand each agent the reference file for its source and let it work the recipe there.

1. **Identify the task.** Run recon on the task `$ARGUMENTS` (a task ID, URL, or short description). If `$ARGUMENTS` is blank and the user gave no task another way, ask for it before doing anything else.
2. **Launch Agidesk recon first** — see [references/agidesk.md](references/agidesk.md). It is the spine of the recon: it establishes what the task is actually about, who is involved, the timeline, and the related tasks.
3. **With the Agidesk findings in hand, launch Slack and Google Drive recon in parallel** — [references/slack.md](references/slack.md) and [references/google-drive.md](references/google-drive.md). Brief each agent richly with specifics the Agidesk agent surfaced: the task ID, key terms and product areas, the people named, the creation date, and any related task IDs. A generic brief finds nothing; a specific one finds the conversation.
4. **If the task is a bug, also launch Datadog recon** — [references/datadog.md](references/datadog.md). Skip it otherwise.
5. **Consolidate** every agent's findings into one brief, organized by source, that calls out the cross-source connections (a Slack thread that explains an Agidesk comment, a Meet note that predates the task) and lists explicitly anything that could not be retrieved.

## Rules of engagement

- **On an MCP error, stop and report it** so the user can fix the MCP, then wait. Do not invent a workaround or reach for a non-MCP tool to route around a broken MCP. (Google Drive has one sanctioned exception, stated in its reference file. And the Agidesk `secret_key` download is not a fallback — its reference file explains why.)
- **When you are blocked on something you were explicitly told to get** — an image whose `secret_key` URL 403s, a file with no reachable link even after following the Agidesk recipe — do not quietly drop it. Flag it to the user with what you tried, so they can ignore it or hand you the file directly.
