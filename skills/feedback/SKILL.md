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

Section the note like Part 1: keep `<h4>` only on the "Nota técnica" title, and give each field its own `<h5>` heading followed by the content (a `<p>`, or a `<ul>` when the field is genuinely a list).

### Type `bug` (mandatory)

```html
<h4>Nota técnica (diagnóstico e post-mortem)</h4>

<h5>Causa-raiz</h5>
<p><o mecanismo real, com os <code>identificadores</code> de código relevantes></p>

<h5>Correção</h5>
<p><o que foi mudado, em uma frase></p>

<h5>Como validamos</h5>
<p><loop de reprodução / repro pela tela / teste de regressão></p>

<h5>Post-mortem (por que passou e o que previne)</h5>
<ul>
  <li><por que não foi pego antes, ex.: falha silenciosa, ambiguidade de contrato></li>
  <li><dívida estrutural / follow-up, com link para a tarefa quando houver></li>
</ul>
```

### Type `feature` (mandatory)

```html
<h4>Nota técnica (construção)</h4>

<h5>O que construímos</h5>
<p><a abordagem técnica e os componentes principais, com <code>identificadores</code>></p>

<h5>Decisões e trade-offs</h5>
<p><por que foi feito assim e não de outro jeito></p>

<h5>Como validamos</h5>
<p><testes / repro pela tela / cenários cobertos></p>

<h5>O que ficou de fora / follow-ups</h5>
<p><recortes de escopo, dívida, próximos passos, com link quando houver></p>
```

### Type `geral` (optional)

Use a flexible note only when there is real technical substance (refactor, hotfix). Adapt the fields to the case:

```html
<h4>Nota técnica</h4>

<h5>O que mudou</h5>
<p><a mudança técnica e os <code>identificadores</code> relevantes></p>

<h5>Como validamos</h5>
<p><como confirmamos que segue funcionando></p>

<h5>Riscos / follow-ups</h5>
<p><o que observar, dívida, próximos passos></p>
```

If it is a plain comment with no technical substance, omit the note entirely.

For `bug` and `feature`, if some item does not apply, say so explicitly instead of omitting the line.

## Output rules

- Raw HTML only. Use `<h4>` for the Part 1 section titles and the "Nota técnica" title, `<h5>` for the technical-note field titles, `<hr>` to separate Part 1 from Part 2, `<ul>`/`<li>` for lists, `<code>` for identifiers, and `<a>` for PR links.
- Straight quotes only, and no em/en dashes — the text often passes through a humanizer, so keep it in that style from the start. This is about punctuation, not spelling: keep correct pt-BR accentuation (`á ã ç é í ó ú ê` ...); never strip accents.
