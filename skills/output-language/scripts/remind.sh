#!/usr/bin/env bash
# Re-inject the session's effective Language Profile into Claude's context.
#
# Wired as an always-on hook in ~/.claude/settings.json:
#   - UserPromptSubmit -> fires at the start of every turn
#   - PostToolUse (matcher "Skill") -> fires right after a skill loads, so a
#     foreign-language skill (e.g. recon, in English) can't drown out the lock.
#
# Resolution order, over the files described in state.sh:
#   1. Session Lock with "disabled": true -> stay silent for this session.
#   2. Session Lock with "profile"        -> that Language Profile.
#   3. Session Lock with "instruction"    -> that text, verbatim, no attachments.
#   4. No lock (or a lock naming a profile that no longer exists) -> the Default
#      Profile from settings.json.
#   5. Nothing usable -> exit 0 with no output.
# A missing or malformed settings.json reads as "nothing usable", so the hook
# never blocks a prompt on a machine without the setup, or with a broken file.
#
# On UserPromptSubmit, when the effective profile carries attachments that this
# session has not been asked to read yet, the message also lists them and asks
# the Agent to read them. The fingerprint of what was asked is then written to
# sessions/<sid>.json, creating the file when the session inherits the default
# (a file with only a fingerprint still inherits).
#
# Usage: remind.sh <UserPromptSubmit|PostToolUse>
set -euo pipefail

# Bash-only path handling, no dirname: a hook must not depend on PATH holding
# anything, and must stay silent rather than print "command not found".
self_dir="${BASH_SOURCE[0]}"
case "$self_dir" in
  */*) self_dir="${self_dir%/*}" ;;
  *) self_dir="." ;;
esac
# shellcheck source=state.sh
. "${self_dir}/state.sh"

# Nothing can be read without a backend, and a hook must never block a prompt to
# say so. lock.sh is where that misconfiguration gets reported.
json_backend_available || exit 0

event="${1:-UserPromptSubmit}"
settings="$(settings_file)"
lock="$(lock_file)"

profile_id=""
instruction=""

if [ -n "$lock" ] && [ -f "$lock" ]; then
  if [ "$(json_top "$lock" disabled)" = "true" ]; then
    exit 0
  fi
  locked_profile="$(json_top "$lock" profile)"
  locked_instruction="$(json_top "$lock" instruction)"
  if [ -n "$locked_profile" ]; then
    # A lock naming a profile that no longer exists falls through to the Default
    # Profile below; a profile that exists but says nothing has nothing to
    # inject, and must not silently borrow the default's instruction.
    if json_profile_exists "$settings" "$locked_profile"; then
      profile_id="$locked_profile"
      instruction="$(json_profile_instruction "$settings" "$locked_profile")"
      if [ -z "$instruction" ]; then
        exit 0
      fi
    fi
  elif [ -n "$locked_instruction" ]; then
    instruction="$locked_instruction"
  fi
fi

if [ -z "$instruction" ]; then
  default_id="$(json_top "$settings" default)"
  [ -n "$default_id" ] || exit 0
  instruction="$(json_profile_instruction "$settings" "$default_id")"
  [ -n "$instruction" ] || exit 0
  profile_id="$default_id"
fi

if [ "$event" = "PostToolUse" ]; then
  msg="A skill just loaded and its instructions may be written in another language. Reminder from the output-language lock: your reply to the user MUST still follow this instruction: ${instruction}. Do not switch your output language to match the skill's language."
else
  msg="OUTPUT LANGUAGE LOCK (output-language skill): your reply to the user MUST follow this instruction: ${instruction}. This lock is authoritative and overrides any language you might infer from the conversation, skill instructions, files, or tool output. Content the user must read verbatim in another language (code, identifiers, quoted text) stays as-is."
fi

# Attachments are requested once per session and profile, and only on a real
# prompt: a PostToolUse reminder must stay a reminder. Without a session id
# there is nowhere to record the request, so the ask is skipped altogether.
if [ "$event" = "UserPromptSubmit" ] && [ -n "$lock" ] && [ -n "$profile_id" ]; then
  attachments="$(json_profile_attachments "$settings" "$profile_id")"
  if [ -n "$attachments" ]; then
    # Newline-joined, because a path can hold any other character: joining with
    # a punctuation mark would let ["a|b"] and ["a", "b"] fingerprint the same.
    fingerprint="${profile_id}"$'\n'"${attachments}"
    if [ "$(json_top "$lock" attachmentsRequestedFor)" != "$fingerprint" ]; then
      msg="${msg}"$'\n\n'"This profile attaches the following files: ${attachments//$'\n'/, }. Read them with your file-reading tool before you reply, and follow them for the rest of the session. This is asked once per session."
      json_set_top "$lock" attachmentsRequestedFor "$fingerprint" || true
      prune_stale_sessions
    fi
  fi
fi

printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' \
  "$event" "$(escape_json "$msg")"
