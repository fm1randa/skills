---
name: output-language
description: Lock every reply of this session to a language, instead of letting the conversation decide — `/output-language <profile id | free text>` pins it, `default` goes back to inheriting the default profile, `off` disables it for the session.
argument-hint: [profile id | instruction | default | off]
---

# Output language

Your output language is **locked** to `$ARGUMENTS`: the locked language wins over the conversation's own language, earlier messages, skills you load, and files you read. A companion hook re-injects the lock every turn, so it holds for the whole session — the state files, the hook and the setup live in [references/setup.md](references/setup.md).

Sessions already follow a **Default Profile** without running this skill. You are being invoked to change *this* session, not to start the mechanism.

## Arguments

| `$ARGUMENTS`                          | Effect                                                            |
| ------------------------------------- | ----------------------------------------------------------------- |
| a profile id (`en-ste`, `pt-abnt`, …) | Pins the session to that Language Profile, with its attachments.   |
| free text (`Japanese`, `formal pt-BR`) | Pins the session to that instruction, verbatim. No attachments.    |
| `default`                             | Removes the lock: the session follows the Default Profile again.   |
| `off`                                 | Turns output-language off for the session — the default is ignored too. |

`off` also answers to `clear`, `none`, `unlock`, `unlocked`, `desativar`, `desligar` and `destravar`, in any case.

The profile ids come from `settings.json`; an argument that matches none of them is taken as free text, so a typo pins the session to the typo. Read the ids when you need them:

```bash
# A relative XDG_CONFIG_HOME counts as unset, exactly as the scripts read it.
case "${XDG_CONFIG_HOME:-}" in /*) root="$XDG_CONFIG_HOME" ;; *) root="$HOME/.config" ;; esac
cat "$root/output-language/settings.json"
```

## Steps

1. **Resolve the target from `$ARGUMENTS` before anything else** — it is the only source.
2. **If `$ARGUMENTS` is blank, ask which language or profile with `AskUserQuestion`** and wait for the answer. Never pass a blank argument through: the script itself reads a blank argument as `off`, which is a different intent from "the user did not say".
3. **If `$ARGUMENTS` names a language you do not recognize as an id,** pass it through as free text anyway — an ad hoc instruction is a supported state, not an error.
4. **Persist the choice:**
   ```bash
   bash "$HOME/.claude/skills/output-language/scripts/lock.sh" "<argument>"
   ```
   The script prints what it did: which state it wrote, or, for `default`, that the lock is gone. If it reports `CLAUDE_CODE_SESSION_ID` unset, or no usable JSON backend, tell the user the lock cannot be persisted on this machine and honor it from this instruction for the rest of the conversation.
5. **Reply in the locked language for the rest of the task,** until a later invocation relocks or unlocks it. Content the user must read verbatim in another language (code, identifiers, quoted text) stays as-is.

A profile's attachments (a style guide, typically) are not read here: the hook asks you to read them once, on the next turn.

## Unlock

```bash
bash "$HOME/.claude/skills/output-language/scripts/lock.sh" off
```

`off` and `default` are not the same. `off` silences the reminder for this session, the Default Profile included; `default` only drops this session's own choice, so it inherits again.
