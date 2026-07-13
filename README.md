# skills

A personal collection of [Agent Skills](https://agentskills.io) — portable, version-controlled instructions that extend skills-compatible agents (Claude Code, Cursor, Codex, and others).

## Install

Install every skill into your agent with the [`skills`](https://github.com/vercel-labs/skills) CLI:

```bash
npx skills add fm1randa/skills
```

Or a single skill by its path:

```bash
npx skills add https://github.com/fm1randa/skills/tree/main/skills/code-review-pyramid
```

The CLI installs a *copy* into your agent's skills directory rather than symlinking, so re-run the command (or `npx skills update`) to pull in updates.

## Skills

| Skill | What it does |
| :--- | :--- |
| [code-review-pyramid](skills/code-review-pyramid/) | Code review organized by Gunnar Morling's Code Review Pyramid — parallel per-layer agent fan-out, confidence-scored findings, severity capped by pyramid layer. |
| [recon](skills/recon/) | Gathers context on an Agidesk task by fanning out one researcher agent per source (Agidesk, Slack, Google Drive, and Datadog for bugs) into a single context brief. |
| [open-pr](skills/open-pr/) | Opens a pull request with a short, high-level description following a fixed convention — confirms the base branch and links the related task as Fixes/Closes/Addresses. |
| [feedback](skills/feedback/) | Drafts a short, low-jargon findings message in Brazilian Portuguese as raw HTML, following a fixed template with hyperlinked PRs. |

## Local development

This repo is the **source of truth** — author and commit skills here. The `skills` CLI installs a *copy* into your agent's skills directory (for Claude Code, `~/.claude/skills`); it does not symlink to this working tree, so re-sync after editing:

```bash
git clone https://github.com/fm1randa/skills ~/Repositories/skills
cd ~/Repositories/skills

# Install / refresh from your local working tree (Claude Code only):
npx skills add ~/Repositories/skills --agent claude-code -g -y
```

Because the CLI copies rather than symlinking to the working tree, re-run that command (or `npx skills update`) after each edit to pick up changes. See [CLAUDE.md](CLAUDE.md) for authoring conventions and [CONTEXT.md](CONTEXT.md) for the vocabulary.

## Credits

The `code-review-pyramid` skill bundles "The Code Review Pyramid" diagram by [Gunnar Morling](https://www.morling.dev/blog/the-code-review-pyramid/), © @gunnarmorling, licensed CC BY-SA 4.0 and included unchanged. See the [attribution note](skills/code-review-pyramid/references/code-review-pyramid.svg.LICENSE.md).

## License

[MIT](LICENSE) © Filipe Miranda. Bundled third-party assets retain their own licenses (see Credits).
