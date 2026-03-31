#!/bin/bash
# PostToolUse / PostToolUseFailure Hook — 하네스 도구 사용 추적
# 모든 도구 호출을 SQLite에 기록. 실패 시 조용히 무시.
set -euo pipefail

input=$(cat)

DB_PATH="${HOME}/.claude/harness-usage.db"

# DB 없으면 초기화
if [ ! -f "$DB_PATH" ]; then
  INIT_SCRIPT="${HOME}/.claude/skills/harness-stats/scripts/init-db.sh"
  if [ -f "$INIT_SCRIPT" ]; then
    bash "$INIT_SCRIPT" 2>/dev/null || true
  fi
  if [ ! -f "$DB_PATH" ]; then
    printf '%s' "$input"
    exit 0
  fi
fi

# 도구 정보 추출
tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
if [ -z "$tool_name" ]; then
  printf '%s' "$input"
  exit 0
fi

# ── 카테고리 + 디테일 + 서브카테고리 분류 ──
category=""
detail=""
subcategory=""
file_path=""

# CLI 서브카테고리 분류 함수
classify_cli() {
  local first_word="$1"
  case "$first_word" in
    git|git-*)          echo "git" ;;
    gh|gh-*)            echo "github-cli" ;;
    gws|gws-*)          echo "gws-cli" ;;
    aws|aws-*)          echo "aws-cli" ;;
    npm|npx|bun|yarn|pnpm) echo "package-mgr" ;;
    node|tsx|python|python3|ruby|deno) echo "runtime" ;;
    curl|wget|httpie)   echo "http" ;;
    ssh|scp|rsync)      echo "remote" ;;
    docker|docker-*)    echo "docker" ;;
    terraform|tf)       echo "terraform" ;;
    sqlite3)            echo "database" ;;
    brew|apt|yum)       echo "sys-package" ;;
    ls|find|cat|head|tail|wc|mkdir|rm|cp|mv|chmod|ln|touch|tree|du|file|diff|sort|uniq|xargs|dirname|basename|realpath|stat|tar|zip|unzip) echo "filesystem" ;;
    echo|printf|heredoc|sed|awk|tr|cut|jq|grep|tee|rg) echo "text-processing" ;;
    cd|pwd|which|type|env|export|source|sleep|wait|kill|pkill|ps|lsof|open|pbcopy|test) echo "shell-builtin" ;;
    bash|sh|zsh)        echo "shell-script" ;;
    browser-use)        echo "browser" ;;
    swift|swiftc|xcodebuild) echo "swift" ;;
    go)                 echo "go" ;;
    *)                  echo "other" ;;
  esac
}

case "$tool_name" in
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
    if printf '%s' "$cmd" | grep -q '\.claude/skills/' 2>/dev/null; then
      category="skill_script"
      detail=$(printf '%s' "$cmd" | grep -oE 'skills/[^/]+' | head -1 | sed 's|skills/||')
    else
      category="cli"
      # 첫 단어 추출 (주석/변수선언/for 등 쉘 구문 무시)
      first_word=$(printf '%s' "$cmd" | sed 's/^[[:space:]]*//' | sed 's/^#.*//' | sed 's/^[A-Z_]*=.*//' | awk '{print $1}' | head -c 30)
      # git add → "git add", npm install → "npm install"
      second_word=$(printf '%s' "$cmd" | sed 's/^[[:space:]]*//' | awk '{print $2}' | head -c 20)
      case "$first_word" in
        git|gh|aws|gws|docker)
          detail="${first_word} ${second_word}"
          ;;
        *)
          detail="$first_word"
          ;;
      esac
      subcategory=$(classify_cli "$first_word")
    fi
    ;;
  Write)
    category="file_write"
    file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
    detail=$(printf '%s' "$file_path" | grep -oE '\.[^.]+$' || echo "unknown")
    ;;
  Edit)
    category="file_edit"
    file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
    detail=$(printf '%s' "$file_path" | grep -oE '\.[^.]+$' || echo "unknown")
    ;;
  Read)
    category="file_read"
    file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
    detail=$(printf '%s' "$file_path" | grep -oE '\.[^.]+$' || echo "unknown")
    ;;
  Glob|Grep)
    category="search"
    detail=$(printf '%s' "$input" | jq -r '.tool_input.pattern // ""' 2>/dev/null | head -c 50)
    ;;
  Agent)
    category="agent"
    detail=$(printf '%s' "$input" | jq -r '.tool_input.description // ""' 2>/dev/null | head -c 50)
    ;;
  Skill)
    category="skill"
    detail=$(printf '%s' "$input" | jq -r '.tool_input.skill // "unknown"' 2>/dev/null || echo "unknown")
    ;;
  mcp__*)
    category="mcp"
    detail=$(printf '%s' "$tool_name" | sed 's/^mcp__//')
    ;;
  *)
    category="other"
    detail="$tool_name"
    ;;
esac

# ── 프로젝트 디렉토리 + 세션 ID ──
project_dir=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
session_id="${CLAUDE_SESSION_ID:-}"

# ── 성공 여부 판별 (tool_response 필드 사용) ──
hook_event=$(printf '%s' "$input" | jq -r '.hook_event_name // ""' 2>/dev/null || echo "")
success=1

if [ "$hook_event" = "PostToolUseFailure" ]; then
  # PostToolUseFailure 이벤트는 무조건 실패
  success=0
else
  # Bash: exit_code 확인
  if [ "$tool_name" = "Bash" ]; then
    exit_code=$(printf '%s' "$input" | jq -r '.tool_response.exit_code // 0' 2>/dev/null || echo "0")
    if [ "$exit_code" != "0" ] && [ "$exit_code" != "null" ]; then
      success=0
    fi
  fi
  # 공통: tool_response.stderr에 에러 키워드 확인
  stderr=$(printf '%s' "$input" | jq -r '.tool_response.stderr // ""' 2>/dev/null || echo "")
  if [ -n "$stderr" ] && printf '%s' "$stderr" | grep -qiE '(error|failed|fatal|ENOENT|EPERM|exception)' 2>/dev/null; then
    success=0
  fi
  # Write/Edit/Read: success 필드 확인
  tool_success=$(printf '%s' "$input" | jq -r '.tool_response.success // ""' 2>/dev/null || echo "")
  if [ "$tool_success" = "false" ]; then
    success=0
  fi
fi

# ── SQL 이스케이프 ──
esc() { printf '%s' "$1" | sed "s/'/''/g"; }

# ── 백그라운드 INSERT (차단 방지) ──
(sqlite3 "$DB_PATH" \
  "INSERT INTO tool_usage (session_id, project_dir, tool_name, tool_category, detail, file_path, success)
   VALUES ('$(esc "$session_id")', '$(esc "$project_dir")', '$(esc "$tool_name")', '$(esc "$category")', '$(esc "${subcategory:+${subcategory}:}${detail}")', '$(esc "$file_path")', ${success});" \
  2>/dev/null || true) &

printf '%s' "$input"
