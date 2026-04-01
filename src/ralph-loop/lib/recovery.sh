#!/bin/bash
# Ralph Loop - Cheapest-First Recovery Cascade
# CC 소스맵 분석에서 차용: "항상 가장 저렴한 복구부터 시도"
#
# Tier 0: 무료 복구 (API 호출 없음) — 배치 축소, 1M 비활성화
# Tier 1: 저비용 복구 — 스코프 축소 (가장 많이 변경된 파일만)
# Tier 2: 에스컬레이션 — 사용자에게 알림

# 복구 상태 추적
RECOVERY_TIER=0
RECOVERY_ATTEMPTS=0
ORIGINAL_BATCH_SIZE=0
ORIGINAL_DISABLE_1M=false

# ── 프롬프트 초과 에러 감지 ──
detect_prompt_too_long() {
  local output_file="$1"
  [ ! -f "$output_file" ] && return 1

  local is_error
  is_error=$(jq -r '.is_error // false' "$output_file" 2>/dev/null)
  [ "$is_error" != "true" ] && return 1

  local subtype
  subtype=$(jq -r '.subtype // ""' "$output_file" 2>/dev/null)
  echo "$subtype" | grep -qiE 'prompt.?too.?long|413|context.?length|token.?limit|max.?context'
}

# ── max output tokens 에러 감지 ──
detect_max_output() {
  local output_file="$1"
  [ ! -f "$output_file" ] && return 1

  local stop_reason
  stop_reason=$(jq -r '.stop_reason // .result.stop_reason // ""' "$output_file" 2>/dev/null)
  [ "$stop_reason" = "max_tokens" ]
}

# ── 복구 캐스케이드 실행 ──
# 반환: 0=복구 성공(재시도), 1=복구 소진(에스컬레이션)
attempt_recovery() {
  local error_type="$1"  # prompt_too_long | max_output
  local state_file="$2"
  local log_dir="$3"

  RECOVERY_ATTEMPTS=$((RECOVERY_ATTEMPTS + 1))

  case "$RECOVERY_TIER" in
    0)
      # Tier 0: 무료 복구
      recover_tier0 "$error_type" "$state_file" "$log_dir"
      return $?
      ;;
    1)
      # Tier 1: 저비용 복구
      recover_tier1 "$error_type" "$state_file" "$log_dir"
      return $?
      ;;
    *)
      # Tier 2: 에스컬레이션
      emit_jsonl "RECOVERY_EXHAUSTED" "복구 소진 — 사용자 개입 필요" \
        "tier=2" "attempts=${RECOVERY_ATTEMPTS}" "error_type=${error_type}"
      return 1
      ;;
  esac
}

# ── Tier 0: 무료 복구 (API 호출 없음) ──
recover_tier0() {
  local error_type="$1"
  local state_file="$2"
  local log_dir="$3"

  if [ "$error_type" = "prompt_too_long" ]; then
    # 전략 A: 1M 컨텍스트 비활성화 (아직 안 했으면)
    if [ "$DISABLE_1M" = false ]; then
      ORIGINAL_DISABLE_1M=false
      DISABLE_1M=true
      export CLAUDE_CODE_DISABLE_1M_CONTEXT=1
      emit_jsonl "RECOVERY_TIER0" "1M 컨텍스트 비활성화로 복구 시도" \
        "tier=0" "strategy=disable_1m"
      echo "[복구] Tier 0: 1M 컨텍스트 비활성화" >&2
      return 0
    fi

    # 전략 B: 배치 크기 축소
    if [ "$BATCH_SIZE" -eq 0 ] || [ "$BATCH_SIZE" -gt 5 ]; then
      ORIGINAL_BATCH_SIZE=$BATCH_SIZE
      BATCH_SIZE=5
      emit_jsonl "RECOVERY_TIER0" "배치 크기 축소로 복구 시도" \
        "tier=0" "strategy=reduce_batch" "new_batch_size=5"
      echo "[복구] Tier 0: 배치 크기 → 5" >&2
      return 0
    fi

    # Tier 0 소진 → Tier 1로 승격
    RECOVERY_TIER=1
    recover_tier1 "$error_type" "$state_file" "$log_dir"
    return $?
  fi

  if [ "$error_type" = "max_output" ]; then
    # max_turns 증가로 복구 (에이전트가 이어서 작업)
    if [ "$MAX_TURNS" -lt 50 ]; then
      MAX_TURNS=$((MAX_TURNS + 10))
      emit_jsonl "RECOVERY_TIER0" "max_turns 증가로 복구 시도" \
        "tier=0" "strategy=increase_turns" "new_max_turns=${MAX_TURNS}"
      echo "[복구] Tier 0: max_turns → ${MAX_TURNS}" >&2
      return 0
    fi

    RECOVERY_TIER=1
    recover_tier1 "$error_type" "$state_file" "$log_dir"
    return $?
  fi

  return 1
}

