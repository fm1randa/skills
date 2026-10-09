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
#                         "attachments": ["<absolute path>", ...] } ],
#         "disabled": true }                optional: the Pause. While it is
#                                           true (or the text "true"),
#                                           remind.sh does nothing in any
#                                           session; removing it resumes.
#                                           Every writer must keep the key.
#     sessions/<session-id>.json            the Session Lock, one of:
#       { "profile": "<id>" }               pinned to a Language Profile
#       { "instruction": "<free text>" }    pinned to an ad hoc instruction
#       { "disabled": true }                output-language off for this session
#       plus "attachmentsRequestedFor": "<fingerprint>", written by remind.sh
#       once it has asked the Agent to read the profile's attachments. A file
#       with only that key still means "follows the Default Profile". The
#       fingerprint is the profile id and its sorted attachment paths joined by
#       newlines, the one character a path cannot hold, so two different
#       attachment sets can never produce the same fingerprint.
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

# Path of the Session Lock, or nothing when there is no session id.
lock_file() {
  local sid="${CLAUDE_CODE_SESSION_ID:-}"
  [ -n "$sid" ] || return 0
  printf '%s/sessions/%s.json' "$(state_root)" "$sid"
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

py_set_top='
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = None
if not isinstance(data, dict):
    data = {}
data[sys.argv[1]] = sys.argv[2]
json.dump(data, sys.stdout, indent=2, ensure_ascii=False)
sys.stdout.write("\n")
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

# json_set_top <file> <key> <value> <expected>: merge one string key into the
# object <expected> and write the result to <file>, creating the file and its
# directory as needed. The write is atomic: a temp file in the same directory,
# then a rename.
#
# <expected> is the content the caller read earlier (empty for "the file did not
# exist"), and the write is a compare-and-swap on it: if the file no longer holds
# that content, someone else -- lock.sh in another turn, or Aidiom -- has written
# a newer lock, and merging stale content over it would silently undo their
# write. The function then leaves the file alone and fails, so the caller can
# skip this turn; the next turn re-reads and merges onto what it finds.
json_set_top() {
  local file="$1" key="$2" value="$3" expected="${4-}" base tmp status=0 dir
  base="$expected"
  # An absent file merges into a fresh object.
  [ -n "$base" ] || base='{}'
  dir="${file%/*}"
  [ "$dir" = "$file" ] || mkdir -p "$dir"
  tmp="${file}.tmp.$$"
  if [ "$json_backend" = "jq" ]; then
    printf '%s' "$base" | jq --arg k "$key" --arg v "$value" \
      'if type == "object" then . else {} end | .[$k] = $v' > "$tmp" 2> /dev/null || status=$?
  else
    printf '%s' "$base" | python3 -c "$py_set_top" "$key" "$value" > "$tmp" 2> /dev/null || status=$?
  fi
  if [ "$status" -ne 0 ]; then
    rm -f "$tmp"
    return 1
  fi
  commit_if_unchanged "$file" "$tmp" "$expected"
}

# commit_if_unchanged <file> <tmp> <expected>: the last step of every
# compare-and-swap write. Rename the prepared <tmp> over <file> if <file> still
# holds <expected> (empty for "the file does not exist"); otherwise remove <tmp>
# and fail, leaving <file> as the other writer left it.
#
# The compare, as late as possible: the caller only prepared a temp file, so this
# compare and the rename are all that a concurrent writer can interleave with. A
# write that lands between the two is still overwritten; the window is that
# small, not closed.
commit_if_unchanged() {
  local file="$1" tmp="$2" expected="$3" current
  current="$(cat "$file" 2> /dev/null || true)"
  if [ "$current" != "$expected" ]; then
    rm -f "$tmp"
    return 1
  fi
  mv "$tmp" "$file"
}

py_edit_top='
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if not isinstance(data, dict):
    sys.exit(1)
if sys.argv[2] == "set":
    data[sys.argv[1]] = True
else:
    data.pop(sys.argv[1], None)
json.dump(data, sys.stdout, indent=2, ensure_ascii=False)
sys.stdout.write("\n")
'

# json_edit_top <file> <key> <set|delete>: set one top-level key to true, or
# delete it, keeping every other key. Unlike json_set_top, this one is strict:
# it fails, and leaves the file byte-for-byte as it was, when the file is
# missing, malformed or not an object, because settings.json holds the user's
# profiles and must never be replaced by an object built from nothing.
#
# The exit code tells the caller which message is true: 1 when the file is
# missing or cannot be read, 2 when it is not a JSON object, 3 when it changed
# while it was being written, 4 when the mode is neither set nor delete.
#
# The write is atomic (a temp file, then a rename) and a compare-and-swap on
# what was read, so an edit Aidiom saves while the new content is prepared is
# not overwritten; see commit_if_unchanged for the window that remains.
json_edit_top() {
  local file="$1" key="$2" op="$3" before tmp status=0
  # Spelled out, so a typo fails here instead of silently deleting the key.
  case "$op" in
    set | delete) ;;
    *)
      echo "json_edit_top: unknown mode '${op}'; expected set or delete." >&2
      return 4
      ;;
  esac
  [ -f "$file" ] || return 1
  before="$(cat "$file" 2> /dev/null)" || return 1
  tmp="${file}.tmp.$$"
  if [ "$json_backend" = "jq" ]; then
    # -e: an empty file yields no value at all, which must fail, not write "".
    printf '%s' "$before" | jq -e --arg k "$key" --arg op "$op" '
      if type != "object" then error("not an object")
      elif $op == "set" then .[$k] = true
      else del(.[$k]) end
    ' > "$tmp" 2> /dev/null || status=$?
  else
    printf '%s' "$before" | python3 -c "$py_edit_top" "$key" "$op" > "$tmp" 2> /dev/null || status=$?
  fi
  if [ "$status" -ne 0 ]; then
    rm -f "$tmp"
    return 2
  fi
  commit_if_unchanged "$file" "$tmp" "$before" || return 3
}

# Drop session files, and temp files left by an interrupted write, untouched for
# more than 7 days, so files for sessions that ended long ago do not accumulate.
# Called after a write, never on a plain read.
#
# The current session's own file is always kept: a session that runs for over a
# week, or one Aidiom pinned days ago, must not lose its lock to housekeeping.
prune_stale_sessions() {
  local sessions keep="${CLAUDE_CODE_SESSION_ID:-}"
  sessions="$(state_root)/sessions"
  [ -d "$sessions" ] || return 0
  find "$sessions" -maxdepth 1 \
    \( -name '*.json' -o -name '*.json.tmp.*' \) \
    ! -name "${keep}.json" ! -name "${keep}.json.tmp.*" \
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
