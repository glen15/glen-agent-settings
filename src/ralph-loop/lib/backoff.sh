#!/bin/bash
# Ralph Loop - Rate limit 감지 + Exponential Backoff

# 기본 감지 패턴 (어댑터가 덮어쓸 수 있음)
if [ -z "${rate_limit_pattern:-}" ]; then
  rate_limit_pattern='rate.?limit|usage.?limit|exceed|throttl|429|too many requests'
fi
if [ -z "${provider_error_pattern:-}" ]; then
  provider_error_pattern='5[0-9]{2}|internal.?server|service.?unavailable|bad.?gateway|overloaded'
fi

# rate limit 키워드 감지
detect_rate_limit() {
  local output="$1"
  echo "$output" | grep -qiE "$rate_limit_pattern"
}

# provider 장애 감지
detect_provider_error() {
  local output="$1"
  echo "$output" | grep -qiE "$provider_error_pattern"
}

# exponential backoff 대기
# 사용법: wait_with_backoff <attempt_number> <log_file>
# attempt 1 → 30분, 2 → 60분, 3 → 120분, 최대 240분
wait_with_backoff() {
  local attempt="${1:-1}"
  local log_file="${2:-/dev/null}"
  local base_minutes=30
  local max_minutes=240

  local wait_minutes=$(( base_minutes * (2 ** (attempt - 1)) ))
  if [ "$wait_minutes" -gt "$max_minutes" ]; then
    wait_minutes=$max_minutes
  fi

  local wait_seconds=$(( wait_minutes * 60 ))
  local resume_time
  resume_time=$(date -v "+${wait_minutes}M" "+%H:%M" 2>/dev/null \
    || date -d "+${wait_minutes} minutes" "+%H:%M" 2>/dev/null \
    || echo "?")

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Rate limit 감지 (시도 #${attempt}). ${wait_minutes}분 대기 (재개 예정: ${resume_time})" >> "$log_file"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Rate limit 감지 (시도 #${attempt}). ${wait_minutes}분 대기..." >&2
  sleep "$wait_seconds"
}
