#!/bin/bash
# glen-agent-settings — 배포 스크립트
# dist/ → ~/.claude/ 및 ~/.codex/
#
# 사용법:
#   ./deploy.sh              # 양쪽 배포
#   ./deploy.sh --claude     # Claude만
#   ./deploy.sh --codex      # Codex만
#   ./deploy.sh --dry-run    # 실제 복사 없이 확인만
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${SCRIPT_DIR}/dist"
CLAUDE_DIR="$HOME/.claude"
CODEX_DIR="$HOME/.codex"
BACKUP_DIR="$HOME/.claude/backups/$(date +%Y%m%d-%H%M%S)"

DEPLOY_CLAUDE=true
DEPLOY_CODEX=true
DRY_RUN=false

# ── 인자 파싱 ──
while [ $# -gt 0 ]; do
  case "$1" in
    --claude)   DEPLOY_CODEX=false; shift ;;
    --codex)    DEPLOY_CLAUDE=false; shift ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --help)     sed -n '2,8p' "$0" | sed 's/^# //'; exit 0 ;;
    *)          echo "알 수 없는 옵션: $1" >&2; exit 1 ;;
  esac
done

# 빌드 먼저 실행
echo "=== 빌드 실행 ==="
bash "${SCRIPT_DIR}/scripts/build.sh"
echo ""

echo "=== glen-agent-settings 배포 ==="

# ── 유틸리티 ──
do_copy() {
  local src="$1" dst="$2"
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY] $src → $dst"
  else
    cp -r "$src" "$dst"
  fi
}

# ── Claude Code 배포 ──
if [ "$DEPLOY_CLAUDE" = true ]; then
  echo ""
  echo "── Claude Code (~/.claude/) ──"

  if [ ! -d "${DIST_DIR}/claude" ]; then
    echo "오류: dist/claude/ 없음. build.sh를 먼저 실행하세요." >&2
    exit 1
  fi

  # 백업
  if [ "$DRY_RUN" = false ]; then
    mkdir -p "$BACKUP_DIR"
    for target in skills hooks ralph-loop; do
      if [ -d "${CLAUDE_DIR}/${target}" ]; then
        cp -r "${CLAUDE_DIR}/${target}" "${BACKUP_DIR}/${target}" 2>/dev/null || true
      fi
    done
    echo "  백업 → ${BACKUP_DIR}"
  fi

  # 스킬 배포
  echo "  [1/5] 스킬..."
  for skill_dir in "${DIST_DIR}/claude/skills/"*/; do
    skill_name=$(basename "$skill_dir")
    mkdir -p "${CLAUDE_DIR}/skills/${skill_name}"
    do_copy "$skill_dir" "${CLAUDE_DIR}/skills/${skill_name}/.."
  done
  # harness.md
  do_copy "${DIST_DIR}/claude/skills/harness.md" "${CLAUDE_DIR}/skills/harness.md" 2>/dev/null || true

  # Hooks 배포
  echo "  [2/5] Hooks..."
  for hook_file in "${DIST_DIR}/claude/hooks/"*.sh; do
    [ -f "$hook_file" ] && do_copy "$hook_file" "${CLAUDE_DIR}/hooks/$(basename "$hook_file")"
  done
  mkdir -p "${CLAUDE_DIR}/hooks/refine"
  for f in "${DIST_DIR}/claude/hooks/refine/"*; do
    [ -f "$f" ] && do_copy "$f" "${CLAUDE_DIR}/hooks/refine/$(basename "$f")"
  done

  # Ralph Loop 배포
  echo "  [3/5] Ralph Loop..."
  mkdir -p "${CLAUDE_DIR}/ralph-loop/lib" "${CLAUDE_DIR}/ralph-loop/adapters" \
           "${CLAUDE_DIR}/ralph-loop/prompts" "${CLAUDE_DIR}/ralph-loop/templates"
  do_copy "${DIST_DIR}/claude/ralph-loop/ralph-loop.sh" "${CLAUDE_DIR}/ralph-loop/ralph-loop.sh"
  for f in "${DIST_DIR}/claude/ralph-loop/lib/"*.sh; do
    do_copy "$f" "${CLAUDE_DIR}/ralph-loop/lib/$(basename "$f")"
  done
  for f in "${DIST_DIR}/claude/ralph-loop/adapters/"*.sh; do
    do_copy "$f" "${CLAUDE_DIR}/ralph-loop/adapters/$(basename "$f")"
  done
  for f in "${DIST_DIR}/claude/ralph-loop/prompts/"*; do
    do_copy "$f" "${CLAUDE_DIR}/ralph-loop/prompts/$(basename "$f")"
  done
  for f in "${DIST_DIR}/claude/ralph-loop/templates/"*; do
    do_copy "$f" "${CLAUDE_DIR}/ralph-loop/templates/$(basename "$f")"
  done
  # ~/bin 심볼릭 링크
  if [ "$DRY_RUN" = false ]; then
    mkdir -p "$HOME/bin"
    ln -sf "${CLAUDE_DIR}/ralph-loop/ralph-loop.sh" "$HOME/bin/ralph-loop"
    echo "  → ~/bin/ralph-loop (심볼릭 링크)"
  fi

  # CLAUDE.md 배포
  echo "  [4/5] CLAUDE.md..."
  do_copy "${DIST_DIR}/claude/CLAUDE.md" "${CLAUDE_DIR}/CLAUDE.md"

  # settings.json 병합 (기존 설정 보존하며 업데이트)
  echo "  [5/5] settings.json..."
  if [ "$DRY_RUN" = false ] && [ -f "${CLAUDE_DIR}/settings.json" ]; then
    # 기존 settings.json 백업
    cp "${CLAUDE_DIR}/settings.json" "${BACKUP_DIR}/settings.json"
    # 새 settings.json의 hooks와 env만 업데이트 (deep merge)
    jq -s '.[0] * .[1]' "${CLAUDE_DIR}/settings.json" "${DIST_DIR}/claude/settings.json" \
      > "${CLAUDE_DIR}/settings.json.tmp" && mv "${CLAUDE_DIR}/settings.json.tmp" "${CLAUDE_DIR}/settings.json"
    echo "  → settings.json 병합 완료 (기존 설정 보존)"
  elif [ "$DRY_RUN" = true ]; then
    echo "  [DRY] settings.json 병합 예정"
  fi

  echo "  ✓ Claude Code 배포 완료"
