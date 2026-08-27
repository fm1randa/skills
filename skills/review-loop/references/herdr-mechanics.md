# Herdr mechanics for one round

The installed `herdr` binary is the authority on syntax. Run `herdr --skill` for
the full agent skill, and `herdr agent` or `herdr pane` for a command group.
What follows is only the part this loop uses, plus the traps it hit.

Run every command from the repository under review.

## The round, end to end

```bash
test "${HERDR_ENV:-}" = 1          # required; if this fails, stop

herdr pane current --current       # resolve the calling pane
herdr pane layout --pane <caller-pane-id>

herdr pane split --current --direction right --cwd "$PWD" --no-focus
# read the new pane ID from .result.pane.pane_id

herdr agent start reviewer-r1 --kind claude --pane <pane-id> \
  --timeout 60000 -- --model sonnet

herdr agent prompt reviewer-r1 '<the brief>' --wait --timeout 900000

herdr agent read reviewer-r1 --source recent-unwrapped --lines 400

herdr agent send-keys reviewer-r1 ctrl+c
herdr pane close <pane-id>
```

## Traps, each one measured

- **`agent prompt --wait` exceeds a foreground tool timeout.** The call moves to
  the background and notifies you when it completes. Wait for that notification
  and spend the time elsewhere; the pane tells you nothing new while it works.
- **`agent read` returns the whole pane**, prompt echo included. The findings are
  at the tail, so read from the end. If the response is longer than the pane's
  scrollback can return — raising `--lines` reveals no more — the agent is on
  the alternate screen and those rows are gone. Only then, ask the agent to
  write its full report to a temp file and reply with the path, and read the
  file.
- **`$HERDR_PANE_ID` goes stale** after a session resume. Resolve the calling
  pane with `herdr pane current --current` rather than trusting the variable.
- **Split right from a wide pane, down from a narrow one.** Check with
  `herdr pane layout`. Repeated splits in one direction make columns nobody can
  read.
- **Model and effort.** Sonnet 5 at medium effort, held constant for every round
  of the loop. `--model sonnet` after the `--` separator gives you both defaults;
  the pane footer confirms what actually started, so read it — an effort flag can
  silently fail to take.
- **Close only the panes this loop created**, and leave the Herdr server
  running.
- **Watch for a phantom input.** Text nobody sent has appeared in a reviewer
  pane's input twice. Read the pane's input line before you send Enter, and
  discard anything you did not write.

## Naming

Name the reviewer for its round: `reviewer-r1`, `reviewer-r2`, and so on. Names
must match `[a-z][a-z0-9_-]{0,31}` and be unique among live agents, and a name
is released when its agent exits. A distinct name per round is what makes
`herdr agent list` tell you where in the loop you are, and it keeps each
reviewer as disposable as the loop needs.
