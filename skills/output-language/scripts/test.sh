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
}

teardown() {
  [ -n "$sandbox" ] && rm -rf "$sandbox"
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

test_ignores_legacy_lang_file() {
  setup "ignores the legacy ~/.claude/output-language/<sid>.lang file"
  mkdir -p "${HOME}/.claude/output-language"
  echo "Klingon" > "${HOME}/.claude/output-language/${CLAUDE_CODE_SESSION_ID}.lang"
  local out
  out="$(bash "$remind" UserPromptSubmit 2>&1)"
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
  assert_empty "$(json_get "$lock_file" attachmentsRequestedFor)" "fingerprint"
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
  assert_empty "$(json_get "$lock_file" attachmentsRequestedFor)" "fingerprint"
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
  fingerprint="$(json_get "$lock_file" attachmentsRequestedFor)"
  assert_eq "$(printf 'pt-abnt\n/tmp/a-guide.pdf\n/tmp/b-guide.pdf')" "$fingerprint" "fingerprint"
  assert_eq "pt-abnt" "$(json_get "$lock_file" profile)" "profile kept"

  second="$(bash "$remind" UserPromptSubmit)"
  msg="$(printf '%s' "$second" | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "portugues brasileiro" "second message"
  assert_not_contains "$msg" "/tmp/a-guide.pdf" "second message"
  teardown
}

test_attachments_for_inheriting_session() {
  setup "an inheriting session gets a fingerprint-only lock file, still inheriting"
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
  assert_file "$lock_file"
  assert_eq "$(printf 'pt-abnt\n/tmp/a-guide.pdf')" "$(json_get "$lock_file" attachmentsRequestedFor)" "fingerprint"
  assert_empty "$(json_get "$lock_file" profile)" "profile"
  assert_empty "$(json_get "$lock_file" instruction)" "instruction"
  teardown
}

test_fingerprint_reset_after_relock() {
  setup "relocking clears the fingerprint, so attachments are requested again"
  seed_settings
  write_lock <<'JSON'
{ "profile": "pt-abnt" }
JSON
  bash "$remind" UserPromptSubmit > /dev/null
  assert_eq "$(printf 'pt-abnt\n/tmp/a-guide.pdf\n/tmp/b-guide.pdf')" "$(json_get "$lock_file" attachmentsRequestedFor)" "fingerprint"

  bash "$lock" pt-abnt > /dev/null
  assert_empty "$(json_get "$lock_file" attachmentsRequestedFor)" "fingerprint after relock"

  local msg
  msg="$(bash "$remind" UserPromptSubmit | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "/tmp/a-guide.pdf" "message after relock"
  teardown
}

test_fingerprint_change_requests_again() {
  setup "a different profile fingerprint asks again"
  seed_settings
  write_lock <<'JSON'
{ "profile": "pt-abnt", "attachmentsRequestedFor": "en-ste" }
JSON
  local msg
  msg="$(bash "$remind" UserPromptSubmit | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "/tmp/a-guide.pdf" "message"
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
  local out
  out="$(bash "$lock" pt-abnt)"
  assert_contains "$out" "pt-abnt" "stdout"
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
  local out
  out="$(bash "$lock" default)"
  assert_contains "$out" "default" "stdout"
  assert_no_file "$lock_file"
  local msg
  msg="$(bash "$remind" UserPromptSubmit | json_stdin hookSpecificOutput additionalContext)"
  assert_contains "$msg" "American English" "message"
  teardown
}

test_off_disables_the_session() {
  setup "lock.sh off writes the disabled state and the hook goes silent"
  seed_settings
  local out
  out="$(bash "$lock" off)"
  assert_contains "$out" "off" "stdout"
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
  echo '{ "profile": "pt-abnt" }' > "$stale"
  touch -t "$(date -v-8d +%Y%m%d%H%M 2>/dev/null || date -d '8 days ago' +%Y%m%d%H%M)" "$stale"
  bash "$lock" pt-abnt > /dev/null
  assert_no_file "$stale"
  assert_file "$lock_file"
  teardown
}

test_own_session_survives_the_prune() {
  setup "the current session's own lock survives the prune, however old"
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
  touch -t "$(date -v-8d +%Y%m%d%H%M 2>/dev/null || date -d '8 days ago' +%Y%m%d%H%M)" "$lock_file"
  # The prune runs on this turn, because the hook writes the fingerprint.
  bash "$remind" UserPromptSubmit > /dev/null
  assert_file "$lock_file"
  assert_eq "pt-abnt" "$(json_get "$lock_file" profile)" "profile kept"
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
  assert_eq "$(printf 'pipe\n/tmp/a|b.pdf')" "$(json_get "$lock_file" attachmentsRequestedFor)" "fingerprint"

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
  assert_eq "$(printf 'pipe\n/tmp/a\nb.pdf')" "$(json_get "$lock_file" attachmentsRequestedFor)" "fingerprint"
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
