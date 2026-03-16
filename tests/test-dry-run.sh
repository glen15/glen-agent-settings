#!/bin/bash
# ralph-loop.sh --dry-run 통합 테스트

echo "-- dry-run 통합 테스트 --"

# 임시 프로젝트 디렉토리 생성
DRY_DIR=$(mktemp -d)
(cd "$DRY_DIR" && git init -q && git commit --allow-empty -m "init" -q)

# task_plan.md 생성
cat > "${DRY_DIR}/task_plan.md" << 'EOF'
# Task Plan

## 기준
- 모든 파일은 UTF-8 인코딩
- 한 줄은 80자 이하
EOF

# 대상 파일 생성
echo "hello" > "${DRY_DIR}/a.txt"
echo "world" > "${DRY_DIR}/b.txt"
(cd "$DRY_DIR" && git add -A && git commit -m "add files" -q)

# dry-run 실행
OUTPUT=$(bash "${PROJECT_DIR}/src/ralph-loop/ralph-loop.sh" \
  --project-dir "$DRY_DIR" \
  --scope "*.txt" \
  --task-plan "${DRY_DIR}/task_plan.md" \
  --max-iterations 3 \
  --no-wait \
  --dry-run 2>&1)

# 결과 검증
assert_contains "$OUTPUT" "Ralph Loop 시작" "시작 메시지 출력"
assert_contains "$OUTPUT" "Ralph Loop 종료" "종료 메시지 출력"
assert_contains "$OUTPUT" "재개: ralph-loop --resume" "재개 안내 출력"

# scope-state.json 확인
LOG_DIRS=$(ls -d "${DRY_DIR}/.ralph-logs/"* 2>/dev/null)
if [ -n "$LOG_DIRS" ]; then
  LATEST_LOG=$(echo "$LOG_DIRS" | tail -1)
  assert_file_exists "${LATEST_LOG}/scope-state.json" "scope-state.json 생성됨"
  assert_file_exists "${LATEST_LOG}/progress.jsonl" "JSONL 로그 생성됨"
  assert_file_exists "${LATEST_LOG}/session.json" "세션 파일 생성됨"
  assert_file_exists "${LATEST_LOG}/summary.md" "요약 파일 생성됨"

  # scope-state.json 검증
  local_conv_mode=$(jq -r '.mode' "${LATEST_LOG}/scope-state.json" 2>/dev/null)
  assert_eq "converge" "$local_conv_mode" "scope-state.json mode=converge"

  # session.json 검증
  local_session_status=$(jq -r '.status' "${LATEST_LOG}/session.json")
  assert_eq "converged" "$local_session_status" "세션 상태 converged"

  # JSONL 이벤트 확인
  local_events=$(jq -r '.step' "${LATEST_LOG}/progress.jsonl" 2>/dev/null | sort -u | tr '\n' ',')
  assert_contains "$local_events" "ROUND_START" "ROUND_START 이벤트 기록"
  assert_contains "$local_events" "ROUND_END" "ROUND_END 이벤트 기록"
else
  FAIL=$((FAIL + 1))
  echo -e "  ${RED}FAIL${NC} 로그 디렉토리 없음"
fi

# exception.md 템플릿 복사 확인
assert_file_exists "${DRY_DIR}/exception.md" "exception.md 템플릿 생성됨"

# 정리
rm -rf "$DRY_DIR"
