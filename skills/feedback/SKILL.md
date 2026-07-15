---
name: feedback
description: >-
  Drafts a short, low-jargon findings message in Brazilian Portuguese as raw
  HTML. Use when the user wants to summarize what changed and how a task was
  approached, or mentions "feedback" / a findings message.
argument-hint: "[bug|feature|geral]"
arguments: [type]
---

Draft a concise message in pt-BR explaining what changed and how we approached the task. Output raw HTML in two parts: a plain-language summary, then a technical note.

## Resolve the feedback type first

Every feedback is one of three types. Pick it before writing:

- **`bug`** — a defect was fixed.
- **`feature`** — a piece of development was completed.
- **`geral`** — anything else (refactor, hotfix, a plain comment or status update).

**How to choose:** the invocation type is `$type`. If it is one of `bug`, `feature`, or `geral`, use it. If it is empty or anything else, infer the type from the task context.

The type only changes Part 2 (the technical note). Part 1 is the same for all types.

## Part 1 — Resumo (low-jargon)

Keep this part easy to read: people should understand it quickly. Avoid technical terms, but do not overshoot into vagueness — balance it. No code identifiers here.

```
#### Como estava antes …
#### O que mudamos …
#### Onde se aplica …
#### PRs
* beta: #1859
* develop: #1860
```

Hyperlink every PR. Note on PRs: we use branches as environments. `beta`, `develop`, `staging`, and `main` each refer to a specific environment.

## Part 2 — Nota técnica

Here you can and should use technical terms and code identifiers (wrap identifiers in `<code>`). The structure depends on the type resolved above.

### Type `bug` (mandatory)

```
#### Nota técnica (diagnóstico e post-mortem)
- Causa-raiz: <o mecanismo real, com os identificadores de código relevantes>
- Correção: <o que foi mudado, em uma frase>
- Como validamos: <loop de reprodução / repro pela tela / teste de regressão>
- Post-mortem (por que passou e o que previne):
    - <por que não foi pego antes, ex.: falha silenciosa, ambiguidade de contrato>
    - <dívida estrutural / follow-up, com link para a tarefa quando houver>
```

### Type `feature` (mandatory)

```
#### Nota técnica (construção)
- O que construímos: <a abordagem técnica e os componentes principais, com identificadores>
- Decisões e trade-offs: <por que foi feito assim e não de outro jeito>
- Como validamos: <testes / repro pela tela / cenários cobertos>
- O que ficou de fora / follow-ups: <recortes de escopo, dívida, próximos passos, com link quando houver>
```

### Type `geral` (optional)

Use a flexible note only when there is real technical substance (refactor, hotfix). Adapt the fields to the case:

```
#### Nota técnica
- O que mudou: <a mudança técnica e os identificadores relevantes>
- Como validamos: <como confirmamos que segue funcionando>
- Riscos / follow-ups: <o que observar, dívida, próximos passos>
```

If it is a plain comment with no technical substance, omit the note entirely.

For `bug` and `feature`, if some item does not apply, say so explicitly instead of omitting the line.

## Output rules

- Raw HTML only. Use `<h4>` for section titles, `<hr>` to separate Part 1 from Part 2, `<ul>`/`<li>` for lists, and `<code>` for identifiers.
- Straight quotes only, and no em/en dashes — the text often passes through a humanizer, so keep it in that style from the start.
