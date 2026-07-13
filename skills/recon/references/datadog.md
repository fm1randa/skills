# Datadog recon (bugs only)

Only run this when the task is a bug. Use the Datadog MCP to gather data about it.

Datadog is enabled for **both the backend and the frontend**, not only Agitalks. Other agents fail here by assuming Datadog only covers Agitalks — it covers Agidesk too.

- **Backend** → APM (spans), the `codeigniter` service (display name "agidesk").
- **Frontend** → RUM, `@application.name:agidesk-front`.
