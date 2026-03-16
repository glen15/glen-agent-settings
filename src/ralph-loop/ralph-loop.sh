#!/bin/bash
# Ralph Loop - 밤샘 무인 자율 코딩 오케스트레이터
# 수렴 아키텍처: task_plan 기준 → 라운드 반복 → 파일별 품질 수렴
#
# 사용법:
#   ralph-loop.sh --project-dir /path/to/project --task-plan criteria.md [옵션]
#
# 옵션:
#   --project-dir DIR     대상 프로젝트 디렉토리 (필수, --resume 시 불필요)
#   --task-plan FILE      검토 기준 파일 (필수, 기본: task_plan.md)
#   --scope SCOPE         대상 범위 (all|glob|@파일목록, 기본: all)
#   --max-iterations N    최대 라운드 횟수 (기본: 50)
#   --max-turns N         라운드당 최대 에이전트 턴 (기본: 30)
#   --adapter NAME        AI 엔진 (claude|codex, 기본: claude)
#   --model MODEL         사용할 모델 (기본: 어댑터 기본값)
#   --branch NAME         작업 브랜치 이름 (기본: ralph/날짜)
#   --disable-1m          1M 컨텍스트 비활성화 (claude 전용)
#   --resume DIR          이전 세션 로그 디렉토리에서 재개
#   --dry-run             실제 API 호출 없이 흐름만 확인
#   --skip-after N        N라운드 연속 미수정 시 자동 제외 (기본: 3)
#   --convergence-threshold N  N라운드 연속 변경0이면 수렴 완료 (기본: 2)
#   --batch-size N        라운드당 처리 파일 수 (기본: 0=제한없음)
#   --no-wait             사용자 대기 없이 연속 실행
#   --help                도움말 표시

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/backoff.sh"
source "${SCRIPT_DIR}/lib/stagnation.sh"
source "${SCRIPT_DIR}/lib/gate.sh"
source "${SCRIPT_DIR}/lib/jsonl.sh"
source "${SCRIPT_DIR}/lib/convergence.sh"
source "${SCRIPT_DIR}/failures/logger.sh"

# ── 기본값 ──
PROJECT_DIR=""
MAX_ITERATIONS=50
MAX_TURNS=30
MODEL=""
BRANCH=""
ADAPTER="claude"
DISABLE_1M=false
DRY_RUN=false
RESUME_DIR=""
LOG_DIR=""
SCOPE="all"
TASK_PLAN=""
SKIP_AFTER=3
CONVERGENCE_THRESHOLD=2
BATCH_SIZE=0
WAIT_REVIEW=true

# ── 인자 파싱 ──
parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --project-dir)  PROJECT_DIR="$2"; shift 2 ;;
      --task-plan)    TASK_PLAN="$2"; shift 2 ;;
      --scope)        SCOPE="$2"; shift 2 ;;
      --max-iterations) MAX_ITERATIONS="$2"; shift 2 ;;
      --max-turns)    MAX_TURNS="$2"; shift 2 ;;
      --model)        MODEL="$2"; shift 2 ;;
      --branch)       BRANCH="$2"; shift 2 ;;
      --adapter)      ADAPTER="$2"; shift 2 ;;
      --disable-1m)   DISABLE_1M=true; shift ;;
      --resume)       RESUME_DIR="$2"; shift 2 ;;
      --dry-run)      DRY_RUN=true; shift ;;
      --skip-after)   SKIP_AFTER="$2"; shift 2 ;;
      --convergence-threshold) CONVERGENCE_THRESHOLD="$2"; shift 2 ;;
      --batch-size)   BATCH_SIZE="$2"; shift 2 ;;
      --no-wait)      WAIT_REVIEW=false; shift ;;
      --help)         show_help; exit 0 ;;
      *)              echo "알 수 없는 옵션: $1" >&2; exit 1 ;;
    esac
  done
}

show_help() {
  sed -n '2,22p' "$0" | sed 's/^# //' | sed 's/^#//'
}

