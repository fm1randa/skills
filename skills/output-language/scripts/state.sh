#!/usr/bin/env bash
# Shared state helpers for the output-language skill: where the files live and
# how to read and write them. Sourced by lock.sh and remind.sh; not meant to be
# run on its own.
#
# File contract (also written by Aidiom, the macOS menu bar app):
#
#   $XDG_CONFIG_HOME/output-language        (or ~/.config/output-language; per
#                                           the XDG spec a relative value of
#                                           XDG_CONFIG_HOME counts as unset)
#     settings.json
#       { "default": "<profile id>",
#         "profiles": [ { "id", "short", "label", "instruction",
#                         "attachments": ["<absolute path>", ...] } ] }
#                                           written only by Aidiom; this skill
#                                           reads it and never writes it.
#     paused                                the Pause: while this file exists,
#                                           remind.sh does nothing in any
#                                           session; removing it resumes. Its
#                                           content is ignored (writers put an
#                                           ISO-8601 timestamp in it for humans).
#     sessions/<session-id>.json            the Session Lock, one of:
#       { "profile": "<id>" }               pinned to a Language Profile
#       { "instruction": "<free text>" }    pinned to an ad hoc instruction
#       { "disabled": true }                output-language off for this session
#                                           No file means the session follows
#                                           the Default Profile. Written by
#                                           lock.sh and Aidiom, each replacing
#                                           the file whole; never by remind.sh.
#     sessions/<session-id>.asked           the attachment fingerprint, plain
#                                           text, written only by remind.sh once
#                                           it has asked the Agent to read the
#                                           effective profile's attachments. The
#                                           fingerprint is the profile id and its
#                                           sorted attachment paths joined by
#                                           newlines, the one character a path
#                                           cannot hold, so two different
#                                           attachment sets can never produce the
#                                           same fingerprint. A pin never needs
#                                           to touch it: a new profile gives a
#                                           new fingerprint, and the hook asks
#                                           again.
#
# A lock written before the fingerprint had its own file may still hold it as
# "attachmentsRequestedFor"; remind.sh reads that key only while there is no
# .asked file, and otherwise ignores it.
#
# JSON is parsed with jq when it is on PATH, else with python3; both backends
# keep each read to one short-lived process, which matters because the hook runs
# on every turn. Set OUTPUT_LANGUAGE_JSON_BACKEND to "jq" or "python3" to force
# one (the test runner uses it to cover both). Without a usable backend nothing
# can be read or written: lock.sh then fails loudly and remind.sh stays silent,
# so callers must check json_backend_available before anything else.

