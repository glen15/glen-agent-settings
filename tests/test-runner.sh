#!/bin/bash
# Ralph Loop 테스트 러너
# 사용법: bash tests/test-runner.sh

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TESTS_DIR")"
PASS=0
FAIL=0
ERRORS=()

# 색상
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-}"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} $msg"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("$msg: expected='$expected' actual='$actual'")
    echo -e "  ${RED}FAIL${NC} $msg (expected='$expected', actual='$actual')"
  fi
}

assert_exit() {
  local expected_code="$1"
  shift
  local actual_code=0
  "$@" >/dev/null 2>&1 || actual_code=$?
  local msg="${*}"
  if [ "$expected_code" = "$actual_code" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} exit=$expected_code: $msg"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("exit=$actual_code (expected $expected_code): $msg")
    echo -e "  ${RED}FAIL${NC} exit=$actual_code (expected $expected_code): $msg"
  fi
}

assert_file_exists() {
  local file="$1"
  local msg="${2:-$file exists}"
  if [ -f "$file" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} $msg"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("$msg: file not found")
    echo -e "  ${RED}FAIL${NC} $msg: file not found"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="${3:-}"
  if echo "$haystack" | grep -q "$needle"; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} $msg"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("$msg: '$needle' not found")
    echo -e "  ${RED}FAIL${NC} $msg: '$needle' not found"
  fi
}

# 테스트 파일 실행
for test_file in "$TESTS_DIR"/test-*.sh; do
  [ "$test_file" = "$TESTS_DIR/test-runner.sh" ] && continue
  [ ! -f "$test_file" ] && continue

  echo ""
  echo "=== $(basename "$test_file") ==="
  source "$test_file"
done

# 결과 요약
echo ""
echo "========================"
echo -e "통과: ${GREEN}${PASS}${NC}  실패: ${RED}${FAIL}${NC}"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""
  echo "실패 상세:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
fi
echo "========================"

[ "$FAIL" -eq 0 ]
