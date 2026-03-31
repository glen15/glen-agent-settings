#!/bin/bash
# 플러그인 자동 설치 — src/plugins.json 기반
# 사용법: bash scripts/install-plugins.sh [--dry-run]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${SCRIPT_DIR}/../src/plugins.json"
DRY_RUN=false

[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

if ! command -v jq &>/dev/null; then
  echo "오류: jq가 필요합니다 (brew install jq)" >&2
  exit 1
fi

if [ ! -f "$MANIFEST" ]; then
  echo "오류: ${MANIFEST} 없음" >&2
  exit 1
fi

# 현재 설치된 플러그인 목록
INSTALLED_FILE="$HOME/.claude/plugins/installed_plugins.json"
installed_ids=""
if [ -f "$INSTALLED_FILE" ]; then
  installed_ids=$(jq -r '.plugins | keys[]' "$INSTALLED_FILE" 2>/dev/null || true)
fi

echo "=== 플러그인 설치 (src/plugins.json) ==="
echo ""

# 1단계: 마켓플레이스 등록
echo "── 마켓플레이스 등록 ──"
marketplace_count=$(jq '.marketplaces | length' "$MANIFEST")
for i in $(seq 0 $((marketplace_count - 1))); do
  name=$(jq -r ".marketplaces[$i].name" "$MANIFEST")
  repo=$(jq -r ".marketplaces[$i].repo" "$MANIFEST")

  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY] /plugin marketplace add ${repo}"
  else
    echo "  마켓플레이스: ${name} (${repo})"
    claude -p "/plugin marketplace add ${repo}" 2>/dev/null || true
  fi
done
echo ""

# 2단계: 플러그인 설치 (미설치 항목만)
echo "── 플러그인 설치 ──"
plugin_count=$(jq '.plugins | length' "$MANIFEST")
skipped=0
installed=0

for i in $(seq 0 $((plugin_count - 1))); do
  id=$(jq -r ".plugins[$i].id" "$MANIFEST")
  desc=$(jq -r ".plugins[$i].description" "$MANIFEST")

  if echo "$installed_ids" | grep -q "^${id}$"; then
    echo "  [SKIP] ${id} — 이미 설치됨"
    ((skipped++))
    continue
  fi

  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY] /plugin install ${id} — ${desc}"
  else
    echo "  [설치] ${id} — ${desc}"
    claude -p "/plugin install ${id}" 2>/dev/null || echo "    ⚠ 설치 실패: ${id}"
    ((installed++))
  fi
done

echo ""
echo "=== 완료: ${installed}개 설치, ${skipped}개 건너뜀 ==="
if [ "$DRY_RUN" = true ]; then
  echo "(DRY RUN — 실제 변경 없음)"
fi
