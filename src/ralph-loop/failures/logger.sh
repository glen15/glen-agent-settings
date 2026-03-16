#!/bin/bash
# Failure Logger — Ralph Loop 전용 실패 자동 기록/조회/주입
# source 해서 사용
#
# 글로벌: ~/.claude/failures/index.jsonl  — 도구 자체 버그, 설정 오류
# 프로젝트: {project}/.failures/index.jsonl — 검증 실패, 콘텐츠 이슈

FAILURES_GLOBAL_DIR="${HOME}/.claude/failures"
FAILURES_GLOBAL_INDEX="${FAILURES_GLOBAL_DIR}/index.jsonl"

# ── 경로 결정 ──

# scope에 따라 index 파일 경로 반환
_failure_index() {
  local scope="${1:-global}"
  local project="${2:-$(pwd)}"

  if [ "$scope" = "project" ]; then
    echo "${project}/.failures/index.jsonl"
  else
    echo "$FAILURES_GLOBAL_INDEX"
  fi
}

# ── 기록 ──

# 실패 레코드 추가
# scope: global(도구/설정 문제) | project(프로젝트 내 검증/콘텐츠 실패)
failure_record() {
  local scope="$1"     # global|project
  local type="$2"      # permission_denied|max_turns|rate_limit|validation_fail|tool_error|provider_error|design_flaw|config_error
  local severity="$3"  # critical|high|medium|low
  local context="$4"   # 발생 컨텍스트
  local details="$5"   # 상세 설명
  local resolution="${6:-}"  # 해결 방법
  local cost="${7:-0}"       # 소비 비용 USD
  local project="${8:-$(pwd)}"

  local index
  index=$(_failure_index "$scope" "$project")
  mkdir -p "$(dirname "$index")"

  jq -cn \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg scope "$scope" \
    --arg type "$type" \
    --arg severity "$severity" \
    --arg context "$context" \
    --arg details "$details" \
    --arg resolution "$resolution" \
    --argjson cost "$cost" \
    --arg project "$project" \
    '{ts:$ts, scope:$scope, type:$type, severity:$severity, context:$context, details:$details, resolution:$resolution, cost_usd:$cost, project:$project}' \
    >> "$index"
}

# claude -p JSON 출력에서 실패 자동 추출/기록 (항상 global scope)
failure_analyze_claude_output() {
  local output_file="$1"
  local context="${2:-unknown}"
  local project="${3:-$(pwd)}"

  [ -f "$output_file" ] || return 0

  local subtype cost denials_count
  subtype=$(jq -r '.subtype // ""' "$output_file" 2>/dev/null)
  cost=$(jq -r '.total_cost_usd // 0' "$output_file" 2>/dev/null)

  # max_turns 초과
  if [ "$subtype" = "error_max_turns" ]; then
    local turns
    turns=$(jq -r '.num_turns // "?"' "$output_file" 2>/dev/null)
    failure_record "global" "max_turns" "high" "$context" \
      "${turns}턴 소진, 작업 미완료" \
      "--max-turns 증가 또는 작업 분할" \
      "$cost" "$project"
  fi

  # permission 거부
  denials_count=$(jq '.permission_denials // [] | length' "$output_file" 2>/dev/null)
  if [ "$denials_count" -gt 0 ] 2>/dev/null; then
    local denied_tools
    denied_tools=$(jq -r '[.permission_denials[].tool_name] | unique | join(", ")' "$output_file" 2>/dev/null)
    failure_record "global" "permission_denied" "critical" "$context" \
      "도구 거부 ${denials_count}회: ${denied_tools}" \
      "--permission-mode bypassPermissions 추가" \
      "$cost" "$project"
  fi

  # 에러 종료
  local is_error
  is_error=$(jq -r '.is_error // false' "$output_file" 2>/dev/null)
  if [ "$is_error" = "true" ]; then
    failure_record "global" "tool_error" "high" "$context" \
      "에이전트 에러 종료" "" "$cost" "$project"
  fi
}

# ── 조회 ──