# ── Tier 1: 저비용 복구 ──
recover_tier1() {
  local error_type="$1"
  local state_file="$2"
  local log_dir="$3"

  if [ "$error_type" = "prompt_too_long" ]; then
    # 가장 많이 수정된 상위 파일만 남기고 나머지 제외
    local top_files
    top_files=$(jq -r '
      .files | to_entries
      | map(select(.value.status == "active"))
      | sort_by(-.value.total_modifications)
      | .[0:3]
      | .[].key
    ' "$state_file" 2>/dev/null)

    if [ -n "$top_files" ]; then
      local tmp="${state_file}.tmp"
      cp "$state_file" "$tmp"

      # 상위 3개 외 active 파일을 suspended로 전환
      jq '
        .files |= with_entries(
          if .value.status == "active" then
            .value.status = "suspended"
          else . end
        )
      ' "$tmp" > "${tmp}.2" && mv "${tmp}.2" "$tmp"

      while IFS= read -r f; do
        [ -z "$f" ] && continue
        jq --arg f "$f" '.files[$f].status = "active"' \
          "$tmp" > "${tmp}.2" && mv "${tmp}.2" "$tmp"
      done <<< "$top_files"

      mv "$tmp" "$state_file"

      emit_jsonl "RECOVERY_TIER1" "스코프 축소: 상위 3개 파일만 활성" \
        "tier=1" "strategy=reduce_scope"
      echo "[복구] Tier 1: 스코프 축소 — 가장 변경이 많은 3개 파일만 활성" >&2
      RECOVERY_TIER=2
      return 0
    fi
  fi

  # Tier 1 소진
  RECOVERY_TIER=2
  return 1
}

# ── 복구 상태 리셋 (라운드 성공 시) ──
reset_recovery() {
  if [ "$RECOVERY_TIER" -gt 0 ]; then
    emit_jsonl "RECOVERY_RESET" "정상 실행 복귀" \
      "tier=${RECOVERY_TIER}" "attempts=${RECOVERY_ATTEMPTS}"

    # suspended 파일 복원
    if [ -n "${1:-}" ] && [ -f "$1" ]; then
      jq '
        .files |= with_entries(
          if .value.status == "suspended" then
            .value.status = "active"
          else . end
        )
      ' "$1" > "${1}.tmp" && mv "${1}.tmp" "$1"
    fi
  fi

  RECOVERY_TIER=0
  RECOVERY_ATTEMPTS=0

  # 원래 설정 복원
  if [ "$ORIGINAL_DISABLE_1M" = false ] && [ "$DISABLE_1M" = true ]; then
    DISABLE_1M=false
    unset CLAUDE_CODE_DISABLE_1M_CONTEXT
  fi
  if [ "$ORIGINAL_BATCH_SIZE" -gt 0 ]; then
    BATCH_SIZE=$ORIGINAL_BATCH_SIZE
    ORIGINAL_BATCH_SIZE=0
  fi
}
