# Home-relative attachments, listed only when present

A profile's `attachments` entry is either an absolute path (`/...`) or a home-relative one (`~/...`). The Reminder hook resolves `~/` against `$HOME` on the machine it runs on, then lists only the paths that exist as files there. A missing file is left out without a word, and a profile with none left behaves as one with no attachments. The attachment fingerprint (ADR 0005) is computed over the resolved paths the hook actually listed. Any other entry (a relative path, `~user/...`, a non-string) is ignored.

`settings.json` is synced across the user's machines, a Mac and two Linux hosts, whose homes differ (`/Users/filipe` and `/home/filipe`). An absolute Mac path names nothing on Linux, so the hook would ask the Agent to read files it cannot open. A file can also be present on one machine and never copied to another, which is a legitimate state rather than an error.

The resolution happens once, in `json_profile_attachments`, after either JSON backend has read the entries, so jq and python3 cannot disagree on it.

## Considered Options

- **One `settings.json` per machine.** It defeats the sync: every profile edit would have to be made on each machine.
- **Paths relative to the state root, or a configurable attachments directory.** Either adds a second root to keep in step across machines, where `$HOME` already is that root.
- **List missing files anyway, or warn about them.** The Agent would spend a turn failing to open them, on every machine that lacks the file, for a state the user chose.

## Consequences

Aidiom should write a file under the home as `~/...` so the entry travels; absolute paths still work on the machine they name. The same `settings.json` can ask for different attachments on different machines, and copying a missing file onto a machine changes the fingerprint, so the hook asks once more on the next turn of each session there. Checking that a file exists is a shell builtin test per listed entry, negligible next to the JSON read.
