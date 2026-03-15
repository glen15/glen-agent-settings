#!/bin/bash
# Ralph Loop - OpenAI Codex CLI 어댑터
# codex exec (non-interactive 모드)로 에이전트 실행
#
# 필요: codex CLI 설치 (npm install -g @openai/codex)
# 참고: https://developers.openai.com/codex/cli/

ADAPTER_NAME="codex"

# codex exec 실행
run_agent() {
  local prompt_file="$1"
  local output_file="$2"
  local max_turns="$3"  # codex에서는 직접 지원하지 않음 (AGENTS.md로 제어)
  local model="$4"

  local cmd_args=("exec" "--json" "--full-auto")

  if [ -n "$model" ]; then
    cmd_args+=("-m" "$model")
  fi

  # codex exec는 프롬프트를 인자로 받음
  local prompt
  prompt=$(cat "$prompt_file")

  codex "${cmd_args[@]}" "$prompt" > "$output_file" 2>&1
  return $?
}

# codex JSON 출력에서 토큰 사용량 추출
parse_adapter_tokens() {
  local output_file="$1"
  local input_tokens=0
  local output_tokens=0

  if [ -f "$output_file" ]; then
    # codex exec --json은 JSONL 스트림 출력
    # 마지막 usage 이벤트에서 토큰 추출
    input_tokens=$(jq -r 'select(.type == "usage") | .input_tokens // 0' "$output_file" 2>/dev/null | tail -1 || echo 0)
    output_tokens=$(jq -r 'select(.type == "usage") | .output_tokens // 0' "$output_file" 2>/dev/null | tail -1 || echo 0)

    # 대체 경로: summary 형식
    if [ "$input_tokens" = "0" ] && [ "$output_tokens" = "0" ]; then
      input_tokens=$(jq -r '.usage.prompt_tokens // .usage.input_tokens // 0' "$output_file" 2>/dev/null | head -1 || echo 0)
      output_tokens=$(jq -r '.usage.completion_tokens // .usage.output_tokens // 0' "$output_file" 2>/dev/null | head -1 || echo 0)
    fi
  fi

  echo "${input_tokens}:${output_tokens}"
}

# dry-run 모의 출력
dry_run_output() {
  echo '{"dry_run": true, "adapter": "codex", "usage": {"prompt_tokens": 0, "completion_tokens": 0}}'
}

# rate limit 키워드 (OpenAI 전용)
rate_limit_pattern='rate.?limit|429|too many requests|tokens per min|requests per min|quota exceeded'

# provider 에러 키워드
provider_error_pattern='5[0-9]{2}|internal.?server|service.?unavailable|bad.?gateway|server_error|overloaded'
