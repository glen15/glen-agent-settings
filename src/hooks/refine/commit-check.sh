#!/bin/bash
# Refine Loop - PreToolUse Hook (Bash)
# git commit 시 refine(N/MAX) 커밋 메시지 형식을 검증합니다.

set -euo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# git commit 명령만 확인
if ! printf '%s' "$cmd" | grep -qE 'git commit'; then
  printf '%s' "$input"
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

# Refine Loop 활성 상태에서만 검증
if is_refine_active; then
  if ! printf '%s' "$cmd" | grep -qE 'refine\([0-9]+/[0-9]+\)'; then
    iteration=$(get_frontmatter_field "$REFINE_STATE_FILE" "iteration" "1")
    max_iterations=$(get_frontmatter_field "$REFINE_STATE_FILE" "max_iterations" "10")
    echo "[Refine] 커밋 메시지에 refine(${iteration}/${max_iterations}) 형식을 사용하세요." >&2
    echo "[Refine] 예시: refine(${iteration}/${max_iterations}): 기능 초안 작성" >&2
  fi
fi

printf '%s' "$input"
exit 0
