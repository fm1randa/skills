# Pause every session with one key in `settings.json`, checked before anything else

Pause silences the Reminder hook in every session at once and, on resume, puts each session back where it was. It is stored as `"disabled": true` at the top of `settings.json`, the same key and the same reading (`true` or `"true"`) as the `disabled` Session Lock. `remind.sh` checks it first and then does nothing at all: no reminder, no attachment fingerprint, no pruning. `/output-language pause` and `resume` write it, and so does Aidiom. Quitting Aidiom changes nothing, because the hook never depended on the app.

## Considered Options

- **A `disabled` Session Lock in every session.** It would need no new key, but it overwrites what each lock held, so resuming could not restore pinned profiles. It also misses sessions that start while everything is paused.
- **A built-in "off" profile with no instruction, set as the Default Profile.** The hook already stays silent for it, but it only reaches sessions that follow the default; pinned sessions keep injecting.
- **Removing the hook from `~/.claude/settings.json`.** That would make the skill and Aidiom edit Claude Code's own configuration. Running sessions might not notice, and a failure halfway would leave the hook gone with no sign of it.

## Consequences

`settings.json` now has a third top-level key, so every writer must keep it. Aidiom rewrites the whole file from its own model, and a version that does not know the key drops it on the next save.
