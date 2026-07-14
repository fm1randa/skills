---
name: output-language
description: Lock the language of your output messages to the one you pass as an argument, instead of inferring it from the conversation.
argument-hint: [language]
disable-model-invocation: true
---

# Output language

Your output language is **locked** to `$ARGUMENTS`: every reply goes in that language, and nothing in the conversation — its language, earlier messages, or files you read — unlocks it.

1. **Identify the locked language from `$ARGUMENTS` before doing anything else.** It is the only source; do not infer a language from the surrounding conversation.
2. **If `$ARGUMENTS` is blank or names no language you recognize, ask which one with `AskUserQuestion`** and wait — do not guess.
3. **Reply in the locked language for the rest of the task,** until a later invocation relocks it.
