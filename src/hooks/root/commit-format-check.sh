#!/bin/bash
# PreToolUse Hook (Bash) - 커밋 메시지 형식 검증
# 한글 메시지, 타입 프리픽스를 검증합니다.
# Refine Loop 활성 시에는 refine/commit-check.sh가 처리하므로 스킵.

set -euo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# git commit 명령만 확인
if ! printf '%s' "$cmd" | grep -qE 'git commit'; then
  printf '%s' "$input"
  exit 0
fi

# Refine Loop 활성이면 스킵 (refine/commit-check.sh가 처리)
REFINE_STATE_FILE=".claude/refine-loop.local.md"
if [ -f "$REFINE_STATE_FILE" ]; then
  active=$(sed -n '/^---$/,/^---$/{/^active:/s/active: *//p;}' "$REFINE_STATE_FILE" 2>/dev/null || echo "false")
  if [ "$active" = "true" ]; then
    printf '%s' "$input"
    exit 0
  fi
fi

# 커밋 메시지 추출 (-m "..." 또는 -m '...' 또는 HEREDOC)
msg=""
if printf '%s' "$cmd" | grep -qE -- '-m '; then
  # -m "..." 또는 -m '...'
  msg=$(printf '%s' "$cmd" | sed -n 's/.*-m ["\x27]\([^"\x27]*\)["\x27].*/\1/p')
  # HEREDOC 패턴 (-m "$(cat <<...)
  if [ -z "$msg" ]; then
    msg=$(printf '%s' "$cmd" | grep -oP '(?<=EOF\n).*?(?=\nCo-Authored)' 2>/dev/null || echo "")
  fi
fi

# 메시지를 추출할 수 없으면 패스
if [ -z "$msg" ]; then
  printf '%s' "$input"
  exit 0
fi

# 첫 줄만 검증
first_line=$(printf '%s' "$msg" | head -1)

# 타입 프리픽스 검증
valid_types="refine|ralph|tidy|feat|fix|test|perf|docs|style|chore|refactor"
if ! printf '%s' "$first_line" | grep -qE "^(${valid_types})[:(]"; then
  echo "[훅] 경고: 커밋 타입이 없거나 잘못됨 — ${first_line}" >&2
  echo "[훅] 허용 타입: feat, fix, tidy, refactor, test, perf, docs, style, chore, refine, ralph" >&2
fi

# 한글 포함 여부 검증 (타입 프리픽스 뒤에 한글이 있어야 함)
msg_body=$(printf '%s' "$first_line" | sed "s/^[a-z]*[:(][^)]*): *//; s/^[a-z]*: *//")
if [ -n "$msg_body" ] && ! printf '%s' "$msg_body" | grep -qP '[\x{AC00}-\x{D7A3}]'; then
  echo "[훅] 경고: 커밋 메시지에 한글이 없음 — ${first_line}" >&2
  echo "[훅] 커밋 메시지는 반드시 한글로 작성하세요" >&2
fi

printf '%s' "$input"
exit 0
