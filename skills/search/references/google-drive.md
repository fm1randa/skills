# Google Drive

Use the Google Drive MCP. If it is not connected at all, the `gws-work` CLI is the sanctioned alternative. (That is not routing around a broken MCP — it is the tool to use when the Drive MCP is absent.)

## Sweeping for an answer

- **Gemini Meet notes are the richest vein.** They carry the team talking through something before it ever became a task, with names and dates attached. Search them by the terms from the expansion and by the names the spine surfaced, inside the window.
- **Then decision documents** — specs, one-pagers, planning sheets. These answer "what did we decide" where Slack only answers "what did we say".
- **`list_recent_files` when the question is about now.** What was touched this week often is the answer to "what is the team on".
- **Open what matches.** `search_files` returns titles; a title is not evidence. Use `read_file_content` on every hit that plausibly bears on the question, and quote the line that does.

## Reporting

Each finding as: document title, kind (Meet notes, spec, sheet), date, link, and the passage that bears on the question. A Meet note that predates a task by a week is worth flagging as exactly that — the conversation that produced it.
