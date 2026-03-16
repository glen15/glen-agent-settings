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

# scope-state.json에서 수렴 완료 여부 확인
check_convergence_state() {
  local state_file="$1"
  local threshold="${2:-2}"

  if [ ! -f "$state_file" ]; then
    return 1
  fi

  local zero_rounds
  zero_rounds=$(jq '.consecutive_zero_rounds' "$state_file" 2>/dev/null || echo "0")
  [ "$zero_rounds" -ge "$threshold" ]
}
