#!/bin/bash
# Refine Loop - UserPromptSubmit Hook
# .claude/refine-loop.local.md에서 상태를 읽어 리치 컨텍스트를 주입합니다.

set -euo pipefail

input=$(cat)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

# 레거시 마이그레이션 확인
migrate_legacy_if_needed

# 상태 파일이 없으면 아무 것도 주입하지 않음
if ! is_refine_active; then
  exit 0
fi

# ── 세션 타임아웃 확인 ──
session_timeout=$(get_frontmatter_field "$REFINE_STATE_FILE" "session_timeout_minutes" "30")
started_at=$(get_frontmatter_field "$REFINE_STATE_FILE" "started_at" "")
if [ -n "$started_at" ] && [ "$session_timeout" -gt 0 ]; then
  elapsed_minutes=$(elapsed_minutes_since "$started_at")
  if [ "$elapsed_minutes" -ge "$session_timeout" ]; then
    cleanup_state "세션 타임아웃(${session_timeout}분)"
    exit 0
  fi
fi

# ── 현재 상태 읽기 ──
iteration=$(get_frontmatter_field "$REFINE_STATE_FILE" "iteration" "1")
max_iterations=$(get_frontmatter_field "$REFINE_STATE_FILE" "max_iterations" "10")
phase=$(get_frontmatter_field "$REFINE_STATE_FILE" "phase" "plan")
stagnation=$(get_frontmatter_field "$REFINE_STATE_FILE" "stagnation_count" "0")
stagnation_limit=$(get_frontmatter_field "$REFINE_STATE_FILE" "stagnation_limit" "3")
total_cost=$(get_frontmatter_field "$REFINE_STATE_FILE" "total_cost_usd" "0.0")
token_budget=$(get_frontmatter_field "$REFINE_STATE_FILE" "token_budget_usd" "0")
current_strategy=$(get_frontmatter_field "$REFINE_STATE_FILE" "current_strategy" "default")

# ── 비용 표시 ──
cost_display="\$${total_cost}"
if [ "$token_budget" != "0" ]; then
  cost_display="\$${total_cost}/\$${token_budget}"
fi

# ── 컨텍스트 주입 ──
jq -n --arg ctx "[Refine] ${iteration}/${max_iterations} | phase:${phase} | 정체:${stagnation}/${stagnation_limit} | ${cost_display} | 전략:${current_strategy}
규칙:
(1) 각 iteration 커밋 필수: refine(${iteration}/${max_iterations}): 한글메시지
(2) Tidy First -> Work -> Right -> Fast 순서 준수
(3) 정체 ${stagnation_limit}회 시 반드시 사용자에게 전략 변경 확인
(4) 작업 완료 시 반드시 <promise>REFINE_DONE</promise> 출력
(5) 완료 조건: 모든 테스트 통과 + 빌드 성공 + 요구사항 충족" \
  '{
    "hookSpecificOutput": {
      "additionalContext": $ctx
    }
  }'

exit 0
