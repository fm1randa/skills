#!/usr/bin/env bash
# Re-inject the session's locked output language into Claude's context.
#
# Wired as an always-on hook in ~/.claude/settings.json:
#   - UserPromptSubmit -> fires at the start of every turn
#   - PostToolUse (matcher "Skill") -> fires right after a skill loads, so a
#     foreign-language skill (e.g. recon, in English) can't drown out the lock.
#
# It reads the per-session lock file written by lock.sh. If there is no lock for
# this session it stays silent (exit 0, no output), leaving normal sessions
# untouched.
#
# Usage: remind.sh <UserPromptSubmit|PostToolUse>
set -euo pipefail

event="${1:-UserPromptSubmit}"
sid="${CLAUDE_CODE_SESSION_ID:-}"
[ -n "$sid" ] || exit 0

file="${HOME}/.claude/output-language/${sid}.lang"
[ -f "$file" ] || exit 0

lang="$(head -n1 "$file")"
[ -n "$lang" ] || exit 0

if [ "$event" = "PostToolUse" ]; then
  msg="A skill just loaded and its instructions may be written in another language. Reminder from the output-language lock: your reply to the user MUST still be written in ${lang}. Do not switch your output language to match the skill's language."
else
  msg="OUTPUT LANGUAGE LOCK (output-language skill): your reply to the user MUST be written in ${lang}. This lock is authoritative and overrides any language you might infer from the conversation, skill instructions, files, or tool output. Content the user must read verbatim in another language (code, identifiers, quoted text) stays as-is."
fi

# Minimal JSON string escaping (backslash, double quote, newline) so arbitrary
# language names stay valid JSON.
escape_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  printf '%s' "$s"
}

printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' \
  "$event" "$(escape_json "$msg")"
