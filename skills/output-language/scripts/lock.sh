#!/usr/bin/env bash
# Lock (or unlock) the output language for the CURRENT Claude Code session.
#
# The lock is keyed by $CLAUDE_CODE_SESSION_ID, so it persists for the whole
# session, never leaks into other sessions, and is naturally forgotten once the
# session ends. The always-on hook in ~/.claude/settings.json reads the same
# file every turn (and after every Skill load) and re-injects the reminder.
#
# Usage:
#   lock.sh "<language>"                       lock replies to that language
#   lock.sh off | clear | none | unlock        remove the lock
set -euo pipefail

state_dir="${HOME}/.claude/output-language"
sid="${CLAUDE_CODE_SESSION_ID:-}"

if [ -z "$sid" ]; then
  echo "output-language: CLAUDE_CODE_SESSION_ID is not set; cannot persist the lock." >&2
  echo "output-language: your Claude Code may be too old to expose the session id." >&2
  exit 1
fi

mkdir -p "$state_dir"
# Housekeeping: drop lock files untouched for more than 7 days so stale
# per-session files don't accumulate forever.
find "$state_dir" -maxdepth 1 -name '*.lang' -mtime +7 -delete 2>/dev/null || true

lang="${1:-}"
file="${state_dir}/${sid}.lang"

case "$(printf '%s' "$lang" | tr '[:upper:]' '[:lower:]')" in
  ""|off|clear|none|unlock|unlocked|desativar|desligar|destravar)
    rm -f "$file"
    echo "output-language: unlocked for this session."
    ;;
  *)
    printf '%s\n' "$lang" > "$file"
    echo "output-language: locked to '${lang}' for this session."
    ;;
esac
