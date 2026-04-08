#!/usr/bin/env bash
# sync-presets.sh — VoltAgent/awesome-design-md 프리셋 싱크
#
# 업스트림의 design-md/<brand>/DESIGN.md를 resources/presets/<brand>.md로
# 동기화한다. 각 파일에 라이선스 헤더 주입, 제목 정규화, 프로프라이어터리
# 폰트를 자유 폰트로 치환한다.
#
# Usage:
#   ./scripts/sync-presets.sh            # 전체 싱크
#   ./scripts/sync-presets.sh --dry-run  # 다운로드만, 쓰기 안 함
#
# Requirements: gh CLI, sed, tar

set -euo pipefail

REPO="VoltAgent/awesome-design-md"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
PRESET_DIR="$SKILL_DIR/resources/presets"
FONT_MAP="$SCRIPT_DIR/font-substitutions.tsv"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "=== Preset sync from $REPO ==="

# 1) Download tarball
echo "[1/5] Downloading upstream tarball..."
gh api "repos/$REPO/tarball" > "$TMPDIR/upstream.tar.gz"
tar xzf "$TMPDIR/upstream.tar.gz" -C "$TMPDIR"
UPSTREAM_BASE=$(find "$TMPDIR" -maxdepth 3 -type d -name "design-md" | head -1)
[ -n "$UPSTREAM_BASE" ] || { echo "ERROR: design-md/ not found in tarball"; exit 1; }
echo "      upstream base: $UPSTREAM_BASE"

# 2) Build sed substitution script from TSV
echo "[2/5] Building substitution script..."
SED_SCRIPT="$TMPDIR/substitutions.sed"

# Title normalization: "# Design System Inspiration of X" -> "# Design System: X"
cat > "$SED_SCRIPT" <<'EOF'
s|^# Design System Inspiration of \(.*\)$|# Design System: \1|
s|^# Design System of \(.*\)$|# Design System: \1|
EOF

# Font substitutions from TSV (skip comments and blanks)
# Pipe delimiter `|` so forward slashes and backticks don't need escaping
grep -v '^\s*#' "$FONT_MAP" | grep -v '^\s*$' | while IFS=$'\t' read -r from to; do
  [ -z "$from" ] && continue
  # Escape pipes and backslashes in from/to
  from_esc=$(printf '%s' "$from" | sed 's/[|\\]/\\&/g')
  to_esc=$(printf '%s' "$to" | sed 's/[|\\]/\\&/g')
  echo "s|${from_esc}|${to_esc}|g" >> "$SED_SCRIPT"
done

rule_count=$(wc -l < "$SED_SCRIPT" | tr -d ' ')
echo "      $rule_count sed rules loaded"

# 3) Process each brand directory
if [ "$DRY_RUN" = 1 ]; then
  echo "[3/5] DRY RUN — listing brands only:"
  ls "$UPSTREAM_BASE" | sort
  exit 0
fi

echo "[3/5] Processing presets..."
mkdir -p "$PRESET_DIR"

count=0
skipped=0
for brand_dir in "$UPSTREAM_BASE"/*/; do
  brand=$(basename "$brand_dir")
  src="$brand_dir/DESIGN.md"

  if [ ! -f "$src" ]; then
    skipped=$((skipped+1))
    continue
  fi

  # Normalize filename: strip .app / .ai / .com suffixes
  out_name="${brand%%.*}"
  out_file="$PRESET_DIR/$out_name.md"

  # Compose output: header + normalized body
  {
    echo "<!-- Source: VoltAgent/awesome-design-md (MIT License) -->"
    echo "<!-- Synced by: src/skills/glen-design/scripts/sync-presets.sh -->"
    echo "<!-- Font substitutions: see scripts/font-substitutions.tsv -->"
    echo ""
    sed -f "$SED_SCRIPT" "$src"
  } > "$out_file"

  count=$((count+1))
done

echo "      $count presets written, $skipped skipped"

# 4) LICENSE file
echo "[4/5] Ensuring LICENSE file..."
if [ ! -f "$PRESET_DIR/LICENSE" ]; then
  cat > "$PRESET_DIR/LICENSE" <<'EOF'
Preset DESIGN.md files in this directory are derived from:

  Source: https://github.com/VoltAgent/awesome-design-md
  License: MIT License
  Copyright (c) VoltAgent

Modifications applied:
  - Licensed/proprietary fonts replaced with free alternatives
  - Format standardized to 9-section output format

The MIT License permits use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, subject to the condition
that the above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.
EOF
fi

# 5) Summary
echo "[5/5] Summary:"
ls "$PRESET_DIR"/*.md 2>/dev/null | wc -l | xargs -I{} echo "      total presets: {}"
echo ""
echo "Done. Run the following to verify:"
echo "  grep -l 'Airbnb Cereal\\|sohne\\|Anthropic Serif' $PRESET_DIR/*.md"
echo "  (should return nothing if substitutions are complete)"
