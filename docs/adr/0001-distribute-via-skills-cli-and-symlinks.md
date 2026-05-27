# Distribute via the vercel-labs `skills` CLI and symlinks, not a Claude plugin marketplace

We distribute these skills with the vercel-labs [`skills`](https://github.com/vercel-labs/skills) CLI (`npx skills add fm1randa/skills`). The repo working tree is the source of truth; the CLI installs a copy into each agent's skills directory, tracked in `skills-lock.json` and refreshed with `skills add` / `skills update` (it does not symlink to the working tree).

We chose this over Claude's native plugin marketplace (`.claude-plugin/marketplace.json`) because the CLI and the Agent Skills format are cross-agent (Claude Code, Cursor, Codex, Gemini CLI) and it needs no manifest. The trade-off: we depend on a third-party CLI, forgo Claude-native plugin versioning, and accept that installs are copies (re-sync after editing) rather than live symlinks to the working tree. It is reversible only at the cost of changing everyone's install instructions, which is why it is recorded here.
