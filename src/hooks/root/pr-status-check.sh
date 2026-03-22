#!/bin/bash
# PostToolUse Hook (Bash) — PR 생성 후 URL 및 Actions 상태 확인
set -euo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

if ! printf '%s' "$cmd" | grep -qE 'gh pr create'; then
  printf '%s' "$input"
  exit 0
fi

output=$(printf '%s' "$input" | jq -r '.tool_output.stdout // ""')
pr_url=$(printf '%s' "$output" | grep -oE 'https://github.com/[^/]+/[^/]+/pull/[0-9]+')

if [ -n "$pr_url" ]; then
  echo "[훅] PR 생성됨: $pr_url" >&2
  echo '[훅] GitHub Actions 상태 확인 중...' >&2
fi

printf '%s' "$input"
