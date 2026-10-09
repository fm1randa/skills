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
#   lock.sh pause | pausar        pause every session (settings.json "disabled")
#   lock.sh resume | retomar      remove the Pause: every session is back
#
# pause and resume need no session id, write only settings.json, and keep every
# other key in it. pause refuses a missing, unreadable or malformed
# settings.json; pausing a paused file and resuming an unpaused one write nothing.
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

# Bash-only path handling, no dirname, so the checks below are what reports a
# broken environment.
self_dir="${BASH_SOURCE[0]}"
case "$self_dir" in
  */*) self_dir="${self_dir%/*}" ;;
  *) self_dir="." ;;
esac
# shellcheck source=state.sh
. "${self_dir}/state.sh"

# Before anything else: without a backend a profile id would look unknown and
# the instruction would come out empty, which would write a lock that says
# nothing while reporting success; and the Pause could not be written at all.
if ! json_backend_available; then
  echo "output-language: no usable JSON backend ('$(json_backend_name)'); cannot write any state." >&2
  echo "output-language: install jq or python3, or unset OUTPUT_LANGUAGE_JSON_BACKEND." >&2
  exit 1
fi

argument="${1:-}"
word="$(printf '%s' "$argument" | tr '[:upper:]' '[:lower:]')"

# Edit the Pause in settings.json, or exit with the message that matches why it
# could not be edited.
edit_pause() {
  local settings="$1" op="$2" status=0
  json_edit_top "$settings" disabled "$op" || status=$?
  case "$status" in
    0) return 0 ;;
    1) echo "output-language: ${settings} cannot be read; nothing changed." >&2 ;;
    2) echo "output-language: ${settings} is not a valid JSON object; nothing changed." >&2 ;;
    3) echo "output-language: ${settings} changed while it was being written; nothing changed." >&2 ;;
    *) echo "output-language: ${settings} could not be edited; nothing changed." >&2 ;;
  esac
  exit 1
}

# The Pause lives in settings.json, not in a Session Lock, so it needs no
# session id and touches no session file: every session keeps what it held.
case "$word" in
  pause | pausar)
    settings="$(settings_file)"
    if [ ! -f "$settings" ]; then
      echo "output-language: there is no ${settings} to pause; nothing changed." >&2
      exit 1
    fi
    # Already paused, the way the hook reads it: rewriting would only reformat
    # a file the user may have laid out by hand.
    if [ "$(json_top "$settings" disabled)" = "true" ]; then
      echo "output-language: already paused in every session. Run '/output-language resume' to put each one back."
      exit 0
    fi
    edit_pause "$settings" set
    echo "output-language: paused in every session. Run '/output-language resume' to put each one back."
    exit 0
    ;;
  resume | retomar)
    settings="$(settings_file)"
    # Read the way the hook reads it, so "no Pause" here means the hook was not
    # paused either: a missing or malformed file, or no "disabled" key.
    if [ "$(json_top "$settings" disabled)" != "true" ]; then
      echo "output-language: there is no Pause to resume; nothing changed."
      exit 0
    fi
    edit_pause "$settings" delete
    echo "output-language: resumed; every session is back where it was."
    exit 0
    ;;
esac

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

case "$word" in
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
