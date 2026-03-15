#!/bin/bash
# jsonl.sh 단위 테스트

# jsonl.sh가 필요로 하는 전역 변수 설정
PROJECT_DIR="${PROJECT_DIR}"
BRANCH="test-branch"
PRD_FILE="/tmp/test-prd.json"
MODEL="sonnet"
MAX_ITERATIONS=10
MAX_TURNS=5

source "${PROJECT_DIR}/src/ralph-loop/lib/jsonl.sh"

echo "-- init_jsonl --"

JSONL_DIR=$(mktemp -d)
init_jsonl "$JSONL_DIR"
assert_file_exists "${JSONL_DIR}/progress.jsonl" "progress.jsonl 생성됨"

echo "-- emit_jsonl --"

emit_jsonl "TEST_EVENT" "테스트 메시지"
local_line_count=$(wc -l < "${JSONL_DIR}/progress.jsonl" | tr -d ' ')
assert_eq "1" "$local_line_count" "이벤트 1줄 기록"

# JSON 유효성 검사
local_valid=$(jq -r '.step' "${JSONL_DIR}/progress.jsonl" 2>/dev/null | head -1)
assert_eq "TEST_EVENT" "$local_valid" "step 필드 올바름"

local_msg=$(jq -r '.message' "${JSONL_DIR}/progress.jsonl" 2>/dev/null | head -1)
assert_eq "테스트 메시지" "$local_msg" "message 필드 올바름"

# key=value 추가 파라미터
emit_jsonl "METRIC" "메트릭 테스트" "iteration=5" "exit_code=0"
local_iter=$(tail -1 "${JSONL_DIR}/progress.jsonl" | jq -r '.iteration')
assert_eq "5" "$local_iter" "숫자 파라미터 올바름"

echo "-- parse_token_usage --"

local_token_file="${JSONL_DIR}/claude-output.json"
echo '{"usage": {"input_tokens": 1500, "output_tokens": 300}}' > "$local_token_file"
local_usage=$(parse_token_usage "$local_token_file")
assert_eq "1500:300" "$local_usage" "토큰 사용량 파싱"

# 사용량 정보 없는 경우
echo '{"result": "ok"}' > "$local_token_file"
local_usage_empty=$(parse_token_usage "$local_token_file")
assert_eq "0:0" "$local_usage_empty" "토큰 정보 없으면 0:0"

echo "-- save_session / load_session --"

save_session "$JSONL_DIR"
assert_file_exists "${JSONL_DIR}/session.json" "session.json 생성됨"

local_session_project=$(jq -r '.project_dir' "${JSONL_DIR}/session.json")
assert_eq "$PROJECT_DIR" "$local_session_project" "세션에 프로젝트 경로 저장"

local_session_status=$(jq -r '.status' "${JSONL_DIR}/session.json")
assert_eq "running" "$local_session_status" "세션 상태 running"

echo "-- finalize_session --"

finalize_session "$JSONL_DIR" "completed"
local_final_status=$(jq -r '.status' "${JSONL_DIR}/session.json")
assert_eq "completed" "$local_final_status" "세션 상태 completed"

local_finished=$(jq -r '.finished_at' "${JSONL_DIR}/session.json")
if [ "$local_finished" != "null" ] && [ -n "$local_finished" ]; then
  PASS=$((PASS + 1))
  echo -e "  ${GREEN}PASS${NC} finished_at 설정됨"
else
  FAIL=$((FAIL + 1))
  echo -e "  ${RED}FAIL${NC} finished_at 미설정"
fi

echo "-- get_last_iteration --"

# ITERATION_END 이벤트가 있는 JSONL
emit_jsonl "ITERATION_END" "반복 완료" "iteration=3"
emit_jsonl "ITERATION_END" "반복 완료" "iteration=7"
local_last=$(get_last_iteration "$JSONL_DIR")
assert_eq "7" "$local_last" "마지막 iteration 번호"

# 정리
rm -rf "$JSONL_DIR"
