#!/bin/bash
# Refine Loop - Stop Hook
# 세션 내 반복 수렴을 위한 프롬프트 리플레이 + 구조화 기능
# 상태 파일: .claude/refine-loop.local.md (Markdown+YAML frontmatter)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

HOOK_INPUT=$(cat)

# ── 레거시 마이그레이션 확인 ──
migrate_legacy_if_needed

# ── 상태 파일 확인 ──
if ! is_refine_active; then
  exit 0
fi

# ── 상태 읽기 ──
iteration=$(get_frontmatter_field "$REFINE_STATE_FILE" "iteration" "1")
max_iterations=$(get_frontmatter_field "$REFINE_STATE_FILE" "max_iterations" "10")
completion_promise=$(get_frontmatter_field "$REFINE_STATE_FILE" "completion_promise" "REFINE_DONE")
stagnation_count=$(get_frontmatter_field "$REFINE_STATE_FILE" "stagnation_count" "0")
stagnation_limit=$(get_frontmatter_field "$REFINE_STATE_FILE" "stagnation_limit" "3")
last_error_hash=$(get_frontmatter_field "$REFINE_STATE_FILE" "last_error_hash" "")
last_files_changed=$(get_frontmatter_field "$REFINE_STATE_FILE" "last_files_changed" "0")
token_budget=$(get_frontmatter_field "$REFINE_STATE_FILE" "token_budget_usd" "0")
time_budget=$(get_frontmatter_field "$REFINE_STATE_FILE" "time_budget_minutes" "0")
session_timeout=$(get_frontmatter_field "$REFINE_STATE_FILE" "session_timeout_minutes" "30")
started_at=$(get_frontmatter_field "$REFINE_STATE_FILE" "started_at" "")
current_strategy=$(get_frontmatter_field "$REFINE_STATE_FILE" "current_strategy" "default")

# ── 완료 프로미스 확인 ──
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")

if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  if grep -q '"role":"assistant"' "$TRANSCRIPT_PATH" 2>/dev/null; then
    LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)
    if [ -n "$LAST_LINE" ]; then
      LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
        .message.content |
        map(select(.type == "text")) |
        map(.text) |
        join("\n")
      ' 2>/dev/null || echo "")

      PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")

      if [ -n "$PROMISE_TEXT" ] && [ "$PROMISE_TEXT" = "$completion_promise" ]; then
        cleanup_state "iteration ${iteration}/${max_iterations}에서 완료 감지"
        exit 0
      fi
    fi
  fi
fi

# ── Hard Limits 확인 ──

# 1) MAX_ITERATIONS 도달
if [ "$iteration" -ge "$max_iterations" ]; then
  cleanup_state "MAX_ITERATIONS(${max_iterations}) 도달"
  exit 0
fi

# 2) 세션 타임아웃
if [ -n "$started_at" ] && [ "$session_timeout" -gt 0 ]; then
  elapsed_minutes=$(elapsed_minutes_since "$started_at")
  if [ "$elapsed_minutes" -ge "$session_timeout" ]; then
    cleanup_state "세션 타임아웃(${session_timeout}분) 초과"
    exit 0
  fi
fi

# ── 비용 계산 ──
total_cost=0.0
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  cost_result=$(python3 "${SCRIPT_DIR}/calc-cost.py" "$TRANSCRIPT_PATH" 2>/dev/null || echo '{"total_cost_usd":0.0}')
  total_cost=$(echo "$cost_result" | jq -r '.total_cost_usd // 0' 2>/dev/null || echo "0.0")
fi

# 3) 토큰 비용 예산 초과
if [ "$token_budget" != "0" ]; then
  budget_exceeded=$(python3 -c "print(1 if float('${total_cost}') >= float('${token_budget}') else 0)" 2>/dev/null || echo "0")
  if [ "$budget_exceeded" = "1" ]; then
    cleanup_state "토큰 예산(\$${token_budget}) 초과 (현재: \$${total_cost})"
    exit 0
  fi
fi

