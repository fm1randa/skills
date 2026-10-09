# Pause as a sentinel file in the state root

Pause silences the Reminder hook in every session at once and, on resume, puts each session back where it was. It is stored as a file, `paused`, in the state root next to `settings.json`: while the file exists, the Pause holds; when it is absent, it does not. Its content is ignored; writers put an ISO-8601 timestamp in it so a human who finds the file can tell when the Pause began. `remind.sh` checks for the file before anything else, the JSON backend included, and then does nothing at all: no reminder, no attachment fingerprint, no pruning. `/output-language pause` creates the file and `resume` removes it, and so does Aidiom. Neither needs `settings.json`, and neither touches it. Quitting Aidiom changes nothing, because the hook never depended on the app.

Creating a file and removing one are each a single atomic step, so two writers cannot lose each other's Pause, and `settings.json` keeps a single program writer, Aidiom.

## Considered Options

- **A `"disabled": true` key at the top of `settings.json`.** This was the first design. Both the skill and Aidiom then wrote `settings.json` the same way: read it, merge one change, rename a temp file over it. A write that lands between one writer's read and its rename is lost, so an Aidiom profile save could silently drop a Pause the skill had just written, or bring back one it had just removed. It also forced every client to carry a key it does not own: a version of Aidiom that did not know the key dropped it on its next save.
- **Advisory locking around `settings.json`.** There is no shared primitive on a stock macOS: `flock(1)` is not installed, so bash with jq has nothing that Swift's `flock(2)` or `NSFileCoordinator` would respect. A lock also binds only the programs that take it, never a hand edit in a text editor.
- **A `disabled` Session Lock in every session.** It would need no new file, but it overwrites what each lock held, so resuming could not restore pinned profiles. It also misses sessions that start while everything is paused.
- **A built-in "off" profile with no instruction, set as the Default Profile.** The hook already stays silent for it, but it only reaches sessions that follow the default; pinned sessions keep injecting.
- **Removing the hook from `~/.claude/settings.json`.** That would make the skill and Aidiom edit Claude Code's own configuration. Running sessions might not notice, and a failure halfway would leave the hook gone with no sign of it.

## Consequences

The state root holds one more file, and its meaning is its existence alone, so it needs no parser: the hook stays silent while paused even on a machine with no JSON backend. `pause` and `resume` work with a missing or malformed `settings.json`, since they never read it. A file manager or `touch`/`rm` is enough to pause and resume by hand.
