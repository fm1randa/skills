#!/usr/bin/env bash
# Shared state helpers for the output-language skill: where the files live and
# how to read and write them. Sourced by lock.sh and remind.sh; not meant to be
# run on its own.
#
# File contract (also written by Aidiom, the macOS menu bar app):
#
#   $XDG_CONFIG_HOME/output-language        (or ~/.config/output-language)
#     settings.json
#       { "default": "<profile id>",
#         "profiles": [ { "id", "short", "label", "instruction",
#                         "attachments": ["<absolute path>", ...] } ] }
#     sessions/<session-id>.json            the Session Lock, one of:
#       { "profile": "<id>" }               pinned to a Language Profile
#       { "instruction": "<free text>" }    pinned to an ad hoc instruction
#       { "disabled": true }                output-language off for this session
#       plus "attachmentsRequestedFor": "<fingerprint>", written by remind.sh
#       once it has asked the Agent to read the profile's attachments. A file
#       with only that key still means "follows the Default Profile".
#
# JSON is parsed with jq when it is on PATH, else with python3; both backends
# keep each read to one short-lived process, which matters because the hook runs
# on every turn. Set OUTPUT_LANGUAGE_JSON_BACKEND to "jq" or "python3" to force
# one (the test runner uses it to cover both).

state_root() {
  printf '%s/output-language' "${XDG_CONFIG_HOME:-${HOME}/.config}"
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
  jq | python3)
    json_backend="$OUTPUT_LANGUAGE_JSON_BACKEND"
    ;;
  *)
    if command -v jq > /dev/null 2>&1; then
      json_backend="jq"
    else
      json_backend="python3"
    fi
    ;;
esac

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

# json_profile_exists <settings file> <profile id>: "yes" when the id is one of
# the profiles in settings.json, nothing otherwise.
json_profile_exists() {
  local file="$1" id="$2"
  [ -f "$file" ] || return 0
  if [ "$json_backend" = "jq" ]; then
    jq -r --arg id "$id" '
      if ((.profiles // []) | map(select(.id == $id)) | length) > 0
      then "yes" else empty end
    ' "$file" 2> /dev/null || true
  else
    python3 -c "$py_exists" "$file" "$id" 2> /dev/null || true
  fi
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

# json_set_top <file> <key> <value>: merge one string key into the object in
# <file>, creating the file (and its directory) when it is absent or unusable.
# The write is atomic: a temp file in the same directory, then a rename.
json_set_top() {
  local file="$1" key="$2" value="$3" base='{}' tmp status=0
  mkdir -p "$(dirname "$file")"
  if [ -f "$file" ]; then
    base="$(cat "$file")"
  fi
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
  mv "$tmp" "$file"
}

# Drop session files untouched for more than 7 days, so files for sessions that
# ended long ago do not accumulate. Called on a write, never on a plain read.
prune_stale_sessions() {
  local sessions
  sessions="$(state_root)/sessions"
  [ -d "$sessions" ] || return 0
  find "$sessions" -maxdepth 1 -name '*.json' -mtime +7 -delete 2> /dev/null || true
}

# Minimal JSON string escaping, so arbitrary instructions stay valid JSON.
escape_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\n'/\\n}"
  printf '%s' "$s"
}
