#!/bin/bash
# UserPromptSubmit Hook — /스킬명 호출 추적
set -euo pipefail

DB_PATH="${HOME}/.claude/harness-usage.db"
[ ! -f "$DB_PATH" ] && exit 0

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.user_prompt // ""' 2>/dev/null || echo "")

# /스킬명 패턴 감지
skill_match=$(printf '%s' "$prompt" | grep -oE '^/[a-z][a-z0-9-]*' || echo "")
[ -z "$skill_match" ] && exit 0

skill_name="${skill_match#/}"
project_dir=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
session_id="${CLAUDE_SESSION_ID:-}"

esc() { printf '%s' "$1" | sed "s/'/''/g"; }

(sqlite3 "$DB_PATH" \
  "INSERT INTO tool_usage (session_id, project_dir, tool_name, tool_category, detail, success)
   VALUES ('$(esc "$session_id")', '$(esc "$project_dir")', 'skill_invoke', 'skill', '$(esc "$skill_name")', 1);" \
  2>/dev/null || true) &

exit 0
