#!/bin/bash
# Stop Hook - console.log 경고
# 세션 종료 시 수정된 파일에 console.log가 있으면 경고합니다.

input=$(cat)

if git rev-parse --git-dir > /dev/null 2>&1; then
  modified_files=$(git diff --name-only HEAD 2>/dev/null | grep -E '\.(ts|tsx|js|jsx)$' || true)

  if [ -n "$modified_files" ]; then
    has_console=false
    while IFS= read -r file; do
      if [ -f "$file" ]; then
        if grep -q "console\.log" "$file" 2>/dev/null; then
          echo "[훅] 경고: console.log 발견 - $file" >&2
          has_console=true
        fi
      fi
    done <<< "$modified_files"

    if [ "$has_console" = true ]; then
      echo '[훅] 커밋 전 console.log를 제거하세요' >&2
    fi
  fi
fi

printf '%s' "$input"
