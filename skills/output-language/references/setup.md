# Setup: state files and the reminder hook

The skill has two halves. A **file contract** under `~/.config/output-language`
holds the Default Profile, the named Language Profiles and one Session Lock per
session; an always-on **Reminder hook** (`scripts/remind.sh`) reads those files
every turn and re-injects the effective instruction, so the language holds even
when a foreign-language skill loads into context. `/output-language`
(`scripts/lock.sh`) only writes this session's lock file.

Because the hook reads the files directly, a session follows the Default Profile
from its very first reply, with no skill run at session start.

## State files

The root is `$XDG_CONFIG_HOME/output-language`, or `~/.config/output-language`
when `XDG_CONFIG_HOME` is unset. A **relative** `XDG_CONFIG_HOME` counts as
unset, per the XDG spec: honoring it would anchor the state to whatever
directory the hook happens to run in, giving every project its own state root.

### `settings.json`

```json
{
  "default": "en-ste",
  "profiles": [
    {
      "id": "en-ste",
      "short": "EN",
      "label": "English (STE)",
      "instruction": "American English, per ASD-STE100 Simplified Technical English",
      "attachments": ["/Users/you/Documents/ASD-STE100-Issue9.pdf"]
    }
  ]
}
```

`default` is the id of the Default Profile. `instruction` is an opaque
natural-language string — language plus any style guide — injected verbatim, so
it is the whole preference in one place. `short` is the two- or three-character
badge Aidiom shows. `attachments` holds absolute paths and may be empty or
absent.

There is no seed step in the skill: write this file by hand, or let Aidiom
create it on first start.

### `sessions/<session-id>.json`

The Session Lock, keyed by `CLAUDE_CODE_SESSION_ID`, so it holds for the whole
session and never leaks into another. When the file exists it holds one of
three states:

```
{ "profile": "pt-abnt" }        // pinned to a Language Profile
{ "instruction": "Japanese" }   // pinned to an ad hoc instruction, no attachments
{ "disabled": true }            // output-language off for this session
```

**No file at all is a fourth, implicit state**: the session follows the Default
Profile.
That is why `/output-language default` deletes the file instead of writing
something, and why `off` — which must also ignore the default — needs a state of
its own.

The hook may add `"attachmentsRequestedFor": "<fingerprint>"` to any of them, and
creates a file holding only that key when an inheriting session has attachments
to read. **A file with only a fingerprint still means "follows the default."**

Session files, and temp files left by an interrupted write, are deleted once they
go untouched for more than seven days. The sweep runs after a write, never on a plain
read — every `lock.sh` run, and in the hook only when it records an attachment
request — so a machine where nothing ever changes never prunes. The current
session's own file is always kept, however old.

## Resolution order

Every turn, the hook resolves in this order:

1. Session Lock with `"disabled": true` — stay silent for this session, the
   Default Profile included.
2. Session Lock with `"profile"` — that Language Profile and its attachments. A
   profile whose `instruction` is empty injects **nothing**; it does not borrow
   the default's text.
3. Session Lock with `"instruction"` — that text, verbatim. Never attachments:
   an ad hoc instruction belongs to no profile. An *empty* instruction is read as
   no lock at all and falls through to the default, unlike the empty profile
   instruction of step 2, which injects nothing.
4. No lock, **or a lock naming a profile that no longer exists** — the Default
   Profile from `settings.json`.
5. Nothing usable — exit silently, with no output.

A missing, malformed or unreadable `settings.json` reads as "nothing usable", so
the hook never blocks a prompt on a machine without the setup, or with a broken
file.

## Attachments, read once

When the effective profile carries attachments, the `UserPromptSubmit` message
also lists the paths and asks the Agent to read them before replying. The files
are never inlined into the hook output; the Agent reads them with its own
file-reading tool, which keeps the PDF out of every turn's context.

