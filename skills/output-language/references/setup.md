# Setup: the reminder hook

The skill has two halves. `/output-language <lang>` writes a per-session lock
file (`scripts/lock.sh`); a hook reads it and re-injects the reminder
(`scripts/remind.sh`) every turn, so the lock survives foreign-language skills
loading into context.

Skill-frontmatter hooks are discarded when the skill finishes, so the reminder
hook must live in your user settings — which the `skills` CLI does not manage.
This is a **one-time manual step per machine**.

## Wire the hook

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

`remind.sh` prints nothing when the session has no lock, so ordinary sessions
are untouched, and it never blocks a prompt or tool call. The `PostToolUse`
matcher `"Skill"` is what fires the reminder right after a skill loads.

## Behavior

- The lock lives at `~/.claude/output-language/<session-id>.lang`, so it holds
  for the whole session and never leaks into another.
- `/output-language off` removes it; `/clear` starts a new session id, which
  drops it.
