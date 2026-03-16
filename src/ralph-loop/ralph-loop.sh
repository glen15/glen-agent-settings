#!/bin/bash
# Ralph Loop - 밤샘 무인 자율 코딩 오케스트레이터
# Geoffrey Huntley 원조 패턴 기반: 매 반복 fresh context + 파일시스템 상태 인수인계
#
# 사용법:
#   ralph-loop.sh --project-dir /path/to/project [옵션]
#
# 옵션:
#   --project-dir DIR     대상 프로젝트 디렉토리 (필수, --resume 시 불필요)
#   --max-iterations N    최대 반복 횟수 (기본: 50)
#   --max-turns N         반복당 최대 에이전트 턴 (기본: 30)
#   --adapter NAME        AI 엔진 (claude|codex, 기본: claude)
#   --model MODEL         사용할 모델 (기본: 어댑터 기본값)
#   --branch NAME         작업 브랜치 이름 (기본: ralph/날짜)
#   --prd FILE            기존 prd.json 경로 (없으면 init 에이전트가 생성)
#   --disable-1m          1M 컨텍스트 비활성화 (claude 전용)
#   --skip-init           초기화 단계 건너뛰기
#   --resume DIR          이전 세션 로그 디렉토리에서 재개
#   --dry-run             실제 API 호출 없이 흐름만 확인
#   --help                도움말 표시

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/backoff.sh"
source "${SCRIPT_DIR}/lib/stagnation.sh"
source "${SCRIPT_DIR}/lib/gate.sh"
source "${SCRIPT_DIR}/lib/jsonl.sh"
source "${SCRIPT_DIR}/failures/logger.sh"

# ── 기본값 ──
PROJECT_DIR=""
MAX_ITERATIONS=50
MAX_TURNS=30
MODEL=""
BRANCH=""
PRD_FILE=""
ADAPTER="claude"
DISABLE_1M=false
SKIP_INIT=false
DRY_RUN=false
RESUME_DIR=""
LOG_DIR=""

# ── 인자 파싱 ──
parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --project-dir)  PROJECT_DIR="$2"; shift 2 ;;
      --max-iterations) MAX_ITERATIONS="$2"; shift 2 ;;
      --max-turns)    MAX_TURNS="$2"; shift 2 ;;
      --model)        MODEL="$2"; shift 2 ;;
      --branch)       BRANCH="$2"; shift 2 ;;
      --prd)          PRD_FILE="$2"; shift 2 ;;
      --adapter)      ADAPTER="$2"; shift 2 ;;
      --disable-1m)   DISABLE_1M=true; shift ;;
      --skip-init)    SKIP_INIT=true; shift ;;
      --resume)       RESUME_DIR="$2"; shift 2 ;;
      --dry-run)      DRY_RUN=true; shift ;;
      --help)         show_help; exit 0 ;;
      *)              echo "알 수 없는 옵션: $1" >&2; exit 1 ;;
    esac
  done
}

