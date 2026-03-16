#!/bin/bash
# PostToolUse Hook (Write, Edit) - 자동 테스트 실행
# 소스 파일 수정 후 관련 테스트가 있으면 자동 실행합니다.

set -euo pipefail

input=$(cat)

file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')

# 파일 경로 없으면 패스
if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
  printf '%s' "$input"
  exit 0
fi

# 테스트 파일 자체 수정은 스킵 (무한루프 방지)
if [[ "$file_path" =~ \.(test|spec)\.(ts|tsx|js|jsx)$ ]] || [[ "$file_path" =~ __tests__/ ]]; then
  printf '%s' "$input"
  exit 0
fi

# 지원 확장자만
if [[ ! "$file_path" =~ \.(ts|tsx|js|jsx|py)$ ]]; then
  printf '%s' "$input"
  exit 0
fi

# git repo 루트 기준으로 작업
repo_root=$(git -C "$(dirname "$file_path")" rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$repo_root" ]; then
  printf '%s' "$input"
  exit 0
fi

basename_no_ext=$(basename "$file_path" | sed 's/\.[^.]*$//')
dir=$(dirname "$file_path")

# 관련 테스트 파일 탐색
test_file=""
for ext in test.ts test.tsx spec.ts spec.tsx test.js test.jsx spec.js spec.jsx; do
  # 같은 디렉토리
  candidate="${dir}/${basename_no_ext}.${ext}"
  if [ -f "$candidate" ]; then
    test_file="$candidate"
    break
  fi
  # __tests__/ 하위
  candidate="${dir}/__tests__/${basename_no_ext}.${ext}"
  if [ -f "$candidate" ]; then
    test_file="$candidate"
    break
  fi
done

# Python: test_ 접두사
if [ -z "$test_file" ] && [[ "$file_path" =~ \.py$ ]]; then
  candidate="${dir}/test_${basename_no_ext}.py"
  [ -f "$candidate" ] && test_file="$candidate"
  if [ -z "$test_file" ]; then
    candidate="${dir}/tests/test_${basename_no_ext}.py"
    [ -f "$candidate" ] && test_file="$candidate"
  fi
fi

# 테스트 파일이 없으면 조용히 패스
if [ -z "$test_file" ]; then
  printf '%s' "$input"
  exit 0
fi

# 테스트 러너 감지 및 실행
echo "[훅] 관련 테스트 발견: $(basename "$test_file")" >&2

if [ -f "${repo_root}/package.json" ]; then
  # Node.js 프로젝트
  if [ -f "${repo_root}/node_modules/.bin/vitest" ]; then
    cd "$repo_root" && npx vitest run "$test_file" --reporter=dot 2>&1 | tail -5 >&2
  elif [ -f "${repo_root}/node_modules/.bin/jest" ]; then
    cd "$repo_root" && npx jest "$test_file" --silent 2>&1 | tail -5 >&2
  fi
elif [ -f "${repo_root}/pyproject.toml" ] || [ -f "${repo_root}/setup.py" ]; then
  # Python 프로젝트
  if command -v pytest >/dev/null 2>&1; then
    cd "$repo_root" && pytest "$test_file" -q 2>&1 | tail -5 >&2
  fi
fi

printf '%s' "$input"
