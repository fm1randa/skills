# The implementer briefing

Message 1 of two. It is read-only: the implementer answers that it understood
and changes nothing, except the single write named below. Message 2 is the bare
slash command.

Fill every `<slot>` from the epic before you send. A slot you cannot fill is a
fact you have not gathered yet - gather it rather than guessing, because the
implementer will act on whatever you write.

## Slots

| Slot | Where it comes from | Example |
| --- | --- | --- |
| `<ticket>` | the slice | `TRF-770393` |
| `<title>` | the slice | Converge message templates |
| `<repos>` | the slice's scope | `agidesk`, `agitalks-backend` |
| `<base>` | the repository's integration branch | `origin/staging`, `origin/main` |
| `<flag>` | the epic, or "no flag" | `channel_scope_enabled` |
| `<language>` | the project's convention | code English, ticket content pt-BR |
| `<cwd>` | main checkout, or a box | `~/Workspace/boxes/t02-10/agidesk` |
| `<allowed-write>` | the board move that starts the slice | move `<ticket>` Ready -> In development |
| `<context>` | the epic, prior slices, settled decisions | see below |

## Template

> You are the implementer for `<ticket>` - `<title>`, one slice of epic
> `<epic>`. Work in `<cwd>`, across `<repos>`.
>
> **Context.** `<context>`: what the epic is doing, which sibling slices already
> merged and what they changed, the decisions already settled (so you do not
> reopen them), and the acceptance criteria of this slice.
>
> **Hard rules.**
>
> - Branch from `<base>`. Never from another slice's branch.
> - All new behavior sits behind `<flag>`. With the flag off, the old path is
>   unchanged end to end, in every repository this slice touches. Prove it
>   before you call the slice done.
> - `<language>`.
> - Do not push. Do not open a pull request. Both wait for my word.
> - This session drives exactly this slice. Do not pick up another ticket.
> - Report back rather than deciding alone when the slice's scope turns out to
>   be wrong.
>
> **The one write you may make now:** `<allowed-write>`. Nothing else - no
> branch, no file, no command - until my next message.
>
> Confirm you have read this, and tell me anything in it that contradicts what
> you find in the code.

## After it answers

Send message 2 on its own line, with no preamble around it:

```
/implement <ticket>
```

Then verify it loaded - the grep in SKILL.md step 4. A slash command wrapped in a
sentence arrives as prose, and the session works without the skill.
