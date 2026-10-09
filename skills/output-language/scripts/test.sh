#!/usr/bin/env bash
# Black-box tests for lock.sh and remind.sh.
#
# Plain bash, no framework. Every case runs in its own temp directory with
# HOME, XDG_CONFIG_HOME and CLAUDE_CODE_SESSION_ID pointed at it, so the tests
# never read or write the real state root. Assertions look only at what a
# caller can see: stdout, exit code and the resulting files.
#
# Requires python3 (to read JSON in the assertions). Every case runs once per
# JSON backend the scripts can use: jq when it is installed, and python3.
#
# Usage: bash scripts/test.sh
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lock="${script_dir}/lock.sh"
remind="${script_dir}/remind.sh"

tests_run=0
tests_failed=0
current_test=""
sandbox=""

fail() {
  echo "  FAIL: $*" >&2
  tests_failed=$((tests_failed + 1))
}

assert_eq() {
  local expected="$1" actual="$2" what="${3:-value}"
  if [ "$expected" != "$actual" ]; then
    fail "${what}: expected '${expected}', got '${actual}'"
  fi
}

assert_empty() {
  local actual="$1" what="${2:-value}"
  if [ -n "$actual" ]; then
    fail "${what}: expected nothing, got '${actual}'"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" what="${3:-output}"
  case "$haystack" in
    *"$needle"*) ;;
    *) fail "${what}: expected to contain '${needle}', got '${haystack}'" ;;
  esac
}

assert_not_contains() {
  local haystack="$1" needle="$2" what="${3:-output}"
  case "$haystack" in
    *"$needle"*) fail "${what}: expected NOT to contain '${needle}', got '${haystack}'" ;;
  esac
}

assert_no_file() {
  [ ! -e "$1" ] || fail "expected '$1' not to exist"
}

assert_file() {
  [ -e "$1" ] || fail "expected '$1' to exist"
}

# Both helpers below print an empty line when the JSON is absent, unparseable or
# the path is missing, so an assertion reports the value instead of a traceback.
py_pick='
import json, sys
try:
    node = json.load(open(sys.argv[1]) if sys.argv[1] != "-" else sys.stdin)
except Exception:
    print("")
    sys.exit(0)
for key in sys.argv[2:]:
    node = node.get(key) if isinstance(node, dict) else None
    if node is None:
        print("")
        sys.exit(0)
print(node if isinstance(node, str) else json.dumps(node))
'

# json_get <file> <key> [<key>...]
json_get() {
  python3 -c "$py_pick" "$@"
}

# json_stdin <key> [<key>...] -- the JSON comes in on stdin
json_stdin() {
  python3 -c "$py_pick" - "$@"
}

# ---------------------------------------------------------------- sandbox ---

setup() {
  current_test="$1"
  tests_run=$((tests_run + 1))
  echo "- ${current_test}"
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/output-language-test.XXXXXX")"
  export HOME="${sandbox}/home"
  export XDG_CONFIG_HOME="${sandbox}/home/.config"
  export CLAUDE_CODE_SESSION_ID="session-under-test"
  # empty-bin stands in for a PATH with neither jq nor python3 on it.
  mkdir -p "$XDG_CONFIG_HOME" "${HOME}/.claude" "${sandbox}/empty-bin"
  root="${XDG_CONFIG_HOME}/output-language"
  lock_file="${root}/sessions/${CLAUDE_CODE_SESSION_ID}.json"
  asked_file="${root}/sessions/${CLAUDE_CODE_SESSION_ID}.asked"
}

cleanup() {
  if [ -n "${sandbox:-}" ]; then
    rm -rf "$sandbox"
  fi
  return 0
}

# So an interrupted run does not leave a sandbox behind in the temp directory.
trap cleanup EXIT INT TERM

teardown() {
  cleanup
  sandbox=""
}

write_settings() {
  mkdir -p "$root"
  cat > "${root}/settings.json"
}

# Two profiles: the default carries no attachments, the other carries two.
seed_settings() {
  write_settings <<'JSON'
{
  "default": "en-ste",
  "profiles": [
    {
      "id": "en-ste",
      "short": "EN",
      "label": "American English",
      "instruction": "American English, per ASD-STE100 Simplified Technical English",
      "attachments": []
    },
    {
      "id": "pt-abnt",
      "short": "PT",
      "label": "Portugues",
      "instruction": "portugues brasileiro, per ABNT NBR ISO 24495-1",
      "attachments": ["/tmp/b-guide.pdf", "/tmp/a-guide.pdf"]
    }
  ]
}
JSON
}

write_lock() {
  mkdir -p "${root}/sessions"
  cat > "$lock_file"
}

write_asked() {
  mkdir -p "${root}/sessions"
  printf '%s\n' "$1" > "$asked_file"
}

# The fingerprint the hook recorded, or nothing when it recorded none.
asked() {
  cat "$asked_file" 2> /dev/null || true
}

eight_days_ago() {
  date -v-8d +%Y%m%d%H%M 2>/dev/null || date -d '8 days ago' +%Y%m%d%H%M
}

# ------------------------------------------------------------------ cases ---

test_silent_with_no_config() {
  setup "silent when there is no settings.json and no lock"
  local out status
  out="$(bash "$remind" UserPromptSubmit 2>&1)"
  status=$?
  assert_eq 0 "$status" "exit code"
  assert_empty "$out" "stdout"
  teardown
}