# 4) 시간 예산 초과
if [ "$time_budget" != "0" ] && [ -n "$started_at" ]; then
  time_elapsed=$(elapsed_minutes_since "$started_at")
  if [ "$time_elapsed" -ge "$time_budget" ]; then
    cleanup_state "시간 예산(${time_budget}분) 초과"
    exit 0
  fi
fi

# ── 정체 감지 ──
new_stagnation_count=$stagnation_count
stag_result=$("${SCRIPT_DIR}/detect-stagnation.sh" "$TRANSCRIPT_PATH" "$last_error_hash" "$last_files_changed" 2>/dev/null || echo "0|||0")
stag_delta=$(echo "$stag_result" | cut -d'|' -f1)
new_error_hash=$(echo "$stag_result" | cut -d'|' -f2)
error_repeated=$(echo "$stag_result" | cut -d'|' -f3)
current_files_changed=$(echo "$stag_result" | cut -d'|' -f4)

if [ "$stag_delta" = "1" ]; then
  new_stagnation_count=$((stagnation_count + 1))
fi

# 정체 한계 도달 시 경고 (종료하지 않음 — 사용자 확인 필요)
stagnation_warning=""
if [ "$new_stagnation_count" -ge "$stagnation_limit" ]; then
  stagnation_warning=" | STAGNATION_LIMIT 도달! 사용자에게 전략 변경을 확인하세요."
fi

# ── 다음 iteration 준비 ──
next_iter=$((iteration + 1))

# phase 순환: plan → execute → verify → record
phases=("plan" "execute" "verify" "record")
phase_idx=$(( (next_iter - 1) % 4 ))
next_phase="${phases[$phase_idx]}"

# ── 상태 파일 업데이트 ──
update_frontmatter_fields "$REFINE_STATE_FILE" \
  "iteration" "$next_iter" \
  "phase" "$next_phase" \
  "stagnation_count" "$new_stagnation_count" \
  "last_error_hash" "$new_error_hash" \
  "last_files_changed" "$current_files_changed" \
  "total_cost_usd" "$total_cost"

# ── refine-state.json iteration 로그 추가 ──
if [ ! -f "$REFINE_STATE_JSON" ]; then
  echo '{"iteration_log":[],"strategy_changes":[]}' > "$REFINE_STATE_JSON"
fi
log_entry=$(jq -n \
  --argjson iter "$iteration" \
  --arg phase "$next_phase" \
  --argjson stag "$new_stagnation_count" \
  --arg cost "$total_cost" \
  --arg strategy "$current_strategy" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{iteration: $iter, phase: $phase, stagnation: $stag, cost_usd: $cost, strategy: $strategy, timestamp: $ts}')
jq --argjson entry "$log_entry" '.iteration_log += [$entry]' "$REFINE_STATE_JSON" > "${REFINE_STATE_JSON}.tmp" \
  && mv "${REFINE_STATE_JSON}.tmp" "$REFINE_STATE_JSON"

# ── 원본 프롬프트 추출 ──
original_prompt=$(parse_prompt_body "$REFINE_STATE_FILE" || echo "이전 iteration 결과를 확인하고 다음 단계를 진행하세요.")

# ── 경과 시간 계산 ──
elapsed_display=""
if [ -n "${elapsed_minutes:-}" ]; then
  elapsed_display=" | ${elapsed_minutes}분"
fi

# ── 비용 표시 ──
cost_display="\$${total_cost}"
if [ "$token_budget" != "0" ]; then
  cost_display="\$${total_cost}/\$${token_budget}"
fi

# ── Block 응답 출력 ──
system_msg="[Refine] ${next_iter}/${max_iterations} | phase:${next_phase} | 정체:${new_stagnation_count}/${stagnation_limit} | ${cost_display}${elapsed_display}${stagnation_warning}
규칙: (1) 커밋 refine(${next_iter}/${max_iterations}) (2) Tidy First (3) 완료 시 <promise>${completion_promise}</promise>"

jq -n \
  --arg reason "$original_prompt" \
  --arg sys "$system_msg" \
  '{
    "decision": "block",
    "reason": $reason,
    "systemMessage": $sys
  }'

exit 0
