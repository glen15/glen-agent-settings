#!/bin/bash
# UserPromptSubmit Hook — 활성 /begin 작업 컨텍스트 주입
# .claude/tasks/*/progress.md에서 "완료" 아닌 작업을 찾아 컨텍스트 주입
set -euo pipefail

input=$(cat)

TASK_DIR=".claude/tasks"
[ ! -d "$TASK_DIR" ] && exit 0

# 활성 작업 탐색 (progress.md에 "완료"가 아닌 것)
active_tasks=""
for progress_file in "$TASK_DIR"/*/progress.md; do
  [ ! -f "$progress_file" ] && continue
  status=$(grep -m1 '^## 현재 상태:' "$progress_file" 2>/dev/null | sed 's/^## 현재 상태: *//' || echo "")
  if [ -n "$status" ] && [ "$status" != "완료" ]; then
    task_name=$(basename "$(dirname "$progress_file")")
    active_tasks="${active_tasks}${task_name} (${status})\n"
  fi
done

[ -z "$active_tasks" ] && exit 0

# contract.md 존재 여부
contract_hint=""
for progress_file in "$TASK_DIR"/*/progress.md; do
  [ ! -f "$progress_file" ] && continue
  task_dir=$(dirname "$progress_file")
  task_name=$(basename "$task_dir")
  if [ ! -f "${task_dir}/contract.md" ] || ! grep -q '[^[:space:]]' "${task_dir}/contract.md" 2>/dev/null; then
    contract_hint=" | contract.md 미작성 — 완료 기준을 정의하세요"
  fi
done

# 컨텍스트 주입
ctx="[Task] 활성 작업: $(printf '%b' "$active_tasks" | tr '\n' ', ' | sed 's/, $//')${contract_hint}
작업 문서: ${TASK_DIR}/<작업명>/ (plan/progress/context/failures/contract)
완료 시 /done, 작업 종료 시 /begin close"

jq -n --arg ctx "$ctx" '{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": $ctx
  }
}'

exit 0
