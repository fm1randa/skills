# Skills Collection

A personal, version-controlled collection of Agent Skills, distributed across skills-compatible agents. This glossary fixes the language of the skills ecosystem, which overloads several terms.

## Language

**Skill**:
A folder containing a `SKILL.md` that teaches an Agent a procedure or body of knowledge, loaded on demand.
_Avoid_: plugin, command, macro, prompt

**SKILL.md**:
The required entrypoint of a Skill — YAML frontmatter (`name`, `description`) plus markdown instructions.
_Avoid_: manifest, config

**Reference file**:
A supporting file under a Skill's `references/`, loaded only when the Skill needs it.
_Avoid_: doc, attachment

**Agent**:
A skills-compatible client (Claude Code, Cursor, Codex, Gemini CLI, and others) that discovers and runs Skills.
_Avoid_: bot, model, assistant

**Skills CLI**:
The vercel-labs `skills` tool (`npx skills add`) that installs a Skill into an Agent, by symlink.
_Avoid_: installer, package manager

**Source of truth**:
The Skill's directory in this repo's working tree — where it is authored and committed.
_Avoid_: canonical copy, the original

**Installed copy**:
What the Skills CLI places in an Agent's skills directory — a copy of the **Source of truth**, refreshed with `skills add` / `skills update`.
_Avoid_: "the skill" (it's derived, not the source)

**Plugin**:
Claude-native packaging (`.claude-plugin/`) that bundles Skills, commands, agents, and hooks. This repo does not use Plugins.
_Avoid_: using "plugin" to mean "Skill"

**Marketplace**:
A Claude-native registry of Plugins (`.claude-plugin/marketplace.json`). This repo does not use a Marketplace.

## Relationships

- A **Skill** contains exactly one **SKILL.md** and zero or more **Reference files**.
- The **Skills CLI** installs a **Skill** into an **Agent** by copying the **Source of truth** into an **Installed copy** (re-sync after edits).
- A **Plugin** may bundle **Skills**, but this repo distributes bare **Skills** — no **Plugin**, no **Marketplace**.

## Example dialogue

> **Filipe:** "Add the review thing as a plugin."
> **Claude:** "We don't ship Plugins here — this repo distributes bare **Skills** via the **Skills CLI**. I'll add it as a **Skill** under `skills/`, and `/code-review-pyramid` becomes the command that invokes it."

## Flagged ambiguities

- "skill" vs "plugin" vs "command" — resolved: we author **Skills**; "plugin"/"marketplace" are Claude-only packaging we deliberately don't use (see ADR 0001); "command" is merely how an **Agent** invokes a **Skill**.
- "canonical copy" implied Agents symlink to the repo — resolved: the **Skills CLI** *copies* the **Source of truth** into an **Installed copy**; the repo is the source, the Agent holds a derived copy.
