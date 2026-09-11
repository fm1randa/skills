---
name: spawn-implementer
description: >-
  Spawn one implementer session in a dedicated Herdr tab and hand it a slash
  command, usually /implement <task-id>. Use when the user asks to launch, spawn
  or fire off an implementer for a task, ticket or issue, or to run a slash
  command in its own tab. For driving a whole epic - board, review rounds,
  validation, pull request - orchestrate is the skill. Requires HERDR_ENV=1.
---

# Spawn an implementer

One tab, one implementer, one prompt. You start it and step away: the session
works on its own and the user watches it.

`herdr --skill` is the authority on the CLI - tab and pane IDs, `agent start`,
`agent prompt`, key handling. Read it instead of deriving any of that here.

## Steps

1. `test "${HERDR_ENV:-}" = 1`. On failure, say you are not inside Herdr and
   stop. There is no fallback.

2. **Name the tab.** Two or three words in kebab-case, from what the task is
   about: `fix-login-redirect`, not `task-770393`. Take the words from the
   conversation. When the task id arrives alone, with nothing said about it,
   read the title from the tracker - Agidesk MCP for a `TRF-` style id, `gh
   issue view` for a repo issue - and fall back to `impl-<id>` if neither
   answers. The same name goes on the tab label and on the agent.

3. **Pick the working directory.** Infer it from the conversation: the repo
   under discussion, or the current one when the task plainly belongs to it. Ask
   which directory it should run in when two repos are equally plausible.

4. **Create the tab**, keeping the user where they are:

   ```bash
   herdr tab create --cwd <dir> --label <name> --no-focus
   ```

   Read the root pane from `.result.root_pane.pane_id`.

5. **Start the implementer** in that pane:

   ```bash
   herdr agent start <name> --kind claude --pane <root-pane-id> -- --model opus --effort medium
   ```

   Read the pane footer afterwards: an effort flag can fail silently, and the
   quality of the work is how you would otherwise find out.

6. **Send the command alone**, as the whole message, with no preamble:

   ```bash
   herdr agent prompt <name> "/implement <task-id>"
   ```

   `/implement` carries `disable-model-invocation: true`: it loads only when it
   arrives as a typed command, so a sentence wrapped around it lands as prose
   and the session improvises without the skill. Send whatever command the user
   named instead, when they named one.

7. **Report the tab and agent name in one line**, then stop. The implementer
   owns the work from here.

## When the user asks you to keep watch

Start one persistent edge-triggered Monitor polling `herdr agent get <name>`,
reporting only the transitions - `idle`, `blocked`, `done`. Suppress `working`:
it arrives constantly and says nothing. Kill the Monitor with the tab.

Waiting turn after turn on `herdr agent wait` or on a sleep loop burns the
session and dies when the machine sleeps.
