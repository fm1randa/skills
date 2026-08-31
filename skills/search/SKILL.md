---
name: search
description: Answers a free-form question about your work by sweeping the work surfaces — Agidesk, Slack, Google Drive, Google Calendar and Datadog.
disable-model-invocation: true
---

# Search

Answer the question in `$ARGUMENTS` by sweeping the **surfaces** where the answer could live.

The question is the completion criterion. Search is done when the answer is stated and every claim in it is backed by a cited finding, or when what blocked the answer is named. A pile of findings with no answer is not done.

This is the sibling of `/recon`, and they divide the work: `/recon` builds the complete picture of one task; `/search` answers one question, whatever it is about.

## Surfaces

| Surface | What it knows | Recipe |
| --- | --- | --- |
| Agidesk | what there is to do, who asked, what state it is in | [references/agidesk.md](references/agidesk.md) |
| Slack | what the team agreed, who took what, what just happened | [references/slack.md](references/slack.md) |
| Google Drive | Meet notes, specs, decision docs | [references/google-drive.md](references/google-drive.md) |
| Google Calendar | how much time you have, who you are meeting | [references/google-calendar.md](references/google-calendar.md) |
| Datadog | what production is actually doing | [references/datadog.md](references/datadog.md) |

## Steps

### 1. Expand the question

Inline, no agent. Turn `$ARGUMENTS` into search material:

- **Terms** the surfaces would actually match — product areas, feature names, IDs, people. Carry both Portuguese and English forms; the team writes in both.
- **Window** — the date range worth searching. Default to the last 14 days when the question implies "now".
- **Identity**, only when the question says *eu / meu / minha / pra mim / me*: resolve who that is on each surface it matters for (email from the environment, Slack user, Agidesk user, primary calendar). State at the top of the answer who you resolved to, so a wrong resolution is visible rather than silent.

Done when a literal-minded searcher could take these terms and run them.

### 2. Route

Two routing decisions, both from the tables below. When the user names surfaces — as flags (`--slack`) or in prose ("olha no Drive") — that naming wins over both tables and only the named surfaces run.

**Which surfaces sweep:**

| Surface | Runs |
| --- | --- |
| Agidesk, Slack, Drive | always |
| Google Calendar | when the question has a time axis — *agora, hoje, essa semana, cabe, antes de, quanto tempo* |
| Datadog | when the question is about errors, latency or production — *quebrou, caiu, lento, erro, 500, timeout* |

**Which surface is the spine** — the one that sweeps first and whose findings brief the rest:

| Question is about | Spine |
| --- | --- |
| work to do — tasks, bugs, priority, what to pick up | Agidesk |
| what was agreed, who took what, what happened | Slack |
| a document, spec, meeting or notes | Drive |
| an incident, error or slowdown in production | Datadog |
| none of the rows match | ask the user which surface to lead with |

Done when the surface list and the spine are both fixed, and the user has been asked if no row matched.

### 3. Sweep the spine

One agent, on the spine surface, handed its recipe file and the expansion from step 1.

Done when its findings are in hand — including "nothing", which is itself a finding that shapes the brief.

### 4. Fan out

One agent per remaining routed surface, in parallel, each handed its recipe file and a brief built from step 1 **plus** what the spine found: the IDs, names, dates and phrasings that surfaced. A generic brief finds nothing; a specific one finds the conversation.

Done when every routed surface has reported.

### 5. Second sweep round

Only when steps 3 and 4 do not sustain an answer. Rebuild the terms from what surfaced — a person's name, a task ID, the phrase the team actually uses — and sweep again.

The cap is two rounds. There is no third: at that point go to step 6 and answer with what you have.

### 6. Answer

Three sections, in this order:

- **Answer** — the answer to the question. When the question asks you to choose, name the choice, and list what you rejected with the one-line reason for each rejection.
- **Evidence** — by surface, each with a link and a date. Every claim in the answer traces to one of these.
- **Not retrieved** — anything a surface could not reach, and what was tried. A surface you had no access to belongs here, named.

Done when the answer stands on cited evidence, or when this section states plainly that the question is unanswered and what is missing to answer it.

## Rules of engagement

- **On an MCP error, stop and report it** so the user can fix the MCP, then wait. Google Drive holds the one sanctioned non-MCP alternative in this skill, stated in its reference file. Every other surface reaches its data through its MCP alone — where a reference file mentions a second authentication route, that is still the same MCP.
- **Answer in the session's language** — whichever `/output-language` has locked, or the language the conversation is already in. The three section names above are labels, not literal strings: write them in that language.
