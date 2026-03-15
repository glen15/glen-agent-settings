#!/bin/bash
# Stop 훅: 미커밋 변경사항 경고
cd /Users/glen/Desktop/work/dxai 2>/dev/null || exit 0

# git 변경사항 확인
changed=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
total=$((changed + untracked))

if [ "$total" -gt 0 ]; then
  echo "[훅] 미커밋 변경사항 ${total}개 감지. 커밋 + nxtflow 태스크 생성을 잊지 마세요." >&2
fi