fi

# ── Codex CLI 배포 ──
if [ "$DEPLOY_CODEX" = true ]; then
  echo ""
  echo "── Codex CLI (~/.codex/) ──"

  if [ ! -d "${DIST_DIR}/codex" ]; then
    echo "오류: dist/codex/ 없음" >&2
    exit 1
  fi

  mkdir -p "$CODEX_DIR"

  # 스킬 → .agents/skills/ (Codex 규칙)
  echo "  [1/3] 스킬..."
  # Codex는 프로젝트별 AGENTS.md를 사용하므로 ~/.codex/skills/에 참조용 보관
  mkdir -p "${CODEX_DIR}/skills"
  for skill_dir in "${DIST_DIR}/codex/skills/"*/; do
    skill_name=$(basename "$skill_dir")
    mkdir -p "${CODEX_DIR}/skills/${skill_name}"
    do_copy "$skill_dir" "${CODEX_DIR}/skills/${skill_name}/.."
  done

  # Ralph Loop
  echo "  [2/3] Ralph Loop..."
  mkdir -p "${CODEX_DIR}/ralph-loop"
  do_copy "${DIST_DIR}/codex/ralph-loop" "${CODEX_DIR}/"

  # config.toml
  echo "  [3/3] config.toml..."
  if [ -f "${CODEX_DIR}/config.toml" ] && [ "$DRY_RUN" = false ]; then
    cp "${CODEX_DIR}/config.toml" "${CODEX_DIR}/config.toml.bak"
  fi
  do_copy "${DIST_DIR}/codex/config.toml" "${CODEX_DIR}/config.toml"

  echo "  ✓ Codex CLI 배포 완료"
fi

echo ""
echo "=== 배포 완료 ==="
if [ "$DRY_RUN" = true ]; then
  echo "(DRY RUN — 실제 변경 없음)"
fi
echo ""
echo "사용법:"
echo "  Ralph Loop (Claude):  ralph-loop --project-dir /path/to/project"
echo "  Ralph Loop (Codex):   ralph-loop --project-dir /path/to/project --adapter codex"
echo "  Refine (세션 내):     /refine \"프롬프트\" --max-iter 5"
