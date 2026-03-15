#!/bin/bash
# Ralph Loop - 순환 에러 감지

# iteration 출력의 해시 계산
compute_output_hash() {
  local file="$1"
  if [ -f "$file" ]; then
    md5 -q "$file" 2>/dev/null || md5sum "$file" 2>/dev/null | cut -d' ' -f1 || echo ""
  else
    echo ""
  fi
}

# 최근 N개 반복의 출력 해시를 비교하여 순환 감지
# 사용법: detect_stagnation <log_dir> <current_iteration> <window_size>
# 반환: 0=정상, 1=순환 감지
detect_stagnation() {
  local log_dir="$1"
  local current_iter="$2"
  local window="${3:-3}"

  if [ "$current_iter" -lt "$window" ]; then
    return 1
  fi

  local current_hash
  current_hash=$(compute_output_hash "${log_dir}/iteration-${current_iter}.json")
  if [ -z "$current_hash" ]; then
    return 1
  fi

  local prev_hash
  prev_hash=$(compute_output_hash "${log_dir}/iteration-$((current_iter - 1)).json")

  if [ "$current_hash" = "$prev_hash" ]; then
    return 0  # 순환 감지
  fi

  return 1
}

# 마지막 커밋 이후 경과 시간 확인
# 반환: 0=타임아웃, 1=정상
detect_no_commit() {
  local timeout_minutes="${1:-30}"

  if ! command -v git >/dev/null 2>&1 || ! git rev-parse --git-dir >/dev/null 2>&1; then
    return 1
  fi

  local last_commit_epoch
  last_commit_epoch=$(git log -1 --format=%ct 2>/dev/null || echo "0")
  local now_epoch
  now_epoch=$(date +%s)
  local elapsed_minutes=$(( (now_epoch - last_commit_epoch) / 60 ))

  if [ "$elapsed_minutes" -ge "$timeout_minutes" ]; then
    return 0  # 타임아웃
  fi

  return 1
}