test_default_injected() {
  setup "injects the Default Profile when the session has no lock"
  seed_settings
  local out msg
  out="$(bash "$remind" UserPromptSubmit)"
  assert_eq "UserPromptSubmit" "$(printf '%s' "$out" | json_stdin hookSpecificOutput hookEventName)" "hookEventName"
  msg="$(printf '%s' "$out" | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "OUTPUT LANGUAGE LOCK" "message"
  assert_contains "$msg" "American English, per ASD-STE100 Simplified Technical English" "message"
  assert_no_file "$lock_file"
  teardown
}

test_default_injected_without_session_id() {
  setup "injects the Default Profile even with no session id, and asks for nothing"
  seed_settings
  local out msg
  out="$(env -u CLAUDE_CODE_SESSION_ID bash "$remind" UserPromptSubmit)"
  msg="$(printf '%s' "$out" | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "American English" "message"
  # With no session id there is nowhere to record a fingerprint, or a lock.
  assert_no_file "${root}/sessions"
  teardown
}

test_profile_lock_beats_default() {
  setup "a lock by profile id beats the Default Profile"
  seed_settings
  write_lock <<'JSON'
{ "profile": "pt-abnt" }
JSON
  local out msg
  out="$(bash "$remind" UserPromptSubmit)"
  msg="$(printf '%s' "$out" | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "portugues brasileiro, per ABNT NBR ISO 24495-1" "message"
  assert_not_contains "$msg" "American English" "message"
  teardown
}

test_free_text_lock() {
  setup "a free-text lock is injected verbatim and carries no attachments"
  seed_settings
  write_lock <<'JSON'
{ "instruction": "Middle English, and rhyme every third line" }
JSON
  local out msg
  out="$(bash "$remind" UserPromptSubmit)"
  msg="$(printf '%s' "$out" | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "Middle English, and rhyme every third line" "message"
  assert_not_contains "$msg" "guide.pdf" "message"
  assert_no_file "$asked_file"
  teardown
}

test_unknown_profile_falls_back_to_default() {
  setup "a lock naming a deleted profile falls back to the Default Profile"
  seed_settings
  write_lock <<'JSON'
{ "profile": "nl-gone" }
JSON
  local out msg
  out="$(bash "$remind" UserPromptSubmit)"
  msg="$(printf '%s' "$out" | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "American English" "message"
  teardown
}

test_post_tool_use_shape() {
  setup "PostToolUse keeps its own message shape"
  seed_settings
  local out msg
  out="$(bash "$remind" PostToolUse)"
  assert_eq "PostToolUse" "$(printf '%s' "$out" | json_stdin hookSpecificOutput hookEventName)" "hookEventName"
  msg="$(printf '%s' "$out" | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "A skill just loaded" "message"
  assert_contains "$msg" "American English, per ASD-STE100 Simplified Technical English" "message"
  teardown
}

test_post_tool_use_never_requests_attachments() {
  setup "PostToolUse never asks for attachments and never writes the fingerprint"
  seed_settings
  write_lock <<'JSON'
{ "profile": "pt-abnt" }
JSON
  local out msg
  out="$(bash "$remind" PostToolUse)"
  msg="$(printf '%s' "$out" | json_stdin hookSpecificOutput additionalContext)"
  assert_not_contains "$msg" "a-guide.pdf" "message"
  assert_no_file "$asked_file"
  teardown
}

test_attachments_requested_once() {
  setup "attachments are requested once, then not again"
  seed_settings
  write_lock <<'JSON'
{ "profile": "pt-abnt" }
JSON
  local first second msg fingerprint
  first="$(bash "$remind" UserPromptSubmit)"
  msg="$(printf '%s' "$first" | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "/tmp/a-guide.pdf" "first message"
  assert_contains "$msg" "/tmp/b-guide.pdf" "first message"
  fingerprint="$(asked)"
  assert_eq "$(printf 'pt-abnt\n/tmp/a-guide.pdf\n/tmp/b-guide.pdf')" "$fingerprint" "fingerprint"
  # The hook never writes the Session Lock.
  assert_eq '{ "profile": "pt-abnt" }' "$(cat "$lock_file")" "the lock, byte for byte"

  second="$(bash "$remind" UserPromptSubmit)"
  msg="$(printf '%s' "$second" | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "portugues brasileiro" "second message"
  assert_not_contains "$msg" "/tmp/a-guide.pdf" "second message"
  teardown
}

test_attachments_for_inheriting_session() {
  setup "an inheriting session with attachments leaves no lock file behind"
  write_settings <<'JSON'
{
  "default": "pt-abnt",
  "profiles": [
    {
      "id": "pt-abnt",
      "short": "PT",
      "label": "Portugues",
      "instruction": "portugues brasileiro",
      "attachments": ["/tmp/a-guide.pdf"]
    }
  ]
}
JSON
  local out msg
  out="$(bash "$remind" UserPromptSubmit)"
  msg="$(printf '%s' "$out" | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "/tmp/a-guide.pdf" "message"
  assert_no_file "$lock_file"
  assert_eq "$(printf 'pt-abnt\n/tmp/a-guide.pdf')" "$(asked)" "fingerprint"
  # Still inheriting: the next turn asks nothing more.
  msg="$(bash "$remind" UserPromptSubmit | json_stdin hookSpecificOutput additionalContext)"
  assert_not_contains "$msg" "/tmp/a-guide.pdf" "second message"
  assert_no_file "$lock_file"
  teardown
}

