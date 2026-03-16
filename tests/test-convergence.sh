#!/bin/bash
# convergence.sh 단위 테스트

echo "-- 수렴 루프 단위 테스트 --"

source "${PROJECT_DIR}/src/ralph-loop/lib/convergence.sh"

# 원래 PROJECT_DIR 보존 (bash 3.2 VAR=val func 영구 변경 방지)
_ORIG_PROJECT_DIR="$PROJECT_DIR"

# 테스트용 임시 디렉토리
CONV_DIR=$(mktemp -d)
(cd "$CONV_DIR" && git init -q && git commit --allow-empty -m "init" -q)

# 테스트 파일 생성
echo "content1" > "${CONV_DIR}/file1.txt"
echo "content2" > "${CONV_DIR}/file2.txt"
echo "content3" > "${CONV_DIR}/file3.txt"
(cd "$CONV_DIR" && git add -A && git commit -m "add files" -q)

STATE_FILE="${CONV_DIR}/scope-state.json"

# ── init_scope_state 테스트 ──
PROJECT_DIR="$CONV_DIR" init_scope_state "*.txt" "$CONV_DIR" "$STATE_FILE" 3 2 2>/dev/null
assert_file_exists "$STATE_FILE" "scope-state.json 생성됨"

local_file_count=$(jq '.files | length' "$STATE_FILE")
assert_eq "3" "$local_file_count" "init_scope_state: 3개 파일 등록"

local_mode=$(jq -r '.mode' "$STATE_FILE")
assert_eq "converge" "$local_mode" "init_scope_state: mode=converge"

local_skip_after=$(jq '.skip_after' "$STATE_FILE")
assert_eq "3" "$local_skip_after" "init_scope_state: skip_after=3"

# ── get_active_files 테스트 ──
local_active_count=$(get_active_files "$STATE_FILE" | wc -l | tr -d ' ')
assert_eq "3" "$local_active_count" "get_active_files: 3개 활성"

# ── get_active_count 테스트 ──
local_active_num=$(get_active_count "$STATE_FILE")
assert_eq "3" "$local_active_num" "get_active_count: 3"

# ── update_file_state: 수정 없는 라운드 ──
PROJECT_DIR="$CONV_DIR" mark_round_start 1
PROJECT_DIR="$CONV_DIR" local_changes=$(update_file_state "$STATE_FILE" 1)
assert_eq "0" "$local_changes" "update_file_state: 변경 0건"

local_skip1=$(jq -r '.files | to_entries[0].value.consecutive_skips' "$STATE_FILE")
assert_eq "1" "$local_skip1" "update_file_state: consecutive_skips 증가"

local_zero=$(jq '.consecutive_zero_rounds' "$STATE_FILE")
assert_eq "1" "$local_zero" "update_file_state: consecutive_zero_rounds=1"

# ── update_file_state: 수정 있는 라운드 ──
PROJECT_DIR="$CONV_DIR" mark_round_start 2
echo "modified" > "${CONV_DIR}/file1.txt"
(cd "$CONV_DIR" && git add file1.txt && git commit -m "modify file1" -q)
PROJECT_DIR="$CONV_DIR" local_changes2=$(update_file_state "$STATE_FILE" 2)
assert_eq "1" "$local_changes2" "update_file_state: 변경 1건"

local_zero2=$(jq '.consecutive_zero_rounds' "$STATE_FILE")
assert_eq "0" "$local_zero2" "update_file_state: 변경 후 zero 리셋"

# ── check_convergence: 아직 수렴 안됨 ──
if check_convergence "$STATE_FILE" 2; then
  FAIL=$((FAIL + 1))
  echo -e "  ${RED}FAIL${NC} check_convergence: 아직 수렴 아님인데 수렴 판정"
else
  PASS=$((PASS + 1))
  echo -e "  ${GREEN}PASS${NC} check_convergence: 아직 수렴 아님 정상"
