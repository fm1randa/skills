# Working in this repo

This is a personal collection of **Agent Skills** (see [CONTEXT.md](CONTEXT.md) for the vocabulary). Skills live in `skills/<name>/`, each with a `SKILL.md` and optional `references/`, `scripts/`, `assets/`. They are distributed with the vercel-labs `skills` CLI — there is **no** Claude plugin or marketplace here (see [ADR 0001](docs/adr/0001-distribute-via-skills-cli-and-symlinks.md)).

## Source of truth

The repo working tree is canonical — author and commit skills here. The `skills` CLI installs a **copy** into the agent (it does not symlink to this working tree), so after editing or adding a skill, re-sync your machine with `npx skills add ~/Repositories/skills --agent claude-code -g -y` (or `npx skills update`). On other machines or for others, install from the published repo: `npx skills add fm1randa/skills`.

## Authoring conventions

- **SKILL.md frontmatter** needs `name` and `description`. The description is the trigger — make it specific and slightly pushy about *when* to use the skill, and state *what* it does. All "when to use" guidance belongs in the description, not the body.
- **Keep SKILL.md focused** (aim under ~500 lines). Move depth into `references/` and point to it from SKILL.md so it loads only when needed (progressive disclosure).
- **English only. No emojis.** Prefer self-documenting prose over ceremony.
- **Stay self-contained.** A skill should work offline; bundle the assets it depends on.
- **Third-party assets keep their own license**, and an attribution note travels with them (see [ADR 0002](docs/adr/0002-bundle-cc-by-sa-asset-in-mit-repo.md)).
- For building and iterating on skills, the `skill-creator` skill is the workflow.

## Don't

- Don't add `.claude-plugin/marketplace.json` or restructure into Plugins — distribution is the `skills` CLI by design (ADR 0001).
- Don't edit the installed copy in `~/.claude/skills` directly — it's derived. Edit the skill here, then re-sync.