The ask happens **once per session and per attachment set**. The hook records a
fingerprint — the profile id and its sorted attachment paths, joined by newlines
rather than by punctuation, so that `["a|b"]` and `["a", "b"]` cannot fingerprint
alike — and asks again only when the fingerprint changes: a different profile, or the same profile with an edited attachment list.
Writing any lock through `lock.sh` rewrites the whole file and so drops the
fingerprint, which is what makes a relock re-read the new guide.

Only a real prompt can trigger the ask; the `PostToolUse` reminder stays a
reminder. A session with no id has nowhere to record the request, so the ask is
skipped there entirely.

## JSON backend

JSON is read and written with `jq` when it is on `PATH`, else with `python3`.
Both keep each read to one short-lived process, which matters because the hook
runs on every turn. Set `OUTPUT_LANGUAGE_JSON_BACKEND` to `jq` or `python3` to
force one — the test runner uses it to cover both. An explicit choice that the
machine cannot run is an error, not something to paper over: `lock.sh` then fails
loudly and `remind.sh` stays silent.

## Wire the hook

Skill-frontmatter hooks are discarded when the skill finishes, so the reminder
hook must live in your user settings — which the `skills` CLI does not manage.
This is a **one-time manual step per machine**.

Merge these entries into the `hooks` block of `~/.claude/settings.json` (keep
any hooks already there):

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$HOME/.claude/skills/output-language/scripts/remind.sh\" UserPromptSubmit"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Skill",
        "hooks": [
          {
            "type": "command",
            "command": "\"$HOME/.claude/skills/output-language/scripts/remind.sh\" PostToolUse"
          }
        ]
      }
    ]
  }
}
```

The commands point at the **installed copy** of `remind.sh`, which exists after
`npx skills add fm1randa/skills`. Re-run the install after editing the scripts so
the copy stays current.

`remind.sh` prints nothing when there is nothing to inject, so ordinary sessions
are untouched, and it never blocks a prompt or tool call. The `PostToolUse`
matcher `"Skill"` is what fires the reminder right after a skill loads.

Run the scripts' tests from the repo root: `bash skills/output-language/scripts/test.sh`.

## Migrating from the CLAUDE.md idiom

Earlier versions kept a per-session lock in `~/.claude/output-language/<sid>.lang`
and got their default from a line in `~/.claude/CLAUDE.md` that ran the skill at
every session start, attaching the style guide with an `@` mention.

Once `settings.json` exists:

- Delete the `/output-language <language>, per @<guide>.pdf` startup line from
  `~/.claude/CLAUDE.md`. The Default Profile replaces it, and leaving it in place
  pins every new session to an ad hoc instruction that carries no attachments.
- Delete the whole `~/.claude/output-language` directory. Nothing reads or writes
  it any more; the old `.lang` locks are ignored, not migrated.

The behavior change to expect: the style guide no longer enters the context whole
at session start. The Agent reads it when the hook asks, once per session.

## Aidiom

Aidiom is a macOS menu bar app, in its own repo, that writes these same files:
it switches the Default Profile, lists the live sessions with the profile each
one uses, pins a profile to one session or to all of them, and edits the
profiles and their attachments. The skill owns the contract; Aidiom is
a client of it, and either can be used alone.

The vocabulary lines up with the states above: a session with no lock file shows
as "default (inherited)", "Follow default" deletes the lock file, and a session
whose lock says `"disabled": true` shows as off. Aidiom is optional — the hook,
the skill and a hand-written `settings.json` are the whole mechanism.

## Other agents

The lock keys off a session id the agent puts in the environment, which is what
makes this Claude Code specific. OpenCode does not export one: session identity
reaches plugin hooks as `sessionID`, and a shell command sees it only if a
plugin injects it through the `shell.env` hook. The evidence, including the
`OPENCODE_SESSION_ID` proposal that was never merged, is in
[research-opencode-session-env.md](research-opencode-session-env.md).
