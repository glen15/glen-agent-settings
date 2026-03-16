#!/bin/bash
# Ralph Loop - Claude Code 어댑터
# claude -p (piped 모드)로 에이전트 실행

ADAPTER_NAME="claude"

# claude -p 실행
run_agent() {
  local prompt_file="$1"
  local output_file="$2"
  local max_turns="$3"
  local model="$4"

  # 무인 루프 전용 — 대화형 사용 금지
  local cmd_args=("-p" "--max-turns" "$max_turns" "--output-format" "json" "--permission-mode" "bypassPermissions")

  if [ -n "$model" ]; then
    cmd_args+=("--model" "$model")
  fi

  cat "$prompt_file" | claude "${cmd_args[@]}" > "$output_file" 2>&1
  return $?
}

# claude JSON 출력에서 토큰 사용량 추출
parse_adapter_tokens() {
  local output_file="$1"
  local input_tokens=0
  local output_tokens=0

  if [ -f "$output_file" ]; then
    input_tokens=$(jq -r '.usage.input_tokens // .result.usage.input_tokens // 0' "$output_file" 2>/dev/null || echo 0)
    output_tokens=$(jq -r '.usage.output_tokens // .result.usage.output_tokens // 0' "$output_file" 2>/dev/null || echo 0)
  fi

  echo "${input_tokens}:${output_tokens}"
}

# dry-run 모의 출력
dry_run_output() {
  echo '{"dry_run": true, "adapter": "claude", "usage": {"input_tokens": 0, "output_tokens": 0}}'
}

# rate limit 키워드 (claude 전용)
rate_limit_pattern='rate.?limit|usage.?limit|exceed|throttl|429|too many requests'

# provider 에러 키워드
provider_error_pattern='5[0-9]{2}|internal.?server|service.?unavailable|bad.?gateway|overloaded'
