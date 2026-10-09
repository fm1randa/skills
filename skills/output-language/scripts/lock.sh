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
#   lock.sh pause | pausar        pause every session (creates <state root>/paused)
#   lock.sh resume | retomar      remove the Pause: every session is back
#
# pause and resume need no session id, no JSON backend and no settings.json, and
# never touch settings.json: the Pause is the sentinel file alone. Pausing while
# paused and resuming while not paused change nothing.
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

argument="${1:-}"

# The Pause is the sentinel file, not a key in settings.json or a Session Lock:
# it needs no session id, no JSON backend and no settings.json, touches no other
# file, and every session keeps what it held. Creating and removing a file are
# each one atomic step, so no concurrent writer of settings.json can lose it.
# nocasematch instead of tr, so this branch runs before the backend check below
# with nothing but bash.
shopt -s nocasematch
case "$argument" in
  pause | pausar)
    sentinel="$(pause_file)"
    mkdir -p "${sentinel%/*}"
    # noclobber makes the redirection create the file or fail, in one step, so
    # an existing Pause (and the time it records) is never rewritten.
    if ! (set -C; date -u +%Y-%m-%dT%H:%M:%SZ > "$sentinel") 2> /dev/null; then
      if [ -e "$sentinel" ]; then
        echo "output-language: already paused in every session. Run '/output-language resume' to put each one back."
        exit 0
      fi
      echo "output-language: cannot create ${sentinel}; nothing changed." >&2
      exit 1
    fi
    echo "output-language: paused in every session. Run '/output-language resume' to put each one back."
    exit 0
    ;;
  resume | retomar)
    sentinel="$(pause_file)"
    if [ ! -e "$sentinel" ]; then
      echo "output-language: there is no Pause to resume; nothing changed."
      exit 0
    fi
    rm -f "$sentinel"
    echo "output-language: resumed; every session is back where it was."
    exit 0
    ;;
esac
shopt -u nocasematch

# Before anything else that writes a lock: without a backend a profile id would
# look unknown and the instruction would come out empty, which would write a
# lock that says nothing while reporting success.
if ! json_backend_available; then
  echo "output-language: no usable JSON backend ('$(json_backend_name)'); cannot write any state." >&2
  echo "output-language: install jq or python3, or unset OUTPUT_LANGUAGE_JSON_BACKEND." >&2
  exit 1
fi

word="$(printf '%s' "$argument" | tr '[:upper:]' '[:lower:]')"

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