show_help() {
  sed -n '2,20p' "$0" | sed 's/^# //' | sed 's/^#//'
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

  # PRD 파일 기본값
  if [ -z "$PRD_FILE" ]; then
    PRD_FILE="${PROJECT_DIR}/prd.json"
  fi

  # 어댑터 로드
  load_adapter

  # JSONL 로거 초기화
  init_jsonl "$LOG_DIR"

  echo "프로젝트: $PROJECT_DIR"
  echo "어댑터: $ADAPTER"
  echo "브랜치: $BRANCH"
  echo "최대 반복: $MAX_ITERATIONS"
  echo "반복당 턴: $MAX_TURNS"
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

# ── 초기화 에이전트 실행 ──
run_init_agent() {
  if [ "$SKIP_INIT" = true ]; then
    emit_jsonl "INIT_SKIP" "초기화 건너뜀"
    return 0
  fi

  emit_jsonl "INIT_START" "초기화 에이전트 실행"
  echo "[$(date '+%H:%M:%S')] 초기화 에이전트 실행..." >&2

  run_ai_agent "${SCRIPT_DIR}/prompts/init.md" "${LOG_DIR}/init.json"
  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    emit_jsonl "INIT_FAIL" "초기화 실패" "exit_code=${exit_code}"
    return 1
  fi

  emit_jsonl "INIT_DONE" "초기화 완료"
  return 0
}

# ── 메인 코딩 루프 ──
run_coding_loop() {
  local start_iteration=0

  # resume 모드: 마지막 완료 iteration부터 이어서
  if [ -n "$RESUME_DIR" ]; then
    start_iteration=$(get_last_iteration "$LOG_DIR")
    emit_jsonl "RESUME" "세션 재개" "from_iteration=${start_iteration}"
    echo "[$(date '+%H:%M:%S')] 반복 #${start_iteration}부터 재개" >&2
  fi

  local iteration=$start_iteration
  local backoff_attempt=0

  while [ $iteration -lt $MAX_ITERATIONS ]; do
    iteration=$((iteration + 1))
    local iter_log="${LOG_DIR}/iteration-${iteration}.json"

    emit_jsonl "ITERATION_START" "반복 #${iteration}/${MAX_ITERATIONS}" "iteration=${iteration}"
    echo "[$(date '+%H:%M:%S')] === 반복 #${iteration}/${MAX_ITERATIONS} ===" >&2

    # ── 코딩 프롬프트 + 실패 기록 주입 ──
    local augmented_prompt="${LOG_DIR}/coding-augmented.md"
    cat "${SCRIPT_DIR}/prompts/coding.md" > "$augmented_prompt"
    failure_inject_prompt 5 "$PROJECT_DIR" >> "$augmented_prompt"

    run_ai_agent "$augmented_prompt" "$iter_log"
    local exit_code=$?

    # ── rate limit 감지 ──
    if [ -f "$iter_log" ] && detect_rate_limit "$iter_log"; then
      backoff_attempt=$((backoff_attempt + 1))
      emit_jsonl "RATE_LIMIT" "Rate limit 감지" "attempt=${backoff_attempt}"
      wait_with_backoff "$backoff_attempt" "${LOG_DIR}/loop.log"
      iteration=$((iteration - 1))  # 이 반복은 카운트하지 않음
      continue
    fi

    # ── provider 장애 감지 ──
    if [ -f "$iter_log" ] && detect_provider_error "$iter_log"; then
      emit_jsonl "PROVIDER_ERROR" "Provider 장애 감지. 10분 대기"
      sleep 600
      iteration=$((iteration - 1))
      continue
    fi

    # rate limit 아니면 backoff 리셋
    backoff_attempt=0

    # ── 순환 에러 감지 ──
    if detect_stagnation "$LOG_DIR" "$iteration" 3; then
      emit_jsonl "STAGNATION" "순환 에러 감지 — 루프 중단" "iteration=${iteration}"
      echo "[반복 #${iteration}] 순환 에러 감지 — 루프 중단" >&2
      finalize_session "$LOG_DIR" "stagnated"
      break
    fi

    # ── 커밋 없는 시간 감지 ──
    if detect_no_commit 30; then
      emit_jsonl "NO_COMMIT_TIMEOUT" "30분간 커밋 없음 — 루프 중단" "iteration=${iteration}"
      echo "[반복 #${iteration}] 30분간 커밋 없음 — 루프 중단" >&2
      finalize_session "$LOG_DIR" "stagnated"
      break
    fi

    emit_jsonl "ITERATION_END" "반복 #${iteration} 완료" "iteration=${iteration}" "exit_code=${exit_code}"

    # ── 완료 확인 ──
    if [ -f "$PRD_FILE" ] && check_all_passing "$PRD_FILE"; then
      emit_jsonl "ALL_PASSING" "모든 기능 통과 — 루프 완료" "iteration=${iteration}"
      echo "[반복 #${iteration}] 모든 기능 통과 — 루프 완료!" >&2
      finalize_session "$LOG_DIR" "completed"
      break
    fi

    # 짧은 대기 (API 속도 제한 대비)
    sleep 5
  done

  # max iterations 도달 시
  if [ $iteration -ge $MAX_ITERATIONS ]; then
    emit_jsonl "MAX_ITERATIONS" "최대 반복 도달" "iteration=${iteration}"
    finalize_session "$LOG_DIR" "max_iterations"
  fi

  echo "$iteration"
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
    echo "## PRD 상태"
    if [ -f "$PRD_FILE" ]; then
      local passing failing
      passing=$(jq '[.features[] | select(.status == "passing")] | length' "$PRD_FILE" 2>/dev/null || echo "?")
      failing=$(jq '[.features[] | select(.status != "passing")] | length' "$PRD_FILE" 2>/dev/null || echo "?")
      echo "- 통과: $passing"
      echo "- 실패: $failing"
    else
      echo "(prd.json 없음)"
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

  setup_branch

  # Phase 1: 초기화
  if ! run_init_agent; then
    emit_jsonl "ABORT" "초기화 실패로 중단"
    finalize_session "$LOG_DIR" "init_failed"
    echo "초기화 실패. 중단합니다." >&2
    exit 1
  fi

  # Phase 2: 코딩 루프
  local total_iterations
  total_iterations=$(run_coding_loop)

  # Phase 3: 요약
  generate_summary "$total_iterations"

  echo "=== Ralph Loop 종료 ==="
  echo "재개: ralph-loop --resume $LOG_DIR"
}

main "$@"
