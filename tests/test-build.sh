#!/bin/bash
# glen-agent-settings — 빌드 검증 테스트
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"

passed=0
failed=0

assert() {
  local desc="$1" condition="$2"
  if eval "$condition"; then
    echo "  ✓ $desc"
    passed=$((passed + 1))
  else
    echo "  ✗ $desc"
    failed=$((failed + 1))
  fi
}

echo "=== 빌드 검증 테스트 ==="

# 빌드 실행
echo "[빌드 실행]"
bash "${ROOT_DIR}/scripts/build.sh" > /dev/null 2>&1
assert "빌드 성공" "true"

# ── Claude dist 검증 ──
echo ""
echo "[Claude dist 검증]"
for skill in create-content done notebooklm nxt refine security-review tdd-workflow ui-ux-pro-max; do
  assert "스킬 존재: $skill" "[ -d '${DIST_DIR}/claude/skills/${skill}' ]"
  assert "SKILL.md 존재: $skill" "[ -f '${DIST_DIR}/claude/skills/${skill}/SKILL.md' ]"
done

assert "harness.md 존재" "[ -f '${DIST_DIR}/claude/skills/harness.md' ]"
assert "CLAUDE.md 존재" "[ -f '${DIST_DIR}/claude/CLAUDE.md' ]"
assert "settings.json 존재" "[ -f '${DIST_DIR}/claude/settings.json' ]"

# Hooks
for hook in auto-test.sh debug-stop-hook.sh post-task-commit-check.sh secret-scanner.sh stop-console-check.sh; do
  assert "root hook: $hook" "[ -f '${DIST_DIR}/claude/hooks/${hook}' ]"
done
for hook in commit-check.sh detect-stagnation.sh hud-wrapper.sh lib.sh prompt-init.sh stop-loop.sh calc-cost.py; do
  assert "refine hook: $hook" "[ -f '${DIST_DIR}/claude/hooks/refine/${hook}' ]"
done

# Ralph Loop
assert "ralph-loop.sh 존재" "[ -f '${DIST_DIR}/claude/ralph-loop/ralph-loop.sh' ]"
assert "ralph-loop.sh 실행 가능" "[ -x '${DIST_DIR}/claude/ralph-loop/ralph-loop.sh' ]"
assert "claude 어댑터 존재" "[ -f '${DIST_DIR}/claude/ralph-loop/adapters/claude.sh' ]"
assert "codex 어댑터 존재" "[ -f '${DIST_DIR}/claude/ralph-loop/adapters/codex.sh' ]"
for lib in backoff.sh gate.sh jsonl.sh stagnation.sh; do
  assert "lib: $lib" "[ -f '${DIST_DIR}/claude/ralph-loop/lib/${lib}' ]"
done
assert "failures/logger.sh 존재" "[ -f '${DIST_DIR}/claude/ralph-loop/failures/logger.sh' ]"

# Agents
echo ""
echo "[Claude agents 검증]"
for agent in architect build-error-resolver code-reviewer doc-updater e2e-runner planner refactor-cleaner security-reviewer tdd-guide; do
  assert "에이전트: $agent" "[ -f '${DIST_DIR}/claude/agents/${agent}.md' ]"
done

# Commands
echo ""
echo "[Claude commands 검증]"
for cmd in build-fix code-review e2e plan refactor-clean tdd test-coverage update-codemaps update-docs; do
  assert "커맨드: $cmd" "[ -f '${DIST_DIR}/claude/commands/${cmd}.md' ]"
done

# ── Codex dist 검증 ──
echo ""
echo "[Codex dist 검증]"
for skill in create-content done notebooklm nxt refine security-review tdd-workflow ui-ux-pro-max; do
  assert "AGENTS.md 존재: $skill" "[ -f '${DIST_DIR}/codex/skills/${skill}/AGENTS.md' ]"
done

# Codex AGENTS.md에 frontmatter가 없는지 확인
echo ""
echo "[Codex frontmatter 제거 검증]"
for skill_dir in "${DIST_DIR}/codex/skills/"*/; do
  skill_name=$(basename "$skill_dir")
  agents_file="${skill_dir}/AGENTS.md"
  if [ -f "$agents_file" ]; then
    first_line=$(head -1 "$agents_file")
    assert "${skill_name}: frontmatter 없음" "[ '$first_line' != '---' ]"
  fi
done

assert "AGENTS.md (root) 존재" "[ -f '${DIST_DIR}/codex/AGENTS.md' ]"
assert "config.toml 존재" "[ -f '${DIST_DIR}/codex/config.toml' ]"
assert "ralph-loop.sh 존재" "[ -f '${DIST_DIR}/codex/ralph-loop/ralph-loop.sh' ]"

# ── 요약 ──
echo ""
total=$((passed + failed))
echo "=== 결과: ${passed}/${total} 통과 ==="
if [ $failed -gt 0 ]; then
  echo "실패: $failed"
  exit 1
fi