state_root() {
  local base="${XDG_CONFIG_HOME:-}"
  # A relative XDG_CONFIG_HOME would anchor the state to whatever directory the
  # hook happens to run in, giving each project its own state root. The spec
  # says to treat such a value as unset.
  case "$base" in
    /*) ;;
    *) base="${HOME}/.config" ;;
  esac
  printf '%s/output-language' "$base"
}

settings_file() {
  printf '%s/settings.json' "$(state_root)"
}

# The Pause sentinel. Plain shell on purpose: it is checked before any JSON
# backend, so a paused hook stays silent even on a machine without one.
pause_file() {
  printf '%s/paused' "$(state_root)"
}

# Path of the Session Lock, or nothing when there is no session id.
lock_file() {
  local sid="${CLAUDE_CODE_SESSION_ID:-}"
  [ -n "$sid" ] || return 0
  printf '%s/sessions/%s.json' "$(state_root)" "$sid"
}

# Path of the attachment fingerprint, or nothing when there is no session id.
asked_file() {
  local sid="${CLAUDE_CODE_SESSION_ID:-}"
  [ -n "$sid" ] || return 0
  printf '%s/sessions/%s.asked' "$(state_root)" "$sid"
}

case "${OUTPUT_LANGUAGE_JSON_BACKEND:-auto}" in
  auto)
    if command -v jq > /dev/null 2>&1; then
      json_backend="jq"
    else
      json_backend="python3"
    fi
    ;;
  *)
    # Honored as given, even when it names nothing this machine has: an explicit
    # choice that cannot run is an error to report, not one to paper over.
    json_backend="$OUTPUT_LANGUAGE_JSON_BACKEND"
    ;;
esac

# Succeeds when the chosen backend is one this script can drive and the command
# is on PATH. Every read swallows its own errors to keep a malformed file from
# blocking a prompt, which would otherwise turn "no backend at all" into "the
# file says nothing" -- an empty read that reads like a missing profile.
json_backend_name() {
  printf '%s' "$json_backend"
}

json_backend_available() {
  case "$json_backend" in
    jq | python3) command -v "$json_backend" > /dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

# Every python3 branch below reads a broken or unexpected file as an empty one,
# which is what keeps a malformed settings.json from ever blocking a prompt.
py_load='
import json, sys
def load(path):
    try:
        with open(path) as fh:
            return json.load(fh)
    except Exception:
        return None
def profile(data, wanted):
    if not isinstance(data, dict):
        return None
    for item in data.get("profiles") or []:
        if isinstance(item, dict) and item.get("id") == wanted:
            return item
    return None
'

py_top="${py_load}"'
data = load(sys.argv[1])
if isinstance(data, dict):
    value = data.get(sys.argv[2])
    if value is not None:
        print(value if isinstance(value, str) else json.dumps(value))
'

py_instruction="${py_load}"'
found = profile(load(sys.argv[1]), sys.argv[2])
if found and isinstance(found.get("instruction"), str):
    print(found["instruction"])
'

py_exists="${py_load}"'
print("yes" if profile(load(sys.argv[1]), sys.argv[2]) else "", end="")
'

py_attachments="${py_load}"'
found = profile(load(sys.argv[1]), sys.argv[2]) or {}
for path in found.get("attachments") or []:
    if isinstance(path, str):
        print(path)
'

py_escape='
import json, sys
sys.stdout.write(json.dumps(sys.stdin.read(), ensure_ascii=False))
'

# json_top <file> <key>: a top-level value as text ("true" for a true boolean).
# Prints nothing when the file is absent, malformed, not an object, or the key
# is missing, so a broken file reads exactly like an empty one.
json_top() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 0
  if [ "$json_backend" = "jq" ]; then
    jq -r --arg k "$key" '
      if type == "object" and has($k) and (.[$k] != null)
      then (.[$k] | tostring) else empty end
    ' "$file" 2> /dev/null || true
  else
    python3 -c "$py_top" "$file" "$key" 2> /dev/null || true
  fi
}

# json_profile_instruction <settings file> <profile id>
json_profile_instruction() {
  local file="$1" id="$2"
  [ -f "$file" ] || return 0
  if [ "$json_backend" = "jq" ]; then
    jq -r --arg id "$id" '
      (.profiles // []) | map(select(.id == $id)) | .[0].instruction // empty
    ' "$file" 2> /dev/null || true
  else
    python3 -c "$py_instruction" "$file" "$id" 2> /dev/null || true
  fi
}

# json_profile_exists <settings file> <profile id>: succeeds when the id is one
# of the profiles in settings.json.
json_profile_exists() {
  local file="$1" id="$2" found
  [ -f "$file" ] || return 1
  if [ "$json_backend" = "jq" ]; then
    found="$(jq -r --arg id "$id" '
      if ((.profiles // []) | map(select(.id == $id)) | length) > 0
      then "yes" else empty end
    ' "$file" 2> /dev/null || true)"
  else
    found="$(python3 -c "$py_exists" "$file" "$id" 2> /dev/null || true)"
  fi
  [ -n "$found" ]
}

# json_profile_attachments <settings file> <profile id>: one path per line,
# sorted, so the fingerprint does not depend on the order in settings.json.
json_profile_attachments() {
  local file="$1" id="$2"
  [ -f "$file" ] || return 0
  {
    if [ "$json_backend" = "jq" ]; then
      jq -r --arg id "$id" '
        (.profiles // []) | map(select(.id == $id))
        | .[0].attachments // [] | .[] | select(type == "string")
      ' "$file" 2> /dev/null || true
    else
      python3 -c "$py_attachments" "$file" "$id" 2> /dev/null || true
    fi
  } | LC_ALL=C sort
}

# read_fingerprint <asked file> <lock file>: the fingerprint the hook last
# recorded for this session, or nothing. The .asked file wins; only when there
# is none does a legacy "attachmentsRequestedFor" key in the lock count.
read_fingerprint() {
  local asked="$1" lock="$2"
  if [ -f "$asked" ]; then
    cat "$asked" 2> /dev/null || true
    return 0
  fi
  json_top "$lock" attachmentsRequestedFor
}

# write_fingerprint <asked file> <fingerprint>: replace the file whole, through
# a temp file in the same directory and a rename. remind.sh is its only writer,
# so there is nothing to merge and no other writer to race.
write_fingerprint() {
  local file="$1" value="$2" dir tmp
  dir="${file%/*}"
  tmp="${file}.tmp.$$"
  if mkdir -p "$dir" 2> /dev/null && printf '%s\n' "$value" > "$tmp" 2> /dev/null \
    && mv "$tmp" "$file" 2> /dev/null; then
    return 0
  fi
  rm -f "$tmp"
  return 1
}

# Drop session files (locks and fingerprints), and temp files left by an
# interrupted write, untouched for more than 7 days, so files for sessions that
# ended long ago do not accumulate. Called after a write, never on a plain read.
#
# The current session's own files are always kept: a session that runs for over
# a week, or one Aidiom pinned days ago, must not lose its lock or its
# fingerprint to housekeeping.
prune_stale_sessions() {
  local sessions keep="${CLAUDE_CODE_SESSION_ID:-}"
  sessions="$(state_root)/sessions"
  [ -d "$sessions" ] || return 0
  find "$sessions" -maxdepth 1 \
    \( -name '*.json' -o -name '*.json.tmp.*' -o -name '*.asked' -o -name '*.asked.tmp.*' \) \
    ! -name "${keep}.json" ! -name "${keep}.json.tmp.*" \
    ! -name "${keep}.asked" ! -name "${keep}.asked.tmp.*" \
    -mtime +7 -print0 2> /dev/null | xargs -0 rm -f 2> /dev/null || true
}

# Escape a string for use inside a JSON string literal, without the quotes.
#
# The backend does the escaping, because JSON requires every control character
# in U+0000-U+001F to be escaped, not only the familiar tab, CR and LF: a form
# feed or a vertical tab passed through raw makes the file (or the hook's own
# output) invalid, and a strict parser then rejects the whole document.
escape_json() {
  local s="$1" quoted
  if [ "$json_backend" = "jq" ]; then
    quoted="$(printf '%s' "$s" | jq -Rs . 2> /dev/null)"
  else
    quoted="$(printf '%s' "$s" | python3 -c "$py_escape" 2> /dev/null)"
  fi
  # jq and json.dumps both wrap the value in double quotes; drop them, so the
  # caller keeps building the surrounding JSON itself.
  quoted="${quoted#\"}"
  quoted="${quoted%\"}"
  printf '%s' "$quoted"
}
