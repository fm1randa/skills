# Datadog

Use the Datadog MCP. It ships skill guides — discover them with `list_datadog_skills` and load the ones that match before reaching for the query tools.

Datadog is enabled for **both the backend and the frontend**, not only Agitalks. Agents fail here by assuming Datadog only covers Agitalks — it covers Agidesk too.

- **Backend** — APM spans, the `codeigniter` service (display name "agidesk").
- **Frontend** — RUM, `@application.name:agidesk-front`.

## Sweeping for an answer

- **Start with monitors and incidents** when the question is "is something broken". `search_datadog_monitors` and `search_datadog_incidents` answer that in one call; logs and spans answer "why".
- **Then errors in the window**, on both sides. An error the frontend reports and the backend does not is a different bug from one both see.
- **Bound every query by the window** from the expansion. An unbounded log search returns volume, not evidence.
- **Report magnitude, not just presence.** "12 errors in 14 days, all one customer" and "12 errors an hour" answer the question differently.

## Reporting

Each finding as: what broke, which side (backend/frontend), first and last seen, count, and a link to the query or dashboard. When nothing shows up, say that explicitly — a clean window is evidence that the problem is not in production.
