#!/bin/bash
# ralph-loop.sh --dry-run 통합 테스트

echo "-- dry-run 통합 테스트 --"

# 임시 프로젝트 디렉토리 생성
DRY_DIR=$(mktemp -d)
(cd "$DRY_DIR" && git init -q && git commit --allow-empty -m "init" -q)

# prd.json 생성 (모두 passing이면 1회만 실행하고 종료)
cat > "${DRY_DIR}/prd.json" << 'EOF'
{"features": [{"id": "f1", "status": "passing"}]}
EOF

# dry-run 실행
OUTPUT=$(bash "${PROJECT_DIR}/src/ralph-loop/ralph-loop.sh" \
  --project-dir "$DRY_DIR" \
  --max-iterations 3 \
  --dry-run 2>&1)

# 결과 검증
assert_contains "$OUTPUT" "Ralph Loop 시작" "시작 메시지 출력"
assert_contains "$OUTPUT" "Ralph Loop 종료" "종료 메시지 출력"
assert_contains "$OUTPUT" "재개: ralph-loop --resume" "재개 안내 출력"

# 로그 파일 확인
LOG_DIRS=$(ls -d "${DRY_DIR}/.ralph-logs/"* 2>/dev/null)
if [ -n "$LOG_DIRS" ]; then
  LATEST_LOG=$(echo "$LOG_DIRS" | tail -1)
  assert_file_exists "${LATEST_LOG}/progress.jsonl" "JSONL 로그 생성됨"
  assert_file_exists "${LATEST_LOG}/session.json" "세션 파일 생성됨"
  assert_file_exists "${LATEST_LOG}/init.json" "init 출력 생성됨"
  assert_file_exists "${LATEST_LOG}/summary.md" "요약 파일 생성됨"

  # session.json 검증
  local_session_status=$(jq -r '.status' "${LATEST_LOG}/session.json")
  assert_eq "completed" "$local_session_status" "세션 상태 completed"

  # JSONL 이벤트 존재 확인
  local_events=$(jq -r '.step' "${LATEST_LOG}/progress.jsonl" 2>/dev/null | sort -u | tr '\n' ',')
  assert_contains "$local_events" "INIT_START" "INIT_START 이벤트 기록"
  assert_contains "$local_events" "ALL_PASSING" "ALL_PASSING 이벤트 기록"
else
  FAIL=$((FAIL + 1))
  echo -e "  ${RED}FAIL${NC} 로그 디렉토리 없음"
fi

# 정리
rm -rf "$DRY_DIR"