# ── 환경 설정 ──
setup_environment() {
  # resume 모드: 이전 세션에서 설정 복원
  if [ -n "$RESUME_DIR" ]; then
    if [ ! -d "$RESUME_DIR" ]; then
      echo "오류: 세션 디렉토리 없음: $RESUME_DIR" >&2
      exit 1
    fi
    load_session "$RESUME_DIR"
    LOG_DIR="$RESUME_DIR"
    SKIP_INIT=true
    echo "=== Ralph Loop 재개 ==="
    echo "세션: $RESUME_DIR"
  else
    if [ -z "$PROJECT_DIR" ]; then
      echo "오류: --project-dir 필수" >&2
      exit 1
    fi

    if [ ! -d "$PROJECT_DIR" ]; then
      echo "오류: 프로젝트 디렉토리 없음: $PROJECT_DIR" >&2
      exit 1
    fi

    # 브랜치 설정
    if [ -z "$BRANCH" ]; then
      BRANCH="ralph/$(date +%Y%m%d-%H%M)"
    fi

    # 로그 디렉토리
    LOG_DIR="${PROJECT_DIR}/.ralph-logs/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$LOG_DIR"

    echo "=== Ralph Loop 시작 ==="
  fi

  cd "$PROJECT_DIR"

  # 1M 컨텍스트 비활성화
  if [ "$DISABLE_1M" = true ]; then
    export CLAUDE_CODE_DISABLE_1M_CONTEXT=1
  fi

  # 어댑터 로드
  load_adapter

  # JSONL 로거 초기화
  init_jsonl "$LOG_DIR"

  echo "프로젝트: $PROJECT_DIR"
  echo "어댑터: $ADAPTER"
  echo "브랜치: $BRANCH"
  echo "최대 라운드: $MAX_ITERATIONS"
  echo "라운드당 턴: $MAX_TURNS"
  echo "스코프: $SCOPE"
  echo "기준 파일: $TASK_PLAN"
  echo "제외 기준: ${SKIP_AFTER}라운드 연속 미수정"
  echo "수렴 기준: ${CONVERGENCE_THRESHOLD}라운드 연속 변경0"
  [ "$BATCH_SIZE" -gt 0 ] 2>/dev/null && echo "배치 크기: $BATCH_SIZE"
  echo "사용자 대기: $WAIT_REVIEW"
  echo "1M 비활성화: $DISABLE_1M"
  echo "로그: $LOG_DIR"
  echo "========================"
}

# ── git 브랜치 생성 ──
setup_branch() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "오류: git 리포지토리가 아닙니다" >&2
    exit 1
  fi

  if ! git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
    git checkout -b "$BRANCH"
    emit_jsonl "BRANCH_CREATE" "브랜치 생성: $BRANCH"
  else
    git checkout "$BRANCH"
    emit_jsonl "BRANCH_CHECKOUT" "기존 브랜치 체크아웃: $BRANCH"
  fi
}

# ── 어댑터 로드 ──
load_adapter() {
  local adapter_file="${SCRIPT_DIR}/adapters/${ADAPTER}.sh"
  if [ ! -f "$adapter_file" ]; then
    echo "오류: 어댑터 없음: ${ADAPTER} (${adapter_file})" >&2
    echo "사용 가능: claude, codex" >&2
    exit 1
  fi
  source "$adapter_file"
}

# ── AI 에이전트 실행 래퍼 ──
run_ai_agent() {
  local prompt_file="$1"
  local output_file="$2"

  if [ "$DRY_RUN" = true ]; then
    dry_run_output > "$output_file"
    return 0
  fi

  local start_time
  start_time=$(date +%s)

  run_agent "$prompt_file" "$output_file" "$MAX_TURNS" "$MODEL"
  local exit_code=$?

  local end_time
  end_time=$(date +%s)
  local duration=$((end_time - start_time))

  # 토큰 사용량 추출 (어댑터별 파서)
  local usage
  usage=$(parse_adapter_tokens "$output_file")
  local input_tokens="${usage%%:*}"
  local output_tokens="${usage##*:}"

  emit_jsonl "AGENT_CALL" "$(basename "$prompt_file")" \
    "adapter=${ADAPTER}" \
    "exit_code=${exit_code}" \
    "duration_s=${duration}" \
    "input_tokens=${input_tokens}" \
    "output_tokens=${output_tokens}"

  # 실패 자동 기록
  failure_analyze_claude_output "$output_file" \
    "ralph-loop/$(basename "$prompt_file" .md)" "$PROJECT_DIR"

  return $exit_code
}