# 최근 N개 실패 (scope별)
failure_recent() {
  local scope="${1:-all}"  # global|project|all
  local count="${2:-10}"
  local project="${3:-$(pwd)}"

  if [ "$scope" = "all" ]; then
    # 글로벌 + 프로젝트 합쳐서 시간순 정렬
    {
      [ -f "$FAILURES_GLOBAL_INDEX" ] && cat "$FAILURES_GLOBAL_INDEX" || true
      local proj_index
      proj_index=$(_failure_index "project" "$project")
      [ -f "$proj_index" ] && cat "$proj_index" || true
    } | jq -s 'sort_by(.ts)' | jq -r '.[] | [.ts, .scope, .type, .severity, .details] | join(" | ")' | tail -n "$count"
  else
    local index
    index=$(_failure_index "$scope" "$project")
    [ -f "$index" ] || return 0
    tail -n "$count" "$index" | jq -r '[.ts, .scope, .type, .severity, .details] | join(" | ")'
  fi
}

# 총 비용 집계 (scope별)
failure_total_cost() {
  local scope="${1:-all}"
  local project="${2:-$(pwd)}"

  if [ "$scope" = "all" ]; then
    local g=0 p=0
    [ -f "$FAILURES_GLOBAL_INDEX" ] && g=$(jq -s '[.[].cost_usd] | add // 0' "$FAILURES_GLOBAL_INDEX")
    local proj_index
    proj_index=$(_failure_index "project" "$project")
    [ -f "$proj_index" ] && p=$(jq -s '[.[].cost_usd] | add // 0' "$proj_index")
    echo "$g $p" | awk '{printf "%.2f", $1 + $2}'
  else
    local index
    index=$(_failure_index "$scope" "$project")
    [ -f "$index" ] || { echo "0"; return 0; }
    jq -s '[.[].cost_usd] | add // 0' "$index"
  fi
}

# 실패 수 카운트 (scope별)
failure_count() {
  local scope="${1:-all}"
  local project="${2:-$(pwd)}"

  if [ "$scope" = "all" ]; then
    local g=0 p=0
    [ -f "$FAILURES_GLOBAL_INDEX" ] && g=$(wc -l < "$FAILURES_GLOBAL_INDEX" | tr -d ' ')
    local proj_index
    proj_index=$(_failure_index "project" "$project")
    [ -f "$proj_index" ] && p=$(wc -l < "$proj_index" | tr -d ' ')
    echo $((g + p))
  else
    local index
    index=$(_failure_index "$scope" "$project")
    [ -f "$index" ] || { echo "0"; return 0; }
    wc -l < "$index" | tr -d ' '
  fi
}

# ── 프롬프트 주입 ──

# 글로벌 + 프로젝트 실패를 마크다운으로 포맷
failure_inject_prompt() {
  local count="${1:-5}"
  local project="${2:-$(pwd)}"

  local global_entries="" project_entries=""

  # 글로벌 실패
  if [ -f "$FAILURES_GLOBAL_INDEX" ]; then
    global_entries=$(tail -n "$count" "$FAILURES_GLOBAL_INDEX")
  fi

  # 프로젝트 실패
  local proj_index
  proj_index=$(_failure_index "project" "$project")
  if [ -f "$proj_index" ]; then
    project_entries=$(tail -n "$count" "$proj_index")
  fi

  [ -z "$global_entries" ] && [ -z "$project_entries" ] && return 0

  echo ""
  echo "## 과거 실패 기록"
  echo ""

  if [ -n "$global_entries" ]; then
    echo "### 도구/설정 실패 (글로벌)"
    echo "$global_entries" | jq -r '"- **\(.type)**: \(.details) → \(.resolution // "미해결")"'
    echo ""
  fi

  if [ -n "$project_entries" ]; then
    echo "### 프로젝트 실패"
    echo "$project_entries" | jq -r '"- **\(.type)**: \(.details) → \(.resolution // "미해결")"'
    echo ""
  fi
}

# ── 관리 ──

# 오래된 항목 정리 (N일 이전)
_prune_index() {
  local index="$1"
  local cutoff="$2"
  [ -f "$index" ] || return 0
  local tmp="${index}.tmp"
  jq -c "select(.ts >= \"$cutoff\")" "$index" > "$tmp" 2>/dev/null
  mv "$tmp" "$index"
}

failure_prune() {
  local scope="${1:-all}"
  local days="${2:-30}"
  local project="${3:-$(pwd)}"

  local cutoff
  cutoff=$(date -u -v-${days}d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "${days} days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)

  if [ "$scope" = "all" ] || [ "$scope" = "global" ]; then
    _prune_index "$FAILURES_GLOBAL_INDEX" "$cutoff"
  fi
  if [ "$scope" = "all" ] || [ "$scope" = "project" ]; then
    _prune_index "$(_failure_index "project" "$project")" "$cutoff"
  fi
}