# Two profiles that both carry attachments, so a switch between them changes the
# fingerprint.
seed_two_attached_profiles() {
  write_settings <<'JSON'
{
  "default": "en-ste",
  "profiles": [
    { "id": "en-ste", "short": "EN", "label": "American English",
      "instruction": "American English", "attachments": ["/tmp/ste.pdf"] },
    { "id": "pt-abnt", "short": "PT", "label": "Portugues",
      "instruction": "portugues brasileiro", "attachments": ["/tmp/a-guide.pdf"] }
  ]
}
JSON
}

test_switching_profiles_asks_once_for_the_new_attachments() {
  setup "switching profiles asks for the new profile's attachments once"
  seed_two_attached_profiles
  bash "$lock" pt-abnt > /dev/null
  bash "$remind" UserPromptSubmit > /dev/null
  assert_eq "$(printf 'pt-abnt\n/tmp/a-guide.pdf')" "$(asked)" "fingerprint"

  bash "$lock" en-ste > /dev/null
  # The pin replaced the lock and left the fingerprint file to the hook.
  assert_eq "$(printf 'pt-abnt\n/tmp/a-guide.pdf')" "$(asked)" "fingerprint after the pin"

  local msg
  msg="$(bash "$remind" UserPromptSubmit | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "/tmp/ste.pdf" "first message after the switch"
  assert_eq "$(printf 'en-ste\n/tmp/ste.pdf')" "$(asked)" "fingerprint after the switch"
  msg="$(bash "$remind" UserPromptSubmit | json_stdin hookSpecificOutput additionalContext)"
  assert_not_contains "$msg" "/tmp/ste.pdf" "second message after the switch"
  teardown
}

test_off_and_default_leave_the_fingerprint_alone() {
  setup "off and default never touch the fingerprint file"
  seed_two_attached_profiles
  bash "$lock" pt-abnt > /dev/null
  bash "$remind" UserPromptSubmit > /dev/null
  local before
  before="$(asked)"
  bash "$lock" off > /dev/null
  assert_eq "$before" "$(asked)" "fingerprint after off"
  bash "$lock" default > /dev/null
  assert_eq "$before" "$(asked)" "fingerprint after default"
  assert_no_file "$lock_file"
  # Back on the default, a different profile: asked again, once.
  local msg
  msg="$(bash "$remind" UserPromptSubmit | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "/tmp/ste.pdf" "message on the default"
  assert_no_file "$lock_file"
  teardown
}

test_fingerprint_change_requests_again() {
  setup "a different profile fingerprint asks again"
  seed_settings
  write_lock <<'JSON'
{ "profile": "pt-abnt" }
JSON
  write_asked "en-ste"
  local msg
  msg="$(bash "$remind" UserPromptSubmit | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "/tmp/a-guide.pdf" "message"
  assert_eq "$(printf 'pt-abnt\n/tmp/a-guide.pdf\n/tmp/b-guide.pdf')" "$(asked)" "fingerprint"
  teardown
}

test_a_legacy_fingerprint_in_the_lock_is_still_honored() {
  setup "a lock still holding attachmentsRequestedFor from before does not ask again"
  seed_settings
  write_lock <<'JSON'
{ "profile": "pt-abnt", "attachmentsRequestedFor": "pt-abnt\n/tmp/a-guide.pdf\n/tmp/b-guide.pdf" }
JSON
  local before msg
  before="$(cat "$lock_file")"
  msg="$(bash "$remind" UserPromptSubmit | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "portugues brasileiro" "message"
  assert_not_contains "$msg" "/tmp/a-guide.pdf" "message"
  assert_eq "$before" "$(cat "$lock_file")" "the lock, byte for byte"
  teardown
}

test_a_legacy_fingerprint_gives_way_to_the_asked_file() {
  setup "once the fingerprint file exists, a stale key in the lock is ignored"
  seed_settings
  write_lock <<'JSON'
{ "profile": "pt-abnt", "attachmentsRequestedFor": "en-ste" }
JSON
  local before msg
  before="$(cat "$lock_file")"
  msg="$(bash "$remind" UserPromptSubmit | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "/tmp/a-guide.pdf" "first message"
  assert_eq "$before" "$(cat "$lock_file")" "the lock, byte for byte"
  msg="$(bash "$remind" UserPromptSubmit | json_stdin hookSpecificOutput additionalContext)"
  assert_not_contains "$msg" "/tmp/a-guide.pdf" "second message"
  teardown
}

