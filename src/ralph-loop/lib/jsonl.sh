#!/bin/bash
# JSONL 구조화 로깅 라이브러리
# 모든 이벤트를 progress.jsonl에 append-only로 기록

JSONL_FILE=""

# ── 초기화 ──
init_jsonl() {
  JSONL_FILE="${1}/progress.jsonl"
  touch "$JSONL_FILE"
}

# ── 이벤트 기록 ──
# 사용법: emit_jsonl "step" "message" [key=value ...]
emit_jsonl() {
  local step="$1"
  local message="$2"
  shift 2

  local ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

  # 기본 JSON 구성
  local json
  json=$(jq -c -n \
    --arg ts "$ts" \
    --arg step "$step" \
    --arg message "$message" \
    '{ts: $ts, step: $step, message: $message}')

  # 추가 key=value 파싱
  while [ $# -gt 0 ]; do
    local key="${1%%=*}"
    local value="${1#*=}"
    # 숫자면 숫자로, 아니면 문자열로
    if [[ "$value" =~ ^[0-9]+$ ]]; then
      json=$(echo "$json" | jq -c --arg k "$key" --argjson v "$value" '. + {($k): $v}')
    else
      json=$(echo "$json" | jq -c --arg k "$key" --arg v "$value" '. + {($k): $v}')
    fi
    shift
  done

  echo "$json" >> "$JSONL_FILE"
}

# ── claude 출력에서 토큰 사용량 추출 ──
parse_token_usage() {
  local output_file="$1"
  local input_tokens=0
  local output_tokens=0

  if [ -f "$output_file" ]; then
    input_tokens=$(jq -r '.usage.input_tokens // .result.usage.input_tokens // 0' "$output_file" 2>/dev/null || echo 0)
    output_tokens=$(jq -r '.usage.output_tokens // .result.usage.output_tokens // 0' "$output_file" 2>/dev/null || echo 0)
  fi

  echo "${input_tokens}:${output_tokens}"
}

# ── 세션 상태 저장 ──
save_session() {
  local log_dir="$1"
  local session_file="${log_dir}/session.json"

  jq -n \
    --arg id "ralph-$(date +%Y%m%d-%H%M%S)" \
    --arg project "$PROJECT_DIR" \
    --arg branch "$BRANCH" \
    --arg model "$MODEL" \
    --arg scope "${SCOPE:-all}" \
    --argjson max_iterations "$MAX_ITERATIONS" \
    --argjson max_turns "$MAX_TURNS" \
    --arg started_at "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    '{
      session_id: $id,
      project_dir: $project,
      branch: $branch,
      model: $model,
      scope: $scope,
      max_iterations: $max_iterations,
      max_turns: $max_turns,
      started_at: $started_at,
      status: "running"
    }' > "$session_file"
}

# ── 세션 상태 로드 (resume용) ──
load_session() {
  local session_file="$1/session.json"

  if [ ! -f "$session_file" ]; then
    echo "오류: 세션 파일 없음: $session_file" >&2
    return 1
  fi

  # 세션 설정 복원
  PROJECT_DIR=$(jq -r '.project_dir' "$session_file")
  BRANCH=$(jq -r '.branch' "$session_file")
  MODEL=$(jq -r '.model // ""' "$session_file")
  SCOPE=$(jq -r '.scope // "all"' "$session_file")
  MAX_ITERATIONS=$(jq -r '.max_iterations' "$session_file")
  MAX_TURNS=$(jq -r '.max_turns' "$session_file")
}

# ── 마지막 완료 iteration 번호 조회 ──
get_last_iteration() {
  local log_dir="$1"
  local jsonl="${log_dir}/progress.jsonl"

  if [ ! -f "$jsonl" ]; then
    echo 0
    return
  fi

  # ITERATION_END 이벤트에서 마지막 iteration 번호 추출
  local last
  last=$(jq -r 'select(.step == "ITERATION_END") | .iteration' "$jsonl" 2>/dev/null | tail -1)
  echo "${last:-0}"
}

# ── 세션 완료 마킹 ──
finalize_session() {
  local log_dir="$1"
  local status="$2"  # completed, interrupted, stagnated
  local session_file="${log_dir}/session.json"

  if [ -f "$session_file" ]; then
    local tmp
    tmp=$(jq --arg s "$status" --arg t "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
      '.status = $s | .finished_at = $t' "$session_file")
    echo "$tmp" > "$session_file"
  fi
}
