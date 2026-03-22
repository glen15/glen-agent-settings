#!/bin/bash
# PostToolUse Hook — 하네스 도구 사용 추적
# 모든 도구 호출을 SQLite에 기록. 실패 시 조용히 무시.
set -euo pipefail

input=$(cat)

DB_PATH="${HOME}/.claude/harness-usage.db"

# DB 없으면 초기화
if [ ! -f "$DB_PATH" ]; then
  INIT_SCRIPT="${HOME}/.claude/skills/harness-stats/scripts/init-db.sh"
  if [ -f "$INIT_SCRIPT" ]; then
    bash "$INIT_SCRIPT" 2>/dev/null || true
  fi
  # 초기화 실패하면 로깅 스킵
  if [ ! -f "$DB_PATH" ]; then
    printf '%s' "$input"
    exit 0
  fi
fi

# 도구 정보 추출
tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
if [ -z "$tool_name" ]; then
  printf '%s' "$input"
  exit 0
fi

# 카테고리 + 디테일 분류
category=""
detail=""
file_path=""

case "$tool_name" in
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
    if printf '%s' "$cmd" | grep -q '\.claude/skills/' 2>/dev/null; then
      category="skill_script"
      detail=$(printf '%s' "$cmd" | grep -oE 'skills/[^/]+' | head -1 | sed 's|skills/||')
    elif printf '%s' "$cmd" | grep -qE '^git ' 2>/dev/null; then
      category="cli"
      detail=$(printf '%s' "$cmd" | awk '{print $1"-"$2}')
    elif printf '%s' "$cmd" | grep -qE '^gh ' 2>/dev/null; then
      category="cli"
      detail=$(printf '%s' "$cmd" | awk '{print $1"-"$2}')
    elif printf '%s' "$cmd" | grep -qE '^gws ' 2>/dev/null; then
      category="cli"
      detail=$(printf '%s' "$cmd" | awk '{print "gws-"$2}')
    else
      category="cli"
      detail=$(printf '%s' "$cmd" | awk '{print $1}' | head -c 30)
    fi
    ;;
  Write)
    category="file_write"
    file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
    detail=$(printf '%s' "$file_path" | grep -oE '\.[^.]+$' || echo "unknown")
    ;;
  Edit)
    category="file_edit"
    file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
    detail=$(printf '%s' "$file_path" | grep -oE '\.[^.]+$' || echo "unknown")
    ;;
  Read)
    category="file_read"
    file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
    detail=$(printf '%s' "$file_path" | grep -oE '\.[^.]+$' || echo "unknown")
    ;;
  Glob|Grep)
    category="search"
    detail=$(printf '%s' "$input" | jq -r '.tool_input.pattern // ""' 2>/dev/null | head -c 50)
    ;;
  Agent)
    category="agent"
    detail=$(printf '%s' "$input" | jq -r '.tool_input.description // ""' 2>/dev/null | head -c 50)
    ;;
  mcp__*)
    category="mcp"
    detail=$(printf '%s' "$tool_name" | sed 's/^mcp__//')
    ;;
  *)
    category="other"
    detail="$tool_name"
    ;;
esac

# 프로젝트 디렉토리 + 세션 ID
project_dir=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
session_id="${CLAUDE_SESSION_ID:-}"

# 성공 여부
success=1
stderr=$(printf '%s' "$input" | jq -r '.tool_output.stderr // ""' 2>/dev/null || echo "")
if [ -n "$stderr" ] && printf '%s' "$stderr" | grep -qiE '(error|failed|fatal)' 2>/dev/null; then
  success=0
fi

# SQL 이스케이프 함수
esc() { printf '%s' "$1" | sed "s/'/''/g"; }

# 백그라운드 INSERT (차단 방지)
(sqlite3 "$DB_PATH" \
  "INSERT INTO tool_usage (session_id, project_dir, tool_name, tool_category, detail, file_path, success)
   VALUES ('$(esc "$session_id")', '$(esc "$project_dir")', '$(esc "$tool_name")', '$(esc "$category")', '$(esc "$detail")', '$(esc "$file_path")', ${success});" \
  2>/dev/null || true) &

printf '%s' "$input"