test_malformed_settings_stays_silent() {
  setup "malformed settings.json never blocks a prompt"
  write_settings <<'JSON'
{ "default": "en-ste", "profiles": [ { "id": "en-ste",
JSON
  local out status
  out="$(bash "$remind" UserPromptSubmit 2>&1)"
  status=$?
  assert_eq 0 "$status" "exit code"
  assert_empty "$out" "stdout"
  teardown
}

test_malformed_lock_falls_back_to_default() {
  setup "a malformed lock file falls back to the Default Profile"
  seed_settings
  write_lock <<'JSON'
{ "profile":
JSON
  local msg
  msg="$(bash "$remind" UserPromptSubmit | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "American English" "message"
  teardown
}

test_lock_by_profile_id() {
  setup "lock.sh maps a known profile id to a profile lock"
  seed_settings
  bash "$lock" pt-abnt > /dev/null
  assert_eq "pt-abnt" "$(json_get "$lock_file" profile)" "profile"
  assert_empty "$(json_get "$lock_file" instruction)" "instruction"
  teardown
}

test_lock_by_free_text() {
  setup "lock.sh maps anything else to a free-text instruction"
  seed_settings
  bash "$lock" "Middle English" > /dev/null
  assert_eq "Middle English" "$(json_get "$lock_file" instruction)" "instruction"
  assert_empty "$(json_get "$lock_file" profile)" "profile"
  teardown
}

test_lock_free_text_without_settings() {
  setup "lock.sh works with no settings.json at all"
  bash "$lock" "American English" > /dev/null
  assert_eq "American English" "$(json_get "$lock_file" instruction)" "instruction"
  teardown
}

test_default_deletes_the_lock() {
  setup "lock.sh default deletes the lock so the session inherits"
  seed_settings
  write_lock <<'JSON'
{ "profile": "pt-abnt" }
JSON
  bash "$lock" default > /dev/null
  assert_no_file "$lock_file"
  local msg
  msg="$(bash "$remind" UserPromptSubmit | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "American English" "message"
  teardown
}

test_off_disables_the_session() {
  setup "lock.sh off writes the disabled state and the hook goes silent"
  seed_settings
  bash "$lock" off > /dev/null
  assert_eq "true" "$(json_get "$lock_file" disabled)" "disabled"
  local hook status
  hook="$(bash "$remind" UserPromptSubmit 2>&1)"
  status=$?
  assert_eq 0 "$status" "exit code"
  assert_empty "$hook" "stdout"
  assert_empty "$(bash "$remind" PostToolUse 2>&1)" "PostToolUse stdout"
  teardown
}

test_off_synonyms_disable() {
  setup "every off synonym writes the disabled state"
  seed_settings
  local word
  for word in off clear none unlock unlocked OFF desativar desligar destravar ""; do
    rm -f "$lock_file"
    bash "$lock" "$word" > /dev/null
    assert_eq "true" "$(json_get "$lock_file" disabled)" "disabled for '${word}'"
  done
  teardown
}

test_relock_after_off() {
  setup "locking again after off drops the disabled state"
  seed_settings
  bash "$lock" off > /dev/null
  bash "$lock" pt-abnt > /dev/null
  assert_empty "$(json_get "$lock_file" disabled)" "disabled"
  assert_eq "pt-abnt" "$(json_get "$lock_file" profile)" "profile"
  teardown
}

test_lock_requires_session_id() {
  setup "lock.sh fails loudly with no session id"
  seed_settings
  local out status
  out="$(env -u CLAUDE_CODE_SESSION_ID bash "$lock" pt-abnt 2>&1)"
  status=$?
  assert_eq 1 "$status" "exit code"
  assert_contains "$out" "CLAUDE_CODE_SESSION_ID" "stderr"
  teardown
}

test_stale_sessions_are_pruned() {
  setup "session files untouched for more than 7 days are pruned"
  seed_settings
  mkdir -p "${root}/sessions"
  local stale="${root}/sessions/long-gone.json"
  local stale_asked="${root}/sessions/long-gone.asked"
  local fresh_asked="${root}/sessions/still-here.asked"
  echo '{ "profile": "pt-abnt" }' > "$stale"
  echo 'pt-abnt' > "$stale_asked"
  echo 'pt-abnt' > "$fresh_asked"
  touch -t "$(eight_days_ago)" "$stale" "$stale_asked"
  bash "$lock" pt-abnt > /dev/null
  assert_no_file "$stale"
  assert_no_file "$stale_asked"
  assert_file "$fresh_asked"
  assert_file "$lock_file"
  teardown
}

test_own_session_survives_the_prune() {
  setup "the current session's own lock and fingerprint survive the prune, however old"
  write_settings <<'JSON'
{
  "default": "pt-abnt",
  "profiles": [
    {
      "id": "pt-abnt",
      "short": "PT",
      "label": "Portugues",
      "instruction": "portugues brasileiro",
      "attachments": ["/tmp/a-guide.pdf"]
    }
  ]
}
JSON
  write_lock <<'JSON'
{ "profile": "pt-abnt" }
JSON
  write_asked "en-ste"
  touch -t "$(eight_days_ago)" "$lock_file" "$asked_file"
  # The prune runs on this turn, because the hook writes the fingerprint.
  bash "$remind" UserPromptSubmit > /dev/null
  assert_file "$lock_file"
  assert_eq "pt-abnt" "$(json_get "$lock_file" profile)" "profile kept"
  assert_eq "$(printf 'pt-abnt\n/tmp/a-guide.pdf')" "$(asked)" "fingerprint"
  # An old fingerprint that this turn does not rewrite survives too.
  touch -t "$(eight_days_ago)" "$lock_file" "$asked_file"
  bash "$lock" pt-abnt > /dev/null
  assert_file "$asked_file"
  teardown
}

test_pinned_profile_without_instruction_is_silent() {
  setup "a lock on a profile that says nothing injects nothing"
  write_settings <<'JSON'
{
  "default": "en-ste",
  "profiles": [
    {
      "id": "en-ste",
      "short": "EN",
      "label": "American English",
      "instruction": "American English",
      "attachments": []
    },
    { "id": "quiet", "short": "--", "label": "Quiet", "instruction": "", "attachments": [] }
  ]
}
JSON
  write_lock <<'JSON'
{ "profile": "quiet" }
JSON
  local out status
  out="$(bash "$remind" UserPromptSubmit 2>&1)"
  status=$?
  assert_eq 0 "$status" "exit code"
  assert_empty "$out" "stdout"
  teardown
}

test_stale_temp_files_are_pruned() {
  setup "a temp file left by an interrupted write is pruned once stale"
  seed_settings
  mkdir -p "${root}/sessions"
  local stale="${root}/sessions/long-gone.json.tmp.4242"
  local stale_asked="${root}/sessions/long-gone.asked.tmp.4242"
  local mine="${lock_file}.tmp.4242"
  local mine_asked="${asked_file}.tmp.4242"
  echo '{ "profile": "pt-abnt" }' > "$stale"
  echo 'pt-abnt' > "$stale_asked"
  echo '{ "profile": "pt-abnt" }' > "$mine"
  echo 'pt-abnt' > "$mine_asked"
  touch -t "$(eight_days_ago)" "$stale" "$stale_asked" "$mine" "$mine_asked"
  bash "$lock" pt-abnt > /dev/null
  assert_no_file "$stale"
  assert_no_file "$stale_asked"
  # The current session's own leftovers are kept, like its lock file.
  assert_file "$mine"
  assert_file "$mine_asked"
  teardown
}

test_settings_without_profiles() {
  setup "settings.json with a default but no profiles key at all"
  write_settings <<'JSON'
{ "default": "en-ste" }
JSON
  local out status
  out="$(bash "$remind" UserPromptSubmit 2>&1)"
  status=$?
  assert_eq 0 "$status" "remind exit code"
  assert_empty "$out" "remind stdout"
  # No profile can be found, so even a plausible id is an ad hoc instruction.
  bash "$lock" en-ste > /dev/null
  assert_eq "en-ste" "$(json_get "$lock_file" instruction)" "instruction"
  assert_empty "$(json_get "$lock_file" profile)" "profile"
  teardown
}

test_relock_during_a_turn_survives() {
  setup "a relock landing mid-turn survives the fingerprint write"
  # The hook no longer writes the lock, so this holds by construction; it stays
  # as a guard against the hook ever writing the lock again.
  write_settings <<'JSON'
{
  "default": "pt-abnt",
  "profiles": [
    { "id": "pt-abnt", "short": "PT", "label": "Portugues",
      "instruction": "portugues brasileiro", "attachments": ["/tmp/a-guide.pdf"] }
  ]
}
JSON
  write_lock <<'JSON'
{ "profile": "pt-abnt" }
JSON
  # A shim in front of the JSON backend replaces the lock file while the hook is
  # reading the attachments: a real interleaving, not a simulated one.
  local tool real out msg
  mkdir -p "${sandbox}/shim"
  for tool in jq python3; do
    real="$(command -v "$tool" 2> /dev/null || true)"
    [ -n "$real" ] || continue
    {
      echo '#!/bin/sh'
      echo 'case "$*" in'
      echo '  *attachments*)'
      printf "    printf '%%s\\\\n' '{ \"instruction\": \"relocked mid-turn\" }' > %s\n" "$lock_file"
      echo '    ;;'
      echo 'esac'
      printf 'exec %s "$@"\n' "$real"
    } > "${sandbox}/shim/${tool}"
    chmod +x "${sandbox}/shim/${tool}"
  done

  out="$(env PATH="${sandbox}/shim:${PATH}" bash "$remind" UserPromptSubmit)"
  msg="$(printf '%s' "$out" | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "portugues brasileiro" "message"
  assert_eq "relocked mid-turn" "$(json_get "$lock_file" instruction)" "the newer lock survives"
  assert_eq "$(printf '{ "instruction": "relocked mid-turn" }')" "$(cat "$lock_file")" "the lock, byte for byte"
  assert_eq "$(printf 'pt-abnt\n/tmp/a-guide.pdf')" "$(asked)" "fingerprint"
  teardown
}

test_no_backend_fails_lock_loudly() {
  setup "lock.sh fails loudly, and writes nothing, without a JSON backend"
  seed_settings
  local out status
  # A forced backend is honored as given, so this stands in for a machine with
  # neither jq nor python3.
  out="$(OUTPUT_LANGUAGE_JSON_BACKEND=no-such-backend bash "$lock" pt-abnt 2>&1)"
  status=$?
  assert_eq 1 "$status" "exit code"
  assert_contains "$out" "no usable JSON backend" "stderr"
  assert_no_file "$lock_file"

  # The same, arrived at honestly: an empty PATH hides both jq and python3.
  out="$(env PATH="${sandbox}/empty-bin" /bin/bash "$lock" pt-abnt 2>&1)"
  status=$?
  assert_eq 1 "$status" "exit code with an empty PATH"
  assert_contains "$out" "no usable JSON backend" "stderr with an empty PATH"
  assert_no_file "$lock_file"
  teardown
}

test_no_backend_keeps_the_hook_silent() {
  setup "remind.sh stays silent, exit 0, without a JSON backend"
  seed_settings
  local out status
  out="$(OUTPUT_LANGUAGE_JSON_BACKEND=no-such-backend bash "$remind" UserPromptSubmit 2>&1)"
  status=$?
  assert_eq 0 "$status" "exit code"
  assert_empty "$out" "stdout"

  out="$(env PATH="${sandbox}/empty-bin" /bin/bash "$remind" UserPromptSubmit 2>&1)"
  status=$?
  assert_eq 0 "$status" "exit code with an empty PATH"
  assert_empty "$out" "stdout with an empty PATH"
  teardown
}

test_relative_xdg_config_home_is_ignored() {
  setup "a relative or empty XDG_CONFIG_HOME falls back to ~/.config"
  # Seed the real fallback root, then point XDG_CONFIG_HOME at a relative path.
  root="${HOME}/.config/output-language"
  seed_settings
  local msg value
  for value in "relative/config" "" "."; do
    msg="$(XDG_CONFIG_HOME="$value" bash "$remind" UserPromptSubmit \
      | json_stdin hookSpecificOutput additionalContext)"
    assert_contains "$msg" "American English" "message for XDG_CONFIG_HOME='${value}'"
  done
  # Nothing was created next to the working directory.
  assert_no_file "${PWD}/relative"
  teardown
}

test_fingerprint_separator_cannot_collide() {
  setup "attachment sets that differ only in a '|' still ask again"
  write_settings <<'JSON'
{
  "default": "pipe",
  "profiles": [
    { "id": "pipe", "short": "PI", "label": "Pipe", "instruction": "Pipe profile",
      "attachments": ["/tmp/a|b.pdf"] }
  ]
}
JSON
  local msg
  msg="$(bash "$remind" UserPromptSubmit | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "/tmp/a|b.pdf" "first message"
  assert_eq "$(printf 'pipe\n/tmp/a|b.pdf')" "$(asked)" "fingerprint"

  # Same profile id, two paths whose naive join is the same string as above.
  write_settings <<'JSON'
{
  "default": "pipe",
  "profiles": [
    { "id": "pipe", "short": "PI", "label": "Pipe", "instruction": "Pipe profile",
      "attachments": ["/tmp/a", "b.pdf"] }
  ]
}
JSON
  msg="$(bash "$remind" UserPromptSubmit | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "/tmp/a" "second message asks again"
  assert_eq "$(printf 'pipe\n/tmp/a\nb.pdf')" "$(asked)" "fingerprint"
  teardown
}

# Form feed, bell and vertical tab: control characters that JSON requires to be
# escaped, and that the familiar tab/CR/LF cases miss.
control_chars_text() {
  printf 'ring \a, feed \f, climb \v, and stop'
}

test_control_characters_in_a_lock_instruction() {
  setup "control characters in a lock instruction survive a round trip"
  seed_settings
  local text msg
  text="$(control_chars_text)"
  bash "$lock" "$text" > /dev/null
  # json_get parses strictly, so it returns nothing if the file is invalid JSON.
  assert_eq "$text" "$(json_get "$lock_file" instruction)" "instruction on disk"
  msg="$(bash "$remind" UserPromptSubmit | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "$text" "message"
  teardown
}

test_control_characters_in_a_profile_instruction() {
  setup "control characters in a profile instruction stay escaped in the output"
  # The fixture spells them as \u escapes, which is how a valid settings.json
  # written by Aidiom or by hand carries a control character.
  write_settings <<'JSON'
{
  "default": "ctl",
  "profiles": [
    {
      "id": "ctl",
      "short": "CT",
      "label": "Controls",
      "instruction": "ring \u0007, feed \u000c, climb \u000b, and stop",
      "attachments": []
    }
  ]
}
JSON
  local msg
  msg="$(bash "$remind" UserPromptSubmit | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "$(control_chars_text)" "UserPromptSubmit message"
  msg="$(bash "$remind" PostToolUse | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "$(control_chars_text)" "PostToolUse message"
  teardown
}

test_json_escaping() {
  setup "quotes and backslashes in an instruction stay valid JSON"
  bash "$lock" 'say "hi\there" and stop' > /dev/null
  local msg
  msg="$(bash "$remind" UserPromptSubmit | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" 'say "hi\there" and stop' "message"
  teardown
}

# ------------------------------------------------------------------ pause ---

# The Pause: the sentinel file in the state root. Its content is ignored, so the
# timestamp here is only what a writer would put there for a human to read.
seed_pause() {
  mkdir -p "$root"
  date -u +%Y-%m-%dT%H:%M:%SZ > "${root}/paused"
}

# Every remind.sh event, for one session state, prints nothing and exits 0.
assert_hook_silent() {
  local what="$1" event out status
  for event in UserPromptSubmit PostToolUse; do
    out="$(bash "$remind" "$event" 2>&1)"
    status=$?
    assert_eq 0 "$status" "${what}: ${event} exit code"
    assert_empty "$out" "${what}: ${event} stdout"
  done
}

test_pause_silences_every_session() {
  setup "while paused, the hook says nothing to any kind of session"
  seed_settings
  seed_pause
  assert_hook_silent "no lock file"
  write_lock <<'JSON'
{ "profile": "pt-abnt" }
JSON
  assert_hook_silent "pinned to a profile"
  write_lock <<'JSON'
{ "instruction": "Middle English" }
JSON
  assert_hook_silent "pinned to free text"
  write_lock <<'JSON'
{ "attachmentsRequestedFor": "en-ste" }
JSON
  assert_hook_silent "inheriting"
  teardown
}

test_pause_holds_whatever_the_sentinel_says() {
  setup "the sentinel pauses whatever it holds, even nothing"
  seed_settings
  write_lock <<'JSON'
{ "profile": "pt-abnt" }
JSON
  local body
  for body in '' 'false' '{"disabled": false}'; do
    mkdir -p "$root"
    printf '%s' "$body" > "${root}/paused"
    assert_hook_silent "sentinel holding '${body}'"
  done
  teardown
}

test_pause_comes_before_the_backend_check() {
  setup "while paused, the hook is silent even with an unusable JSON backend"
  seed_settings
  seed_pause
  local out status
  out="$(OUTPUT_LANGUAGE_JSON_BACKEND=no-such-backend bash "$remind" UserPromptSubmit 2>&1)"
  status=$?
  assert_eq 0 "$status" "exit code"
  assert_empty "$out" "stdout"
  teardown
}

test_pause_writes_and_prunes_nothing() {
  setup "while paused, the hook writes no fingerprint and prunes nothing"
  seed_settings
  seed_pause
  # Unpaused, this turn would ask for pt-abnt's attachments, record the
  # fingerprint and sweep the stale file below.
  write_lock <<'JSON'
{ "profile": "pt-abnt" }
JSON
  local stale="${root}/sessions/long-gone.json" before_lock before_settings
  echo '{ "profile": "pt-abnt" }' > "$stale"
  touch -t "$(date -v-8d +%Y%m%d%H%M 2>/dev/null || date -d '8 days ago' +%Y%m%d%H%M)" "$stale"
  before_lock="$(cat "$lock_file")"
  before_settings="$(cat "${root}/settings.json")"
  bash "$remind" UserPromptSubmit > /dev/null
  assert_eq "$before_lock" "$(cat "$lock_file")" "the lock"
  assert_eq "$before_settings" "$(cat "${root}/settings.json")" "settings.json"
  assert_file "$stale"
  assert_no_file "$asked_file"
  assert_eq "2" "$(ls "${root}/sessions" | wc -l | tr -d ' ')" "files in sessions/"
  teardown
}

test_disabled_key_in_settings_no_longer_pauses() {
  setup "a \"disabled\" key in settings.json is not the Pause"
  seed_settings
  python3 - "${root}/settings.json" <<'PY'
import json, sys
path = sys.argv[1]
data = json.load(open(path))
data["disabled"] = True
json.dump(data, open(path, "w"), indent=2)
PY
  local msg
  msg="$(bash "$remind" UserPromptSubmit | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "American English" "message"
  teardown
}

# The files in the state root, one per line, so a test can see that nothing was
# created, left behind or removed besides what it expects.
state_root_files() {
  ls "$root" | tr '\n' ' ' | sed 's/ $//'
}

test_pause_creates_the_sentinel() {
  setup "pause and pausar create the sentinel and leave settings.json byte-for-byte"
  local fixture="${sandbox}/settings.fixture" word out status
  for word in pause pausar PAUSE; do
    seed_settings
    rm -f "${root}/paused"
    cp "${root}/settings.json" "$fixture"
    # A session id is not needed: the Pause belongs to no session.
    out="$(env -u CLAUDE_CODE_SESSION_ID bash "$lock" "$word" 2>&1)"
    status=$?
    assert_eq 0 "$status" "exit code for '${word}'"
    assert_contains "$out" "paused" "output for '${word}'"
    assert_not_contains "$out" "already" "output for '${word}'"
    assert_file "${root}/paused"
    cmp -s "$fixture" "${root}/settings.json" || fail "settings.json changed for '${word}'"
    assert_eq "paused settings.json" "$(state_root_files)" "files in the state root for '${word}'"
  done
  # For a human who finds the file: when the Pause began.
  assert_contains "$(cat "${root}/paused")" "T" "sentinel content"
  assert_no_file "${root}/sessions"
  teardown
}

test_pause_works_without_settings() {
  setup "pause creates the sentinel, and no settings.json, when there is none"
  local out status
  out="$(bash "$lock" pause 2>&1)"
  status=$?
  assert_eq 0 "$status" "exit code"
  assert_contains "$out" "paused" "output"
  assert_file "${root}/paused"
  assert_no_file "${root}/settings.json"
  assert_hook_silent "paused with no settings.json"
  teardown
}

test_pause_leaves_a_malformed_settings_alone() {
  setup "pause pauses, and leaves a malformed settings.json byte-for-byte"
  local body out status
  # Truncated JSON, an empty file, and valid JSON that is not an object.
  for body in '{ "default": "en-ste", "profiles": [' '' '["en-ste"]'; do
    rm -rf "$root"
    mkdir -p "$root"
    printf '%s' "$body" > "${root}/settings.json"
    out="$(bash "$lock" pause 2>&1)"
    status=$?
    assert_eq 0 "$status" "exit code for '${body}'"
    assert_file "${root}/paused"
    assert_eq "$body" "$(cat "${root}/settings.json")" "settings.json for '${body}'"
  done
  teardown
}

test_pause_and_resume_need_no_backend() {
  setup "pause and resume work without a usable JSON backend"
  seed_settings
  local out status
  out="$(OUTPUT_LANGUAGE_JSON_BACKEND=no-such-backend bash "$lock" pause 2>&1)"
  status=$?
  assert_eq 0 "$status" "pause exit code"
  assert_file "${root}/paused"
  out="$(OUTPUT_LANGUAGE_JSON_BACKEND=no-such-backend bash "$lock" resume 2>&1)"
  status=$?
  assert_eq 0 "$status" "resume exit code"
  assert_no_file "${root}/paused"
  teardown
}

test_pausing_twice_leaves_the_sentinel_alone() {
  setup "pause while paused says so and leaves the sentinel as it was"
  seed_settings
  mkdir -p "$root"
  printf '%s' 'paused by hand' > "${root}/paused"
  local word out status
  for word in pause pausar; do
    out="$(bash "$lock" "$word" 2>&1)"
    status=$?
    assert_eq 0 "$status" "exit code for '${word}'"
    assert_contains "$out" "already paused" "output for '${word}'"
    assert_eq "paused by hand" "$(cat "${root}/paused")" "sentinel for '${word}'"
  done
  teardown
}

test_resume_removes_the_sentinel() {
  setup "resume and retomar remove the sentinel and leave settings.json byte-for-byte"
  local fixture="${sandbox}/settings.fixture" word out status
  for word in resume retomar RESUME; do
    seed_settings
    seed_pause
    cp "${root}/settings.json" "$fixture"
    out="$(env -u CLAUDE_CODE_SESSION_ID bash "$lock" "$word" 2>&1)"
    status=$?
    assert_eq 0 "$status" "exit code for '${word}'"
    assert_contains "$out" "resumed" "output for '${word}'"
    assert_no_file "${root}/paused"
    cmp -s "$fixture" "${root}/settings.json" || fail "settings.json changed for '${word}'"
  done
  assert_eq "settings.json" "$(state_root_files)" "files in the state root"
  teardown
}

test_resume_puts_a_pinned_session_back() {
  setup "after a resume, a pinned session gets its profile back and is not asked again"
  seed_settings
  write_lock <<'JSON'
{ "profile": "pt-abnt" }
JSON
  # The attachments were asked for before the Pause.
  bash "$remind" UserPromptSubmit > /dev/null
  bash "$lock" pause > /dev/null
  assert_hook_silent "paused"
  bash "$lock" resume > /dev/null
  local msg
  msg="$(bash "$remind" UserPromptSubmit | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "portugues brasileiro, per ABNT NBR ISO 24495-1" "message"
  assert_not_contains "$msg" "/tmp/a-guide.pdf" "message"
  assert_eq "pt-abnt" "$(json_get "$lock_file" profile)" "profile"
  teardown
}

test_resume_without_a_pause_changes_nothing() {
  setup "resume with no Pause says so and changes nothing"
  local out status
  out="$(bash "$lock" resume 2>&1)"
  status=$?
  assert_eq 0 "$status" "exit code with no state root"
  assert_contains "$out" "no Pause" "output with no state root"
  assert_no_file "$root"

  seed_settings
  out="$(bash "$lock" retomar 2>&1)"
  status=$?
  assert_eq 0 "$status" "exit code with settings.json"
  assert_contains "$out" "no Pause" "output with settings.json"
  assert_eq "settings.json" "$(state_root_files)" "files in the state root"
  teardown
}

test_pause_survives_a_concurrent_settings_writer() {
  setup "a Pause is never lost to, and never touches, a concurrent settings.json writer"
  seed_settings
  local fixture="${sandbox}/settings.fixture" writer i
  cp "${root}/settings.json" "$fixture"
  # Aidiom's save, a few hundred times over: a temp file, then a rename.
  (
    for i in $(seq 1 300); do
      cp "$fixture" "${root}/settings.json.tmp.writer"
      mv "${root}/settings.json.tmp.writer" "${root}/settings.json"
    done
  ) &
  writer=$!
  bash "$lock" pause > /dev/null
  bash "$lock" resume > /dev/null
  bash "$lock" pause > /dev/null
  wait "$writer"
  assert_file "${root}/paused"
  cmp -s "$fixture" "${root}/settings.json" || fail "settings.json differs from the fixture"
  assert_eq "paused settings.json" "$(state_root_files)" "files in the state root"
  teardown
}

test_off_still_means_this_session_only() {
  setup "off and its synonyms still turn off only this session, never pause"
  seed_settings
  local before word
  before="$(cat "${root}/settings.json")"
  for word in off desativar desligar; do
    rm -f "$lock_file"
    bash "$lock" "$word" > /dev/null
    assert_eq "true" "$(json_get "$lock_file" disabled)" "lock for '${word}'"
    assert_eq "$before" "$(cat "${root}/settings.json")" "settings.json for '${word}'"
  done
  # Another session still hears the Default Profile.
  local msg
  msg="$(CLAUDE_CODE_SESSION_ID=another-session bash "$remind" UserPromptSubmit \
    | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "American English" "another session"
  teardown
}

# ------------------------------------------------------------------- main ---

# Every case runs once per available JSON backend, so the python3 fallback is
# covered on a machine that has jq.
backends="python3"
if command -v jq > /dev/null 2>&1; then
  backends="jq python3"
fi

cases="$(declare -F | awk '{print $3}' | grep '^test_')"

for backend in $backends; do
  export OUTPUT_LANGUAGE_JSON_BACKEND="$backend"
  echo "== JSON backend: ${backend}"
  for test_case in $cases; do
    "$test_case"
  done
  echo
done

echo
if [ "$tests_failed" -eq 0 ]; then
  echo "ok: ${tests_run} tests passed"
  exit 0
fi
echo "FAILED: ${tests_failed} assertion(s) across ${tests_run} tests"
exit 1
