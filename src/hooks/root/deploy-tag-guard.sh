#!/bin/bash
# PreToolUse Hook (Bash) — 프로덕션 태그는 main 브랜치에서만 허용
set -euo pipefail
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# git tag 명령이 아니면 통과
if ! printf '%s' "$cmd" | grep -qE 'git\s+tag'; then
  printf '%s' "$input"
  exit 0
fi

# 조회성 명령(git tag -l, git tag --list, git tag -d)은 허용
if printf '%s' "$cmd" | grep -qE 'git\s+tag\s+(-l|--list|-d|--delete)'; then
  printf '%s' "$input"
  exit 0
fi

# 현재 브랜치 확인
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

if [ "$current_branch" != "main" ]; then
  echo "[훅] 차단: 프로덕션 태그는 main 브랜치에서만 생성 가능합니다 (현재: $current_branch)" >&2
  exit 2
fi

printf '%s' "$input"
