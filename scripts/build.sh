#!/bin/bash
# glen-agent-settings — 빌드 스크립트
# src/ + overlays/ → dist/claude/, dist/codex/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="${ROOT_DIR}/src"
DIST_DIR="${ROOT_DIR}/dist"

echo "=== glen-agent-settings 빌드 ==="

# ── dist 초기화 ──
rm -rf "${DIST_DIR}/claude" "${DIST_DIR}/codex"
mkdir -p "${DIST_DIR}/claude/skills" "${DIST_DIR}/claude/hooks/refine" "${DIST_DIR}/claude/ralph-loop" \
         "${DIST_DIR}/claude/agents" "${DIST_DIR}/claude/commands"
mkdir -p "${DIST_DIR}/codex/skills" "${DIST_DIR}/codex/ralph-loop"

# ── 1. 스킬 복사 (양쪽 공통) ──
echo "[1/7] 스킬 빌드..."
for skill_dir in "${SRC_DIR}/skills/"*/; do
  skill_name=$(basename "$skill_dir")
  # Claude: 그대로 복사
  cp -r "$skill_dir" "${DIST_DIR}/claude/skills/${skill_name}"

  # Codex: SKILL.md → AGENTS.md 변환 (frontmatter 제거)
  mkdir -p "${DIST_DIR}/codex/skills/${skill_name}"
  if [ -f "${skill_dir}/SKILL.md" ]; then
    # frontmatter 제거 (--- ... --- 블록)
    awk 'BEGIN{in_fm=0; found=0}
      /^---$/ && !found {in_fm=!in_fm; if(!in_fm) found=1; next}
      !in_fm {print}' "${skill_dir}/SKILL.md" > "${DIST_DIR}/codex/skills/${skill_name}/AGENTS.md"
  fi
  # 스크립트/데이터 파일도 복사
  find "$skill_dir" -not -name "SKILL.md" -not -path "$skill_dir" -maxdepth 0 -exec cp -r {} "${DIST_DIR}/codex/skills/${skill_name}/" \; 2>/dev/null || true
  for sub in scripts data; do
    if [ -d "${skill_dir}/${sub}" ]; then
      cp -r "${skill_dir}/${sub}" "${DIST_DIR}/codex/skills/${skill_name}/"
    fi
  done
done
echo "  → claude: $(ls "${DIST_DIR}/claude/skills/" | wc -l | tr -d ' ') 스킬"
echo "  → codex: $(ls "${DIST_DIR}/codex/skills/" | wc -l | tr -d ' ') 스킬"

# ── 2. Hooks (Claude 전용) ──
echo "[2/7] Hooks 빌드..."
cp "${SRC_DIR}/hooks/root/"*.sh "${DIST_DIR}/claude/hooks/" 2>/dev/null || true
cp "${SRC_DIR}/hooks/refine/"* "${DIST_DIR}/claude/hooks/refine/"
chmod +x "${DIST_DIR}/claude/hooks/"*.sh 2>/dev/null || true
chmod +x "${DIST_DIR}/claude/hooks/refine/"*.sh 2>/dev/null || true
echo "  → claude: root $(ls "${DIST_DIR}/claude/hooks/"*.sh 2>/dev/null | wc -l | tr -d ' ') + refine $(ls "${DIST_DIR}/claude/hooks/refine/" | wc -l | tr -d ' ')"
echo "  → codex: hooks 없음 (Codex는 Starlark Rules 사용)"

# ── 3. Ralph Loop ──
echo "[3/7] Ralph Loop 빌드..."
cp -r "${SRC_DIR}/ralph-loop/"* "${DIST_DIR}/claude/ralph-loop/"
cp -r "${SRC_DIR}/ralph-loop/"* "${DIST_DIR}/codex/ralph-loop/"
chmod +x "${DIST_DIR}/claude/ralph-loop/ralph-loop.sh" "${DIST_DIR}/claude/ralph-loop/lib/"*.sh "${DIST_DIR}/claude/ralph-loop/adapters/"*.sh
chmod +x "${DIST_DIR}/codex/ralph-loop/ralph-loop.sh" "${DIST_DIR}/codex/ralph-loop/lib/"*.sh "${DIST_DIR}/codex/ralph-loop/adapters/"*.sh
echo "  → 양쪽 배포 (claude/codex 어댑터 포함)"

# ── 4. Agents + Commands (Claude 전용) ──
echo "[4/7] Agents 빌드..."
if [ -d "${SRC_DIR}/agents" ]; then
  cp "${SRC_DIR}/agents/"*.md "${DIST_DIR}/claude/agents/"
  echo "  → claude: $(ls "${DIST_DIR}/claude/agents/" | wc -l | tr -d ' ') 에이전트"
fi

echo "[5/7] Commands 빌드..."
if [ -d "${SRC_DIR}/commands" ]; then
  cp "${SRC_DIR}/commands/"*.md "${DIST_DIR}/claude/commands/"
  echo "  → claude: $(ls "${DIST_DIR}/claude/commands/" | wc -l | tr -d ' ') 커맨드"
fi

# ── 5. 가이드 문서 ──
echo "[6/7] 가이드 빌드..."
cp "${SRC_DIR}/guides/CLAUDE.md" "${DIST_DIR}/claude/CLAUDE.md"
cp "${SRC_DIR}/guides/harness.md" "${DIST_DIR}/claude/skills/harness.md"
# Codex: CLAUDE.md → AGENTS.md 변환
cp "${SRC_DIR}/guides/CLAUDE.md" "${DIST_DIR}/codex/AGENTS.md"
echo "  → claude: CLAUDE.md + harness.md"
echo "  → codex: AGENTS.md"

# ── 6. 설정 파일 ──
echo "[7/7] 설정 파일 빌드..."
# __CLAUDE_HOME__ 플레이스홀더를 실제 경로로 치환
sed "s|__CLAUDE_HOME__|${HOME}/.claude|g" "${SRC_DIR}/settings.json" > "${DIST_DIR}/claude/settings.json"

# Codex config.toml 생성
cat > "${DIST_DIR}/codex/config.toml" << 'TOML'
# glen-agent-settings — Codex CLI config
model = "o4-mini"
approval_mode = "auto-edit"

[history]
persistence = "per_directory"
max_entries = 500

[instructions]
auto_read_agents_md = true
TOML
echo "  → claude: settings.json"
echo "  → codex: config.toml"

echo ""
echo "=== 빌드 완료 ==="
echo "  dist/claude/ — $(find "${DIST_DIR}/claude" -type f | wc -l | tr -d ' ') 파일"
echo "  dist/codex/  — $(find "${DIST_DIR}/codex" -type f | wc -l | tr -d ' ') 파일"