# ── 수렴 루프 ──
run_convergence_loop() {
  local state_file="${LOG_DIR}/scope-state.json"
  local exception_file="${PROJECT_DIR}/exception.md"

  # 스코프 초기화
  init_scope_state "$SCOPE" "$PROJECT_DIR" "$state_file" "$SKIP_AFTER" "$CONVERGENCE_THRESHOLD"

  # exception.md 템플릿 복사 (없으면)
  if [ ! -f "$exception_file" ]; then
    cp "${SCRIPT_DIR}/templates/exception.md" "$exception_file"
  fi

  local round=0
  local backoff_attempt=0

  while [ $round -lt $MAX_ITERATIONS ]; do
    round=$((round + 1))
    local iter_log="${LOG_DIR}/iteration-${round}.json"

    local active_count
    active_count=$(get_active_count "$state_file")

    # active 파일이 0이면 수렴 완료
    if [ "$active_count" -eq 0 ]; then
      emit_jsonl "CONVERGED" "모든 파일 제외됨 — 수렴 완료" "round=${round}"
      echo "[라운드 #${round}] 활성 파일 0 — 수렴 완료!" >&2
      finalize_session "$LOG_DIR" "converged"
      break
    fi

    emit_jsonl "ROUND_START" "라운드 #${round}/${MAX_ITERATIONS}" \
      "round=${round}" "active_files=${active_count}"
    echo "[$(date '+%H:%M:%S')] === 라운드 #${round}/${MAX_ITERATIONS} (활성: ${active_count}) ===" >&2

    # 라운드 시작 git tag
    mark_round_start "$round"

    # ── 프롬프트 조합 ──
    local augmented_prompt="${LOG_DIR}/converge-augmented.md"
    cat "${SCRIPT_DIR}/prompts/converge.md" > "$augmented_prompt"

    # task_plan 내용 주입
    if [ -f "$TASK_PLAN" ]; then
      {
        echo ""
        echo "---"
        echo "## 기준 (task_plan)"
        echo ""
        cat "$TASK_PLAN"
      } >> "$augmented_prompt"
    fi

    # exception.md 피드백 주입
    parse_exception_md "$exception_file" "$state_file"
    if [ -n "$EXCEPTION_FIXES" ] || [ -n "$EXCEPTION_CRITERIA" ]; then
      {
        echo ""
        echo "---"
        echo "## 사용자 피드백 (exception)"
        [ -n "$EXCEPTION_FIXES" ] && echo -e "\n### 수정 요청\n${EXCEPTION_FIXES}"
        [ -n "$EXCEPTION_CRITERIA" ] && echo -e "\n### 기준 변경\n${EXCEPTION_CRITERIA}"
      } >> "$augmented_prompt"
    fi

    # active 파일 목록 주입
    local file_list
    if [ "$BATCH_SIZE" -gt 0 ]; then
      file_list=$(get_batch_files "$state_file" "$BATCH_SIZE")
    else
      file_list=$(get_active_files "$state_file")
    fi

    {
      echo ""
      echo "---"
      echo "## 검토 대상 파일 (라운드 #${round})"
      echo ""
      while IFS= read -r f; do
        [ -z "$f" ] && continue
        echo "- $f"
      done <<< "$file_list"
    } >> "$augmented_prompt"

    # 실패 기록 주입
    failure_inject_prompt 5 "$PROJECT_DIR" >> "$augmented_prompt"

    # ── 에이전트 호출 ──
    run_ai_agent "$augmented_prompt" "$iter_log"
    local exit_code=$?

    # ── rate limit 감지 ──
    if [ -f "$iter_log" ] && detect_rate_limit "$iter_log"; then
      backoff_attempt=$((backoff_attempt + 1))
      emit_jsonl "RATE_LIMIT" "Rate limit 감지" "attempt=${backoff_attempt}"
      wait_with_backoff "$backoff_attempt" "${LOG_DIR}/loop.log"
      round=$((round - 1))
      continue
    fi

    # ── provider 장애 감지 ──
    if [ -f "$iter_log" ] && detect_provider_error "$iter_log"; then
      emit_jsonl "PROVIDER_ERROR" "Provider 장애 감지. 10분 대기"
      sleep 600
      round=$((round - 1))
      continue
    fi

    backoff_attempt=0

    # ── 라운드 결과 처리 ──
    local changes_count
    changes_count=$(update_file_state "$state_file" "$round")

    local excluded_count
    excluded_count=$(apply_exclusions "$state_file" "$SKIP_AFTER" "$round")

    # 제외된 파일 이벤트 기록
    if [ "$excluded_count" -gt 0 ]; then
      emit_jsonl "FILE_EXCLUDED" "${excluded_count}개 파일 자동 제외" \
        "round=${round}" "excluded=${excluded_count}"
    fi

    local summary
    summary=$(generate_round_summary "$state_file" "$round" "$changes_count" "$excluded_count")

    emit_jsonl "ROUND_END" "$summary" \
      "round=${round}" "changes=${changes_count}" "excluded=${excluded_count}"
    echo "[$(date '+%H:%M:%S')] $summary" >&2

    # ── 수렴 체크 ──
    if check_convergence "$state_file" "$CONVERGENCE_THRESHOLD"; then
      emit_jsonl "CONVERGED" "수렴 완료" "round=${round}" "threshold=${CONVERGENCE_THRESHOLD}"
      echo "[라운드 #${round}] 수렴 완료! (${CONVERGENCE_THRESHOLD}라운드 연속 변경 없음)" >&2
      finalize_session "$LOG_DIR" "converged"
      break
    fi

    # ── 사용자 검토 대기 ──
    if [ "$WAIT_REVIEW" = true ] && [ "$DRY_RUN" != true ]; then
      emit_jsonl "USER_REVIEW_WAIT" "사용자 검토 대기" "round=${round}"
      echo "" >&2
      echo "────────────────────────────────────" >&2
      echo "라운드 #${round} 완료. 검토 후:" >&2
      echo "  Enter    → 다음 라운드 진행" >&2
      echo "  q + Enter → 루프 중단" >&2
      echo "  exception.md 수정 후 Enter → 피드백 반영" >&2
      echo "────────────────────────────────────" >&2

      local user_input=""
      read -r user_input < /dev/tty 2>/dev/null || true
      if [ "$user_input" = "q" ] || [ "$user_input" = "quit" ]; then
        emit_jsonl "USER_QUIT" "사용자 중단" "round=${round}"
        finalize_session "$LOG_DIR" "user_quit"
        break
      fi

      # exception.md 변경 반영
      if [ -f "$exception_file" ]; then
        parse_exception_md "$exception_file" "$state_file"
        if [ -n "$EXCEPTION_FIXES" ] || [ -n "$EXCEPTION_EXCLUDES" ] || [ -n "$EXCEPTION_CRITERIA" ]; then
          emit_jsonl "EXCEPTION_APPLIED" "exception.md 피드백 반영" "round=${round}"
        fi
      fi
    fi

    sleep 5
  done

  # max iterations 도달
  if [ $round -ge $MAX_ITERATIONS ]; then
    emit_jsonl "MAX_ITERATIONS" "최대 라운드 도달" "round=${round}"
    finalize_session "$LOG_DIR" "max_iterations"
  fi

  echo "$round"
}

