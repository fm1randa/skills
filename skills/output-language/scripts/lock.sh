#!/usr/bin/env bash
# Pin (or unpin) the output language of the CURRENT Claude Code session.
#
# The Session Lock is keyed by $CLAUDE_CODE_SESSION_ID, so it holds for the whole
# session, never leaks into another one, and is pruned once it goes stale. The
# always-on Reminder hook (remind.sh) reads the same files every turn and after
# every Skill load, so a change takes effect on the next prompt.
#
# Usage:
#   lock.sh "<profile id>"        pin the session to that Language Profile
#   lock.sh "<free text>"         pin the session to that ad hoc instruction
#   lock.sh default               remove the lock: follow the Default Profile
#   lock.sh off | clear | none | unlock | unlocked
#           | desativar | desligar | destravar
#                                 turn output-language off for this session
#
# The three states are distinct, and Aidiom (the macOS menu bar app) reads the
# same shapes: `default` deletes sessions/<sid>.json, so the session inherits the
# Default Profile again ("Follow default" in the app, which deletes the file too);
# `off` writes { "disabled": true }, which the hook honors by staying silent and
# ignoring the Default Profile (the app shows such a session as "off").
#
# Every write drops "attachmentsRequestedFor", so the Agent is asked to read the
# new profile's attachments on the next turn.
set -euo pipefail

# shellcheck source=state.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/state.sh"

if [ -z "${CLAUDE_CODE_SESSION_ID:-}" ]; then
  echo "output-language: CLAUDE_CODE_SESSION_ID is not set; cannot persist the lock." >&2
  echo "output-language: your Claude Code may be too old to expose the session id." >&2
  exit 1
fi

file="$(lock_file)"
mkdir -p "$(dirname "$file")"
prune_stale_sessions

# Write the whole file, so no key of an earlier state survives -- the fingerprint
# included, which is why this builds the object instead of merging into it with
# state.sh's json_set_top.
write_lock() {
  local body="$1" tmp="${file}.tmp.$$"
  printf '{\n  %s\n}\n' "$body" > "$tmp"
  mv "$tmp" "$file"
}

argument="${1:-}"

case "$(printf '%s' "$argument" | tr '[:upper:]' '[:lower:]')" in
  ""|off|clear|none|unlock|unlocked|desativar|desligar|destravar)
    write_lock '"disabled": true'
    echo "output-language: off for this session (the Default Profile is ignored too)."
    ;;
  default)
    rm -f "$file"
    echo "output-language: this session now follows the default."
    ;;
  *)
    if json_profile_exists "$(settings_file)" "$argument"; then
      write_lock "\"profile\": \"$(escape_json "$argument")\""
      echo "output-language: this session now uses the '${argument}' profile."
    else
      write_lock "\"instruction\": \"$(escape_json "$argument")\""
      echo "output-language: this session now uses the instruction '${argument}'."
    fi
    ;;
esac