fi

# ── apply_exclusions: skip_after 미달 시 제외 없음 ──
local_excluded=$(apply_exclusions "$STATE_FILE" 3 2)
assert_eq "0" "$local_excluded" "apply_exclusions: skip_after 미달 시 제외 0"

# ── apply_exclusions: skip_after 도달 시 제외 ──
# file2, file3을 consecutive_skips=3으로 수동 설정
local_tmp="${STATE_FILE}.tmp"
local_f2_key=$(jq -r '.files | keys[] | select(endswith("file2.txt"))' "$STATE_FILE")
local_f3_key=$(jq -r '.files | keys[] | select(endswith("file3.txt"))' "$STATE_FILE")
jq --arg k "$local_f2_key" '.files[$k].consecutive_skips = 3' "$STATE_FILE" > "$local_tmp" && mv "$local_tmp" "$STATE_FILE"
jq --arg k "$local_f3_key" '.files[$k].consecutive_skips = 3' "$STATE_FILE" > "$local_tmp" && mv "$local_tmp" "$STATE_FILE"

local_excluded2=$(apply_exclusions "$STATE_FILE" 3 3)
assert_eq "2" "$local_excluded2" "apply_exclusions: 2개 파일 제외"

local_active_after=$(get_active_count "$STATE_FILE")
assert_eq "1" "$local_active_after" "apply_exclusions 후 active=1"

# ── check_convergence: 수동으로 consecutive_zero_rounds=2 설정 ──
jq '.consecutive_zero_rounds = 2' "$STATE_FILE" > "$local_tmp" && mv "$local_tmp" "$STATE_FILE"
if check_convergence "$STATE_FILE" 2; then
  PASS=$((PASS + 1))
  echo -e "  ${GREEN}PASS${NC} check_convergence: 2라운드 연속 변경0 → 수렴 판정"
else
  FAIL=$((FAIL + 1))
  echo -e "  ${RED}FAIL${NC} check_convergence: 수렴 판정 실패"
fi

# ── parse_exception_md 테스트 ──
cat > "${CONV_DIR}/exception.md" << 'EXCEOF'
# Exception

## 수정 요청
- file1.txt: 첫 줄을 대문자로

## 제외 요청
- file1.txt: 이 파일은 건드리지 마세요

## 기준 변경
- 모든 파일은 UTF-8 인코딩이어야 함
EXCEOF

parse_exception_md "${CONV_DIR}/exception.md"
assert_contains "$EXCEPTION_FIXES" "첫 줄을 대문자로" "parse_exception_md: 수정 요청 파싱"
assert_contains "$EXCEPTION_EXCLUDES" "file1.txt" "parse_exception_md: 제외 요청 파싱"
assert_contains "$EXCEPTION_CRITERIA" "UTF-8" "parse_exception_md: 기준 변경 파싱"

# ── get_batch_files 테스트 ──
# state 리셋
PROJECT_DIR="$CONV_DIR" init_scope_state "*.txt" "$CONV_DIR" "$STATE_FILE" 3 2 2>/dev/null
local_batch=$(get_batch_files "$STATE_FILE" 2 | wc -l | tr -d ' ')
assert_eq "2" "$local_batch" "get_batch_files: batch_size=2 → 2개"

local_all=$(get_batch_files "$STATE_FILE" 0 | wc -l | tr -d ' ')
assert_eq "3" "$local_all" "get_batch_files: batch_size=0 → 전체"

# ── generate_round_summary 테스트 ──
local_summary=$(generate_round_summary "$STATE_FILE" 5 3 1)
assert_contains "$local_summary" "라운드 #5" "generate_round_summary: 라운드 번호 포함"
assert_contains "$local_summary" "변경: 3건" "generate_round_summary: 변경 수 포함"

# 정리
rm -rf "$CONV_DIR"
PROJECT_DIR="$_ORIG_PROJECT_DIR"
