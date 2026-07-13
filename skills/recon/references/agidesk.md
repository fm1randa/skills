# Agidesk recon

Use the Agidesk MCP (prefer OAuth, fall back to the API key). Gather context on the task itself and on related tasks — both the ones literally linked to it and the ones that may be related given what you understand about the task.

Read all attachments and see all images and videos referenced in the comments. The MCP does **not** expose binary download — the file endpoints return metadata only, with an empty `content`. Use this recipe instead.

1. Get the raw comment bodies with `agidesk_api_request GET /tasks/{id}/comments` and parse each `htmlcontent`. Inline images live in `<img src="...">`; file and video links live in `<a href="...">`. PDFs and other attachments come as `file.path` (no `secret_key`).
2. Inline images carry a tokenized URL: `https://atendimento.agidesk.com/uploads/.../N.png?secret_key=...`. Download each one by URL (`curl -sSL -o file.png "<url>"`) and then read the downloaded file to actually **see** it. PDFs download the same way from their `file.path` even though they have no `secret_key`.
3. Do **not** try `/api/v1/files/{id}/download` — it returns HTTP 400 (no tokenized URL via MCP). The tokenized `?secret_key=` URL from the `htmlcontent` is the working path.
4. For Jam videos (jam.dev links found in comments), use the Jam MCP: `getDetails` first, then `analyzeVideo` for a per-intent step reconstruction (mic-off recordings have no transcript, so the intent analysis is the source), and `getScreenshots` for screenshot-type Jams.

Fetching the `secret_key` URL by curl is **not** falling off the MCP: the URL itself came from the Agidesk MCP, and the download is just how that MCP-provided link is opened. Prefer this over any other route.
