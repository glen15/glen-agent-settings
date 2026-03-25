#!/bin/bash
# Stop 훅: 미커밋 변경사항 + 활성 작업 미종료 경고
# 세션 종료 시 git 상태와 /begin 작업 상태를 함께 확인

# 현재 디렉토리에서 git repo 루트 탐색
repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$repo_root" || exit 0

warnings=""

# ── 1. git 변경사항 확인 ──
changed=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
total=$((changed + untracked))

if [ "$total" -gt 0 ]; then
  warnings="${warnings}[훅] 미커밋 변경사항 ${total}개. /done으로 커밋하세요.\n"
fi

# ── 2. 활성 /begin 작업 확인 ──
TASK_DIR=".claude/tasks"
if [ -d "$TASK_DIR" ]; then
  for progress_file in "$TASK_DIR"/*/progress.md; do
    [ ! -f "$progress_file" ] && continue
    status=$(grep -m1 '^## 현재 상태:' "$progress_file" 2>/dev/null | sed 's/^## 현재 상태: *//' || echo "")
    if [ -n "$status" ] && [ "$status" != "완료" ]; then
      task_name=$(basename "$(dirname "$progress_file")")
      if [ "$total" -gt 0 ]; then
        warnings="${warnings}[훅] 작업 '${task_name}' 활성 중 + 미커밋 변경 있음. /done 후 /begin close \"${task_name}\"로 종료하세요.\n"
      else
        warnings="${warnings}[훅] 작업 '${task_name}' 아직 활성 상태. /begin close \"${task_name}\"로 종료하세요.\n"
      fi
    fi
  done
fi

if [ -n "$warnings" ]; then
  printf '%b' "$warnings" >&2
fi
