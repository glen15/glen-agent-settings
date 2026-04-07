#!/usr/bin/env bash
# korean-md-bold-check.sh
# PostToolUse hook: Edit/Write/MultiEdit가 .md/.mdx 파일에 적용된 직후
# 한국어 마크다운에서 bold(**...**) 마커가 깨질 위험 패턴을 자동 점검한다.
#
# 깨지는 패턴 (한국어 GFM 환경에서 렌더 실패 사례):
#   1. **bold + "큰따옴표"**           예: **"내가 원하는 결과"**는
#   2. **bold (괄호)** + 한국어 조사   예: **Lab 2 (사건처리)**이
#   3. **bold + 한국어 조사** 직후     예: **민감 자료(개인정보)**는
#
# 안전 패턴:
#   1. "**텍스트**"             (따옴표 밖으로)
#   2. **텍스트** (괄호 설명)    (괄호 밖으로 분리)
#
# Memory: feedback_korean_bold_pattern.md (프로젝트별)
#
# Exit code:
#   0 — 정상 (위험 패턴 없음 또는 .md/.mdx 아님)
#   2 — blocking (위험 패턴 발견, Claude에게 경고 전달)

set -uo pipefail

# stdin에서 JSON 파싱
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# 파일 경로가 비어있거나 .md/.mdx가 아니면 통과
if [[ -z "$FILE" ]]; then
  exit 0
fi
if [[ ! "$FILE" =~ \.(md|mdx)$ ]]; then
  exit 0
fi

# 파일이 존재하지 않으면 통과 (삭제 등)
if [[ ! -f "$FILE" ]]; then
  exit 0
fi

# 위험 패턴 검사
# - fenced code block (``` ... ```) 내부는 제외
# - 각 라인의 inline code (`...`) 부분도 제거 후 검사
# - 라인 번호는 보존
CLEANED=$(awk '
  BEGIN { in_block = 0 }
  /^```/ { in_block = !in_block; next }
  !in_block {
    line = $0
    # inline code 제거 (가장 짧은 매칭 우선)
    while (match(line, /`[^`]*`/)) {
      line = substr(line, 1, RSTART-1) substr(line, RSTART+RLENGTH)
    }
    print NR ":" line
  }
' "$FILE")

ISSUES=""

# 패턴 1: bold + 직접 인접한 큰따옴표 (**"..."** 또는 양쪽이 인접)
P1=$(echo "$CLEANED" | grep -E '\*\*"[^"]+"\*\*|\*\*[^*]+"\*\*[가-힣]|[가-힣]\*\*"[^*]+\*\*' 2>/dev/null || true)
if [[ -n "$P1" ]]; then
  ISSUES+=$'\n[패턴 1: bold + 따옴표 인접 — 깨질 수 있음]\n'
  ISSUES+="$P1"$'\n'
fi

# 패턴 2: bold 안에 괄호 + bold 직후 한국어 조사
P2=$(echo "$CLEANED" | grep -E '\*\*[^*]*\([^)]*\)\*\*[가-힣]' 2>/dev/null || true)
if [[ -n "$P2" ]]; then
  ISSUES+=$'\n[패턴 2: bold 안 괄호 + 직후 한국어 조사 — 깨질 수 있음]\n'
  ISSUES+="$P2"$'\n'
fi

# 패턴이 없으면 정상 종료
if [[ -z "$ISSUES" ]]; then
  exit 0
fi

# 위험 패턴 발견 — stderr로 경고 출력 후 exit 2 (Claude에게 전달)
{
  echo ""
  echo "⚠️  한국어 마크다운 bold 패턴 위험 발견 — $FILE"
  echo "$ISSUES"
  echo "수정 가이드:"
  echo "  - 따옴표는 bold 밖으로:  **\"텍스트\"** → \"**텍스트**\""
  echo "  - 괄호는 bold 밖으로:    **이름(설명)**조사 → **이름** (설명)조사"
  echo "  - 자세한 패턴: ~/.claude/projects/*/memory/feedback_korean_bold_pattern.md"
  echo ""
  echo "위 라인을 수정한 뒤 다음 단계로 진행하세요."
} >&2

exit 2
