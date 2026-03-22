#!/bin/bash
# Stop 훅: 미커밋 변경사항 경고
# 세션 종료 시 현재 git repo에 미커밋 변경이 있으면 알림

# 현재 디렉토리에서 git repo 루트 탐색
repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$repo_root" || exit 0

# git 변경사항 확인
changed=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
total=$((changed + untracked))

if [ "$total" -gt 0 ]; then
  echo "[훅] 미커밋 변경사항 ${total}개 감지. /done으로 커밋하세요." >&2
fi
