# OpenCode session identity in process environments

**Date:** 2026-08-07  
**Repo version checked:** installed binary `opencode 1.18.15` (`~/.opencode/bin/opencode`); plugin types `@opencode-ai/plugin@1.14.28` under `~/.config/opencode/node_modules`; source tree `github.com/anomalyco/opencode` branch `dev` (raw files).  
**Official docs:** https://opencode.ai/docs/

## Question

Does OpenCode expose any environment variables (especially session ID, agent identity, project/cwd) to:

1. shell/bash commands the agent runs (tool execution);
2. hook/plugin processes;
3. skill scripts invoked via slash commands?

Needed for designing a multi-agent, **per-session** lock for the `output-language` skill. An earlier incomplete probe suggested only plugin context has `sessionID`, not shell env — this note verifies or falsifies that against primary sources.

## Verdict

**OpenCode does not inject the current session ID into child process environments by default.** Session identity is first-class in plugin hooks and tool context as camelCase `sessionID`, and plugins can *opt-in* inject env vars via the documented `shell.env` hook. A proposed built-in `OPENCODE_SESSION_ID` (PR #9289 / issue #9292) was **never merged** and is absent from the installed binary.

---

## Findings

### 1. Documented / product `OPENCODE_*` (and related) env vars

#### Documented CLI configuration variables

Official CLI docs list configuration env vars under [Environment variables](https://opencode.ai/docs/cli/#environment-variables). These control product behavior; **none is a live session id**:

| Variable | Role (docs) |
| --- | --- |
| `OPENCODE_AUTO_SHARE` | Auto-share sessions |
| `OPENCODE_GIT_BASH_PATH` | Git Bash path (Windows) |
| `OPENCODE_CONFIG` | Config file path |
| `OPENCODE_TUI_CONFIG` | TUI config path |
| `OPENCODE_CONFIG_DIR` | Config directory |
| `OPENCODE_CONFIG_CONTENT` | Inline JSON config |
| `OPENCODE_DISABLE_*` / `OPENCODE_ENABLE_*` / `OPENCODE_EXPERIMENTAL_*` | Feature flags |
| `OPENCODE_PERMISSION` | Inlined permissions JSON |
| `OPENCODE_CLIENT` | Client identifier (default `cli`) |
| `OPENCODE_SERVER_PASSWORD` / `OPENCODE_SERVER_USERNAME` | HTTP basic auth for serve/web |
| `OPENCODE_MODELS_URL` | Models config URL |
| …plus experimental table | bash timeout, filewatcher, workspaces, etc. |

Config docs also document `OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR`, `OPENCODE_CONFIG_CONTENT`, `OPENCODE_TUI_CONFIG` as config precedence inputs ([Config locations](https://opencode.ai/docs/config/#precedence-order)).

#### Process-global markers set by the CLI itself

On every CLI invocation, middleware sets:

```text
process.env.AGENT = "1"
process.env.OPENCODE = "1"
process.env.OPENCODE_PID = String(process.pid)
```

Source: `packages/opencode/src/index.ts` (yargs middleware, ~lines 75–77). Confirmed in the installed binary (`AGENT="1"`, `OPENCODE="1"`, `OPENCODE_PID`).

These are **process-wide**, not per-session. Because the shell tool spreads `...process.env` into child env, **children inherit `AGENT=1`, `OPENCODE=1`, and `OPENCODE_PID`** (the parent OpenCode pid, not a session id).

#### Present in binary / runtime but not session-scoped

From installed binary `OPENCODE_*` strings (1.18.15), notable extras beyond the docs table include:

- `OPENCODE_WORKSPACE_ID` — experimental workspaces / control-plane (not session)
- `OPENCODE_PID` — parent process pid (set as above)
- `OPENCODE_PLUGIN_META_FILE`, `OPENCODE_DB`, `OPENCODE_ROUTE`, `OPENCODE_TERMINAL`, test-only flags, etc.

**Not present in the binary:** `OPENCODE_SESSION_ID`, `OPENCODE_SESSION_TITLE`, or any `OPENCODE_SESSION_*`.

#### SDK server spawn

`@opencode-ai/sdk` server helpers set `OPENCODE_CONFIG_CONTENT` when spawning a server process (`sdk/dist/server.js`, `sdk/dist/v2/server.js`). That is config injection for the server process, not per-session tool env.

---

### 2. Does the bash/shell tool get `sessionID` in its environment by default?

**No.**

#### Code path (agent shell tool)

File: `packages/opencode/src/tool/shell.ts` on `dev`.

Env construction:

```ts
const shellEnv = Effect.fn("ShellTool.shellEnv")(function* (ctx: Tool.Context, cwd: string) {
  const extra = yield* plugin.trigger(
    "shell.env",
    { cwd, sessionID: ctx.sessionID, callID: ctx.callID },
    { env: {} },
  )
  return {
    ...process.env,
    ...extra.env,
  }
})
```

Spawn:

```ts
// cmd() → ChildProcess.make(..., { cwd, env, ... })
// run() is called with env: yield* shellEnv(ctx, cwd)
```

Implications:

- Default env for the tool is **parent `process.env`** plus **plugin-provided** `extra.env`.
- `ctx.sessionID` is passed into the **plugin hook input**, not assigned to any env key unless a plugin writes it into `output.env`.
- Same pattern appears in the installed binary (`ShellTool.shellEnv` → trigger `"shell.env"` with `sessionID:c.sessionID`).

#### Code path (user prompt shell / interactive shell)

File: `packages/opencode/src/session/prompt.ts`, `shellImpl`:

```ts
const shellEnv = yield* plugin.trigger(
  "shell.env",
  { cwd, sessionID: input.sessionID, callID: part.callID },
  { env: {} },
)
const cmd = ChildProcess.make(sh, args, {
  cwd,
  extendEnv: true,
  env: { ...shellEnv.env, TERM: "dumb" },
  ...
})
```

Again: plugins may add env; **no built-in session id variable**.

#### Historical proposal (not shipped)

- Issue [#9292](https://github.com/anomalyco/opencode/issues/9292) proposed `OPENCODE_SESSION_ID` and `OPENCODE_SESSION_TITLE` for bash tool + prompt shell. **Closed as not planned.**
- PR [#9289](https://github.com/anomalyco/opencode/pull/9289) implemented that injection; **closed stale without merge** (May 2026 bot close).
- Follow-ups [#12159](https://github.com/anomalyco/opencode/pull/12159) / [#12160](https://github.com/anomalyco/opencode/pull/12160) also closed.
- Issue [#15117](https://github.com/anomalyco/opencode/issues/15117) notes MCP still lacks session env even *if* bash had it; also closed not planned. MCP `StdioClientTransport` is a separate gap.

---

### 3. Does `shell.env` exist and can it inject vars?

**Yes.** First-party and documented.

#### Types (`@opencode-ai/plugin`)

`~/.config/opencode/node_modules/@opencode-ai/plugin/dist/index.d.ts`:

```ts
"shell.env"?: (input: {
    cwd: string;
    sessionID?: string;
    callID?: string;
}, output: {
    env: Record<string, string>;
}) => Promise<void>;
```

#### Docs

[Plugins → Inject environment variables](https://opencode.ai/docs/plugins/#inject-environment-variables):

```js
export const InjectEnvPlugin = async () => {
  return {
    "shell.env": async (input, output) => {
      output.env.MY_API_KEY = "secret"
      output.env.PROJECT_ROOT = input.cwd
    },
  }
}
```

Docs state this applies to **“all shell execution (AI tools and user terminals)”**.

#### How plugins load

Plugin function receives **process/project** context, not session:

```ts
export type PluginInput = {
  client: ...
  project: Project
  directory: string
  worktree: string
  experimental_workspace: ...
  serverUrl: URL
  $: BunShell
}
```

(`PluginInput` in the same `index.d.ts`.) Session appears only on **per-invocation** hooks (`shell.env`, `tool.execute.*`, `chat.message`, etc.).

Plugin `$` is Bun’s shell API for plugin-side commands; it is not automatically given session env either.

---

### 4. Other ways session id is available outside plugins

| Channel | Session id available? | Notes |
| --- | --- | --- |
| Shell/bash tool env (default) | **No** | Only via `shell.env` injection |
| Prompt shell env (default) | **No** | Same |
| Slash-command `` `!` `` / shell expansion in command templates | **No session inject** | `prompt.ts` uses `Process.text([cmd], { shell })`, which inherits parent env (`util/process.ts`); does **not** call `shell.env` with session |
| Skill tool | **No process env** | Loads `SKILL.md` text into the model context only (`tool/skill.ts`); does not execute skill scripts |
| Custom plugin tools | **Yes** (`context.sessionID`) | `ToolContext` in `plugin/dist/tool.d.ts` |
| Built-in tool context (internal) | **Yes** (`ctx.sessionID`) | `packages/opencode/src/tool/tool.ts` `Context.sessionID` |
| Plugin event hooks | **Yes** | Many hooks take `sessionID`; bus events carry it in properties (e.g. local herdr plugin reads `properties.sessionID`) |
| System prompt `<env>` block | **cwd / worktree only** | `session/system.ts` injects Working directory, Workspace root, git?, platform, date — **not** session id or agent name |
| CLI flags | **Resume only** | `--session` / `-s` continues a known id; does not export current id to children ([CLI tui flags](https://opencode.ai/docs/cli/#flags)) |
| HTTP API | **Yes as path/body field** | SDK routes `/session/{sessionID}/...` (`@opencode-ai/sdk`); field name `sessionID` |
| Disk during a run | **Multi-session DB, not “current” env** | Docs: data under `~/.local/share/opencode/` ([Troubleshooting storage](https://opencode.ai/docs/troubleshooting/#storage)); no single env-readable “active session” file for tools |
| Stdin envelopes for skill scripts | **None found** | Skills are content-loaded, not spawned with an envelope |
| MCP server env | **No** | [#15117](https://github.com/anomalyco/opencode/issues/15117) |

#### Agent identity

- Available as **`agent: string`** on tool context and several chat hooks (`chat.message`, `chat.params`, …).
- **Not** set as a per-session env var by default.
- Global `AGENT=1` only means “running under OpenCode,” not which agent.

#### Project / cwd

- Shell tool spawns with `cwd` = session instance directory (or tool `workdir`).
- `shell.env` input includes `cwd`.
- System prompt exposes Working directory + Workspace root to the **model**, not as env keys like `OPENCODE_CWD`.
- Plugin init has `directory` and `worktree`.

---

### 5. Canonical session identifier field name

| Surface | Name | Format |
| --- | --- | --- |
| Plugin hooks, tool context, SDK types | **`sessionID`** (camelCase) | Branded string starting with `ses` |
| Binary / schema | SessionID brand `isStartsWith("ses")`; factory `"ses_" + …` | e.g. `ses_…` |
| A few TUI plugin types | `session_id` (snake_case) in isolated TUI APIs | `plugin/dist/tui.d.ts` |
| Proposed-but-unmerged env | `OPENCODE_SESSION_ID` | Never shipped |

**Canonical for OpenCode integration code: `sessionID`.**  
If designing env injection via `shell.env`, a natural key is still the community-proposed `OPENCODE_SESSION_ID` (for scripts) while reading `input.sessionID` from the hook.

---

### 6. Skills and slash commands (item 3 of the question)

From [Agent Skills docs](https://opencode.ai/docs/skills/) and `tool/skill.ts`:

1. Skills are discovered from `SKILL.md` directories.
2. The agent loads them with the **`skill` tool**, which returns markdown content + a base directory note.
3. **No skill subprocess** is started by the skill tool; scripts under `scripts/` only run if the agent (or user) later executes them via shell.
4. When that happens, env rules are those of the **shell tool** (section 2): inherit parent env + `shell.env` plugins — still no default session id.

Slash **commands** (`/name`) expand templates into a user prompt (`SessionPrompt.command`). Optional shell interpolations in templates use `Process.text` without session-aware env. The command path does expose `sessionID` to the `command.execute.before` plugin hook, not to child env.

---

## Implications for `output-language`

Current Claude Code design keys the lock on `$CLAUDE_CODE_SESSION_ID` (`scripts/lock.sh`). **There is no OpenCode equivalent env var today.**

Practical options for a multi-agent per-session lock on OpenCode:

1. **Recommended first-party path: small OpenCode plugin implementing `shell.env`**  
   - Read `input.sessionID` and set e.g. `output.env.OPENCODE_SESSION_ID = input.sessionID` (and optionally agent if available elsewhere).  
   - Then `lock.sh` / `remind.sh` can key off that env the same way they key off Claude’s session id.  
   - Scope: shell tool + user terminals that go through `shell.env` (docs claim both).  
   - Caveat: command-template shell expansion may **not** go through `shell.env` (see `Process.text` path).

2. **Plugin-native lock (no shell env)**  
   - Use `command.execute.before` / `chat.message` / event bus with `sessionID` to write/read lock state and inject reminder text via hooks (`experimental.chat.system.transform` or synthetic parts).  
   - More invasive; closer to how Claude’s settings hooks work, but OpenCode’s plugin model is different from Claude’s command hooks.

3. **Do not key only on `OPENCODE_PID` or `AGENT`/`OPENCODE`**  
   - Shared across all concurrent sessions in the same process; wrong for multi-session locks.

4. **Do not assume skill scripts “just have” session id**  
   - Skill load is content-only; scripts need the shell env path (or explicit args the agent passes).

5. **If relying on agent cooperation alone**  
   - Fragile; system prompt does not list session id. Would need prompt injection via plugin.

---

## Open questions

1. **Are there other shell spawn paths** (desktop app integrated terminal / PTY, code-mode, background tasks) that skip `shell.env`? Docs claim AI tools + user terminals; PTY feature requests exist but were not fully audited here.
2. **Will #9289 ever land?** Still closed; design should not wait on `OPENCODE_SESSION_ID` as a built-in.
3. **Subagent/child sessions:** task tool creates child `sessionID`s (parentID relationship). A lock keyed only on the *child* session may not apply to the parent pane, and vice versa — design needs a parent-vs-child policy (see local herdr plugin’s child-session filtering pattern).
4. **Plugin type package lag:** installed `@opencode-ai/plugin` is 1.14.28 while binary is 1.18.15; types already include `shell.env` + `sessionID`, but keep versions in mind when authoring.
5. **Exact session id string shape** beyond `ses` prefix: binary shows `ses_` + id factory; treat as opaque string.

---

## Source index

| Source | What it established |
| --- | --- |
| https://opencode.ai/docs/cli/#environment-variables | Documented OPENCODE_* config vars (no session id) |
| https://opencode.ai/docs/plugins/#inject-environment-variables | `shell.env` official API + example |
| https://opencode.ai/docs/plugins/ | Plugin context shape; event list including `shell.env` |
| https://opencode.ai/docs/skills/ | Skills are content-loaded via skill tool |
| https://opencode.ai/docs/config/ | Config env vars / precedence |
| https://opencode.ai/docs/troubleshooting/#storage | On-disk data location |
| `packages/opencode/src/tool/shell.ts` | Shell tool env = process.env + plugin; sessionID only in hook input |
| `packages/opencode/src/session/prompt.ts` | Prompt shell + command shell expansion paths |
| `packages/opencode/src/tool/skill.ts` | Skill tool returns text, no spawn |
| `packages/opencode/src/tool/tool.ts` | Internal `Context.sessionID` |
| `packages/opencode/src/session/system.ts` | System `<env>` has cwd/worktree, not session |
| `packages/opencode/src/index.ts` | Sets `AGENT`, `OPENCODE`, `OPENCODE_PID` |
| `packages/opencode/src/util/process.ts` | Default spawn merges `process.env` unless custom env |
| `~/.config/opencode/node_modules/@opencode-ai/plugin/dist/index.d.ts` | `Hooks["shell.env"]`, `PluginInput` |
| `~/.config/opencode/node_modules/@opencode-ai/plugin/dist/tool.d.ts` | Plugin `ToolContext.sessionID` / agent / directory / worktree |
| Installed binary `opencode 1.18.15` | No `OPENCODE_SESSION_*`; confirms shellEnv + AGENT markers |
| https://github.com/anomalyco/opencode/issues/9292 | Feature request closed not planned |
| https://github.com/anomalyco/opencode/pull/9289 | Implementation PR never merged |
| https://github.com/anomalyco/opencode/issues/15117 | MCP also lacks session env |
