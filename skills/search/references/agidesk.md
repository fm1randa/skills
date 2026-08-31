# Agidesk

Use the Agidesk MCP: prefer OAuth, fall back to the API key. Both are the same MCP — the API key is the second authentication route, not a second tool.

There is no alternative to this MCP. When it errors or is unavailable, stop and report it so the user can fix it, then wait.

## Sweeping for an answer

Search by the terms from the expansion, and then narrow by the axes the question implies:

- **Assignee** — when identity was resolved, everything assigned to that person, and separately everything where they are named in a comment but not assigned. The second set is where "someone is waiting on you" hides.
- **State and age** — open, blocked, waiting on a customer, untouched for weeks. A task waiting on someone else is not a task you can pick up, and the answer should say so rather than list it.
- **Recency** — who last touched it and when. A task nobody has moved in a month means something different from one edited yesterday.
- **Type** — bug, tech debt, feature. Questions about "what to pick up" are usually really about one of these.

Report each hit as ID, title, type, state, assignee, last activity, and one line on what it is about. That line is what the other surfaces will search for.

## Attachments

Open an attachment only when the answer depends on what is inside it. (`/recon` opens all of them; here that is usually wasted work.)

When you do need one, the MCP does **not** expose binary download — the file endpoints return metadata only, with an empty `content`. Use this recipe:

1. Get the raw comment bodies with `agidesk_api_request GET /tasks/{id}/comments` and parse each `htmlcontent`. Inline images live in `<img src="...">`; file and video links live in `<a href="...">`. PDFs and other attachments come as `file.path` (no `secret_key`).
2. Inline images carry a tokenized URL: `https://atendimento.agidesk.com/uploads/.../N.png?secret_key=...`. Download each one by URL (`curl -sSL -o file.png "<url>"`) and then read the downloaded file to actually **see** it. PDFs download the same way from their `file.path` even though they have no `secret_key`.
3. Do **not** try `/api/v1/files/{id}/download` — it returns HTTP 400 (no tokenized URL via MCP). The tokenized `?secret_key=` URL from the `htmlcontent` is the working path.
4. For Jam videos (jam.dev links found in comments), use the Jam MCP: `getDetails` first, then `analyzeVideo` for a per-intent step reconstruction (mic-off recordings have no transcript, so the intent analysis is the source), and `getScreenshots` for screenshot-type Jams.

Fetching the `secret_key` URL by curl is **not** falling off the MCP: the URL itself came from the Agidesk MCP, and the download is just how that MCP-provided link is opened.
