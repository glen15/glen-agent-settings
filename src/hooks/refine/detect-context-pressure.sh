#!/bin/bash
# Refine Loop - Context 압력 감지
# claw-code compact.rs 패턴 포팅: 토큰 추정 + pending work + 참조 파일 추출
#
# 사용법: detect-context-pressure.sh <transcript_path> <iteration>
# 출력 JSON:
#   estimated_tokens: 추정 토큰 수
#   pressure_level: "low" | "medium" | "high"
#   pending_work: ["..."] (최대 3개)
#   key_files: ["..."] (최대 8개)
#   warning: "" | 경고 메시지

set -euo pipefail

TRANSCRIPT_PATH="${1:-}"
ITERATION="${2:-1}"

# ── 임계값 ──
# CC의 auto-compaction은 200K에서 트리거
# 우리는 그보다 일찍 경고해야 함 (경고만, 종료 아님)
THRESHOLD_MEDIUM=120000   # 120K tokens → "medium" (HUD 표시)
THRESHOLD_HIGH=180000     # 180K tokens → "high" (경고 메시지 주입)

# ── 기본 출력 ──
output_json() {
  local tokens="${1:-0}"
  local level="${2:-low}"
  local warning="${3:-}"
  local pending_json="${4:-[]}"
  local files_json="${5:-[]}"

  jq -n \
    --argjson tokens "$tokens" \
    --arg level "$level" \
    --arg warning "$warning" \
    --argjson pending "$pending_json" \
    --argjson files "$files_json" \
    '{
      estimated_tokens: $tokens,
      pressure_level: $level,
      pending_work: $pending,
      key_files: $files,
      warning: $warning
    }'
}

# transcript 없으면 low 반환
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  output_json 0 "low"
  exit 0
fi

# ── 1) 토큰 추정 (compact.rs: text.len() / 4 + 1) ──
file_bytes=$(wc -c < "$TRANSCRIPT_PATH" 2>/dev/null || echo "0")
estimated_tokens=$(( file_bytes / 4 ))

# ── 2) Pending work 키워드 스캔 ──
# compact.rs: todo, next, pending, follow up, remaining
# assistant 메시지의 텍스트에서 최근 3개 매칭
pending_json="[]"
if [ "$estimated_tokens" -ge "$THRESHOLD_MEDIUM" ]; then
  pending_lines=$(grep '"role"[: ]*"assistant"' "$TRANSCRIPT_PATH" 2>/dev/null \
    | tail -10 \
    | jq -r '.message.content[]? | select(.type == "text") | .text' 2>/dev/null \
    | grep -iE '(todo|next|pending|follow.?up|remaining|남은|다음|해야)' \
    | tail -3 \
    | head -c 500 \
    || echo "")

  if [ -n "$pending_lines" ]; then
    pending_json=$(printf '%s' "$pending_lines" \
      | jq -R -s 'split("\n") | map(select(length > 0)) | map(.[0:160]) | .[0:3]' 2>/dev/null \
      || echo "[]")
  fi
fi

# ── 3) 참조 파일 경로 추출 ──
# compact.rs: 슬래시 포함 + 알려진 확장자 (.rs/.ts/.tsx/.js/.json/.md/.py/.sh)
files_json="[]"
if [ "$estimated_tokens" -ge "$THRESHOLD_MEDIUM" ]; then
  file_candidates=$(grep '"role"[: ]*"assistant"' "$TRANSCRIPT_PATH" 2>/dev/null \
    | tail -20 \
    | jq -r '.message.content[]? | select(.type == "text") | .text' 2>/dev/null \
    | grep -oE '[A-Za-z0-9_./-]+\.(rs|ts|tsx|js|json|md|py|sh|css|html|yaml|yml)' \
    | grep '/' \
    | sort -u \
    | head -8 \
    || echo "")

  if [ -n "$file_candidates" ]; then
    files_json=$(printf '%s' "$file_candidates" \
      | jq -R -s 'split("\n") | map(select(length > 0)) | .[0:8]' 2>/dev/null \
      || echo "[]")
  fi
fi

# ── 4) 압력 수준 판정 ──
level="low"
warning=""

if [ "$estimated_tokens" -ge "$THRESHOLD_HIGH" ]; then
  level="high"
  warning="Context 압력 HIGH (${estimated_tokens}tok ≥ ${THRESHOLD_HIGH}). iteration ${ITERATION}에서 context reset을 권장합니다. progress.md에 현재 상태를 기록하고 새 세션에서 이어가세요."
elif [ "$estimated_tokens" -ge "$THRESHOLD_MEDIUM" ]; then
  level="medium"
  warning="Context 압력 MEDIUM (${estimated_tokens}tok). 남은 iteration에서 context 품질 저하에 주의하세요."
fi

output_json "$estimated_tokens" "$level" "$warning" "$pending_json" "$files_json"
