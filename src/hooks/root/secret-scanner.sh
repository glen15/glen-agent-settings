#!/bin/bash
# PreToolUse Hook (Write, Edit) - 시크릿 스캐너
# 파일에 하드코딩된 시크릿이 포함되면 차단합니다.

set -euo pipefail

input=$(cat)

# Write: content 필드, Edit: new_string 필드
content=$(printf '%s' "$input" | jq -r '.tool_input.content // .tool_input.new_string // ""')

if [ -z "$content" ]; then
  printf '%s' "$input"
  exit 0
fi

file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')

# .env, .envrc 등 환경변수 파일은 예외 (시크릿이 있어야 정상)
if [[ "$file_path" =~ \.(env|envrc|env\..*)$ ]]; then
  printf '%s' "$input"
  exit 0
fi

# 시크릿 패턴 목록
patterns=(
  # AWS
  'AKIA[0-9A-Z]{16}'
  # GitHub token
  'gh[pousr]_[A-Za-z0-9_]{36,}'
  # Generic private key
  '-----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----'
  # JWT (긴 base64 토큰)
  'eyJ[A-Za-z0-9_-]{20,}\.eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}'
  # Slack token
  'xox[bpras]-[0-9a-zA-Z-]{10,}'
  # Database URL with password
  '(postgres|mysql|mongodb)://[^:]+:[^@]{8,}@'
  # Anthropic API key
  'sk-ant-[A-Za-z0-9_-]{20,}'
  # OpenAI API key
  'sk-[A-Za-z0-9]{20,}T3BlbkFJ[A-Za-z0-9]{20,}'
  # Generic secret assignment (password = "...", secret = "...", api_key = "...")
  '(password|secret|api_key|apikey|api_secret|access_token)\s*[:=]\s*["\x27][A-Za-z0-9+/=_-]{16,}["\x27]'
)

for pattern in "${patterns[@]}"; do
  if printf '%s' "$content" | grep -qEi "$pattern"; then
    echo "[훅] 차단: 시크릿 패턴 감지 — $file_path" >&2
    echo "[훅] 환경변수를 사용하세요 (process.env.*, os.environ 등)" >&2
    exit 2
  fi
done

printf '%s' "$input"
