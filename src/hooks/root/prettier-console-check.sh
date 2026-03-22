#!/bin/bash
# PostToolUse Hook (Edit) — ts/js 파일 Prettier 자동 포맷 + console.log 경고
set -euo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')

# ts/js 파일만 대상
if [[ ! "$file_path" =~ \.(ts|tsx|js|jsx)$ ]]; then
  printf '%s' "$input"
  exit 0
fi

# Prettier 자동 포맷
if [ -n "$file_path" ] && [ -f "$file_path" ]; then
  if command -v prettier >/dev/null 2>&1; then
    prettier --write "$file_path" 2>&1 | head -5 >&2
  fi
fi

# console.log 경고
if [ -n "$file_path" ] && [ -f "$file_path" ]; then
  console_logs=$(grep -n 'console\.log' "$file_path" 2>/dev/null || true)
  if [ -n "$console_logs" ]; then
    echo "[훅] 경고: console.log 발견 - $file_path" >&2
    echo '[훅] 커밋 전 console.log를 제거하세요' >&2
  fi
fi

printf '%s' "$input"
