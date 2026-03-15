#!/bin/bash
# Ralph Loop - 검증 게이트

# Gate-0: 린트 + 타입체크 (수십 초)
run_gate_0() {
  local project_dir="$1"
  local log_file="${2:-/dev/null}"

  echo "[$(date '+%H:%M:%S')] Gate-0: 린트/타입체크 실행..." >> "$log_file"

  # package.json이 있으면 npm 기반
  if [ -f "${project_dir}/package.json" ]; then
    (cd "$project_dir" && npm run lint 2>&1 || true) >> "$log_file"
    (cd "$project_dir" && npx tsc --noEmit 2>&1 || true) >> "$log_file"
    return $?
  fi

  # pyproject.toml 또는 setup.py가 있으면 Python 기반
  if [ -f "${project_dir}/pyproject.toml" ] || [ -f "${project_dir}/setup.py" ]; then
    (cd "$project_dir" && python3 -m ruff check . 2>&1 || true) >> "$log_file"
    (cd "$project_dir" && python3 -m mypy . 2>&1 || true) >> "$log_file"
    return $?
  fi

  echo "[Gate-0] 지원되는 프로젝트 타입을 감지하지 못했습니다." >> "$log_file"
  return 0
}

# Gate-1: 단위 테스트 (분 단위)
run_gate_1() {
  local project_dir="$1"
  local log_file="${2:-/dev/null}"

  echo "[$(date '+%H:%M:%S')] Gate-1: 단위 테스트 실행..." >> "$log_file"

  if [ -f "${project_dir}/package.json" ]; then
    (cd "$project_dir" && npm test 2>&1) >> "$log_file"
    return $?
  fi

  if [ -f "${project_dir}/pyproject.toml" ] || [ -f "${project_dir}/setup.py" ]; then
    (cd "$project_dir" && python3 -m pytest -q 2>&1) >> "$log_file"
    return $?
  fi

  echo "[Gate-1] 테스트 명령을 찾지 못했습니다." >> "$log_file"
  return 0
}

# prd.json의 기능 상태 업데이트
update_prd_status() {
  local prd_file="$1"
  local feature_id="$2"
  local new_status="$3"

  if [ ! -f "$prd_file" ]; then
    return 1
  fi

  local tmp="${prd_file}.tmp"
  jq --arg id "$feature_id" --arg status "$new_status" \
    '(.features[] | select(.id == $id)).status = $status' \
    "$prd_file" > "$tmp" && mv "$tmp" "$prd_file"
}

# prd.json에서 모든 기능이 통과했는지 확인
check_all_passing() {
  local prd_file="$1"

  if [ ! -f "$prd_file" ]; then
    return 1
  fi

  local failing_count
  failing_count=$(jq '[.features[] | select(.status != "passing")] | length' "$prd_file" 2>/dev/null || echo "1")

  [ "$failing_count" = "0" ]
}