# ── 요약 생성 ──
generate_summary() {
  local total_iterations="$1"
  local summary_file="${LOG_DIR}/summary.md"

  {
    echo "# Ralph Loop 실행 요약"
    echo ""
    echo "- 프로젝트: $PROJECT_DIR"
    echo "- 브랜치: $BRANCH"
    echo "- 총 반복: $total_iterations"
    echo "- 시작: $(jq -r 'select(.step == "INIT_START" or .step == "RESUME") | .ts' "$JSONL_FILE" 2>/dev/null | head -1 || echo 'N/A')"
    echo "- 종료: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # 토큰 통계
    local total_input total_output
    total_input=$(jq -r 'select(.step == "AGENT_CALL") | .input_tokens // 0' "$JSONL_FILE" 2>/dev/null | awk '{s+=$1}END{print s+0}')
    total_output=$(jq -r 'select(.step == "AGENT_CALL") | .output_tokens // 0' "$JSONL_FILE" 2>/dev/null | awk '{s+=$1}END{print s+0}')
    echo "## 토큰 사용량"
    echo "- 입력: ${total_input}"
    echo "- 출력: ${total_output}"
    echo ""

    echo "## 커밋 히스토리"
    echo '```'
    git log --oneline "${BRANCH}" --not main 2>/dev/null || git log --oneline -20 2>/dev/null || echo "(커밋 없음)"
    echo '```'
    echo ""
    echo "## 수렴 상태"
    local state_file="${LOG_DIR}/scope-state.json"
    if [ -f "$state_file" ]; then
      local total_files active_count excluded_count total_changes conv_zero
      total_files=$(jq '.files | length' "$state_file")
      active_count=$(jq '[.files | to_entries[] | select(.value.status == "active")] | length' "$state_file")
      excluded_count=$(jq '[.files | to_entries[] | select(.value.status == "excluded")] | length' "$state_file")
      total_changes=$(jq '.total_changes' "$state_file")
      conv_zero=$(jq '.consecutive_zero_rounds' "$state_file")
      echo "- 전체 파일: $total_files"
      echo "- 활성: $active_count"
      echo "- 제외: $excluded_count"
      echo "- 총 변경: $total_changes"
      echo "- 연속 무변경: $conv_zero"
      echo ""
      echo "### 수정 횟수 상위 10"
      jq -r '.files | to_entries[] | select(.value.total_modifications > 0) | "\(.value.total_modifications)회 \(.key)"' "$state_file" 2>/dev/null | sort -rn | head -10
    else
      echo "(scope-state.json 없음)"
    fi

    echo ""
    echo "## 실패 기록"
    local fail_count
    fail_count=$(failure_count "all" "$PROJECT_DIR")
    echo "- 누적 실패: ${fail_count}건"
    echo "- 낭비 비용: \$$(failure_total_cost "all" "$PROJECT_DIR")"
    if [ "$fail_count" -gt 0 ] 2>/dev/null; then
      echo ""
      failure_recent "all" 5 "$PROJECT_DIR"
    fi

    echo ""
    echo "## 이벤트 로그"
    echo '```'
    jq -r '[.ts, .step, .message] | join(" | ")' "$JSONL_FILE" 2>/dev/null || echo "(로그 없음)"
    echo '```'
  } > "$summary_file"

  echo ""
  cat "$summary_file"
  echo ""
  echo "상세 로그: $LOG_DIR"
  echo "JSONL 로그: ${JSONL_FILE}"
}

# ── 메인 ──
main() {
  parse_args "$@"
  setup_environment

  # 세션 저장 (새 세션일 때만)
  if [ -z "$RESUME_DIR" ]; then
    save_session "$LOG_DIR"
  fi

  # task_plan 필수
  if [ -z "$TASK_PLAN" ]; then
    TASK_PLAN="${PROJECT_DIR}/task_plan.md"
  fi
  if [ ! -f "$TASK_PLAN" ]; then
    echo "오류: task_plan 파일 없음: $TASK_PLAN" >&2
    echo "  --task-plan 옵션으로 기준 파일을 지정하세요." >&2
    exit 1
  fi

  setup_branch

  # 수렴 루프 실행
  local total_iterations
  total_iterations=$(run_convergence_loop)

  # Phase 3: 요약
  generate_summary "$total_iterations"

  echo "=== Ralph Loop 종료 ==="
  echo "재개: ralph-loop --resume $LOG_DIR"
}

main "$@"
