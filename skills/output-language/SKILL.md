---
name: output-language
description: Lock every reply to a language you pass (`/output-language <lang>`) instead of letting the conversation decide; `off` unlocks.
argument-hint: [language | off]
disable-model-invocation: true
---

# Output language

Your output language is **locked** to `$ARGUMENTS`: the locked language wins over the conversation's own language, earlier messages, skills you load, and files you read. A companion hook re-injects the lock every turn so it holds for the whole session — setup and behavior live in [references/setup.md](references/setup.md).

## Steps

1. **Resolve the target language from `$ARGUMENTS` before anything else** — it is the only source.
2. **If `$ARGUMENTS` is `off`, `clear`, `none`, or `unlock`,** run the unlock command, confirm the lock is removed (in the language of the request), and stop.
3. **If `$ARGUMENTS` is blank or names no language you recognize, ask which one with `AskUserQuestion`** and wait for the answer.
4. **Persist the lock:**
   ```bash
   bash "$HOME/.claude/skills/output-language/scripts/lock.sh" "<resolved language>"
   ```
   If it reports `CLAUDE_CODE_SESSION_ID` unset, tell the user cross-turn persistence is unavailable on their Claude Code version and honor the lock from this instruction for the rest of the conversation.
5. **Reply in the locked language for the rest of the task,** until a later invocation relocks or unlocks it. Content the user must read verbatim in another language (code, identifiers, quoted text) stays as-is.

## Unlock

```bash
bash "$HOME/.claude/skills/output-language/scripts/lock.sh" off
```
