#!/bin/bash
# Refine Loop - HUD 래퍼
# 기존 claude-hud 출력 후 Refine Loop 상태를 확장 표시합니다.
# 표시 형식: Refine 3/10 [E] | 정체 1/3 | $0.42/$5.00 | 12분

# 기존 HUD 실행
HUD_DIR=$(ls -td ~/.claude/plugins/cache/claude-hud/claude-hud/*/ 2>/dev/null | head -1)
if [ -n "$HUD_DIR" ]; then
  "$HOME/.bun/bin/bun" "${HUD_DIR}src/index.ts" 2>/dev/null
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

if ! is_refine_active; then
  exit 0
fi

# ── 상태 읽기 ──
iteration=$(get_frontmatter_field "$REFINE_STATE_FILE" "iteration" "1")
max_iterations=$(get_frontmatter_field "$REFINE_STATE_FILE" "max_iterations" "10")
phase=$(get_frontmatter_field "$REFINE_STATE_FILE" "phase" "plan")
stagnation=$(get_frontmatter_field "$REFINE_STATE_FILE" "stagnation_count" "0")
stagnation_limit=$(get_frontmatter_field "$REFINE_STATE_FILE" "stagnation_limit" "3")
total_cost=$(get_frontmatter_field "$REFINE_STATE_FILE" "total_cost_usd" "0.0")
token_budget=$(get_frontmatter_field "$REFINE_STATE_FILE" "token_budget_usd" "0")
started_at=$(get_frontmatter_field "$REFINE_STATE_FILE" "started_at" "")

# ── ANSI 색상 ──
CYAN='\033[36m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
RESET='\033[0m'

# ── phase 아이콘 ──
case "$phase" in
  plan)    phase_icon="P" ;;
  execute) phase_icon="E" ;;
  verify)  phase_icon="V" ;;
  record)  phase_icon="R" ;;
  *)       phase_icon="?" ;;
esac

# ── 기본 라인: Refine N/MAX [P] ──
refine_line="${CYAN}Refine${RESET}\u00A0${iteration}/${max_iterations}\u00A0[${phase_icon}]"

# ── 정체 표시 ──
if [ "$stagnation" -gt 0 ] 2>/dev/null; then
  stag_color="$YELLOW"
  if [ "$stagnation" -ge "$stagnation_limit" ] 2>/dev/null; then
    stag_color="$RED"
  fi
  refine_line="${refine_line}\u00A0${DIM}|${RESET}\u00A0${stag_color}정체\u00A0${stagnation}/${stagnation_limit}${RESET}"
fi

# ── 비용 표시 ──
cost_display="\$${total_cost}"
if [ "$token_budget" != "0" ]; then
  cost_display="\$${total_cost}/\$${token_budget}"
fi
refine_line="${refine_line}\u00A0${DIM}|${RESET}\u00A0${cost_display}"

# ── 경과 시간 표시 ──
if [ -n "$started_at" ]; then
  elapsed_minutes=$(elapsed_minutes_since "$started_at")
  refine_line="${refine_line}\u00A0${DIM}|${RESET}\u00A0${elapsed_minutes}분"
fi

echo -e "$refine_line"
