---
name: refine
description: "Refine Loop 제어 (세션 내 반복 수렴). /refine [on|off|status] 또는 /refine \"프롬프트\" --max-iter N --budget N"
user_invocable: true
---

# Refine Loop

세션 내 반복 수렴 도구입니다. 프롬프트 리플레이 + 구조화된 iteration 관리를 제공합니다.
한 작업을 파고들어 수렴시킬 때 사용합니다 (Make it Work → Right → Fast).

## 호출 모드

| 명령 | 동작 |
|------|------|
| `/refine` | 토글 (ON/OFF) |
| `/refine on` | 기본값으로 활성화 (max_iter=10) |
| `/refine off` | 비활성화 |
| `/refine "프롬프트"` | 프롬프트+파라미터로 시작 |
| `/refine status` | 현재 상태 표시 |

## 파라미터 (프롬프트 모드)

- `--max-iter N` : 최대 반복 횟수 (기본: 10)
- `--budget N` : 토큰 비용 예산 USD (기본: 0=무제한)
- `--timeout N` : 시간 예산 분 (기본: 0=무제한)
- `--promise TEXT` : 완료 프로미스 (기본: REFINE_DONE)

## 실행 방법

### Step 1: 인자 파싱 및 상태 관리

Bash로 다음 스크립트를 실행하세요:

```bash
STATE_FILE=".claude/refine-loop.local.md"
STATE_JSON=".claude/refine-state.json"
LEGACY_FILE=".claude/ralph-loop.local.md"
mkdir -p .claude

RAW_ARGS="__ARGS__"

# ── status 명령 ──
if [ "$RAW_ARGS" = "status" ]; then
  if [ -f "$STATE_FILE" ]; then
    echo "=== Refine Loop 상태 ==="
    sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE"
    if [ -f "$STATE_JSON" ]; then
      echo ""
      echo "=== Iteration 로그 ==="
      jq -r '.iteration_log[-3:][] | "\(.timestamp) iter:\(.iteration) phase:\(.phase) stag:\(.stagnation) cost:\(.cost_usd) strategy:\(.strategy)"' "$STATE_JSON" 2>/dev/null || echo "(로그 없음)"
    fi
  else
    echo "Refine Loop 비활성"
  fi
  exit 0
fi

# ── off 명령 ──
if [ "$RAW_ARGS" = "off" ]; then
  rm -f "$STATE_FILE" "$STATE_JSON" "$LEGACY_FILE" ".claude/ralph-auto-loop.json" ".claude/ralph-skip-current"
  echo "Refine Loop OFF"
  exit 0
fi

# ── on 명령 (프롬프트 없이) ──
if [ "$RAW_ARGS" = "on" ] || [ -z "$RAW_ARGS" ]; then
  if [ -f "$STATE_FILE" ] && [ "$RAW_ARGS" != "on" ]; then
    # 토글: 이미 활성이면 OFF
    rm -f "$STATE_FILE" "$STATE_JSON"
    echo "Refine Loop OFF"
    exit 0
  fi
  # 레거시 파일 정리 (ralph → refine 마이그레이션)
  rm -f "$LEGACY_FILE" ".claude/ralph-auto-loop.json" ".claude/ralph-skip-current"
  TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  cat > "$STATE_FILE" <<STATEEOF
---
active: true
iteration: 1
max_iterations: 10
completion_promise: "REFINE_DONE"
started_at: "${TS}"
version: 2
phase: "plan"
stagnation_count: 0
stagnation_limit: 3
session_timeout_minutes: 30
last_error_hash: ""
repeated_error_count: 0
last_files_changed: 0
total_cost_usd: 0.0
token_budget_usd: 0
time_budget_minutes: 0
current_strategy: "default"
---

(프롬프트 없이 활성화됨)
완료 시 <promise>REFINE_DONE</promise>를 출력하세요.
STATEEOF
  echo '{"iteration_log":[],"strategy_changes":[]}' > "$STATE_JSON"
  echo "Refine Loop ON (1/10)"
  exit 0
fi

# ── 프롬프트 모드: 인자 파싱 ──
MAX_ITER=10
BUDGET=0
TIMEOUT=0
PROMISE="REFINE_DONE"
PROMPT=""

# 따옴표로 감싼 프롬프트 추출
if echo "$RAW_ARGS" | grep -qE '^"'; then
  PROMPT=$(echo "$RAW_ARGS" | sed 's/^"\(.*\)".*/\1/')
  REMAINING=$(echo "$RAW_ARGS" | sed 's/^"[^"]*" *//')
elif echo "$RAW_ARGS" | grep -qE "^'"; then
  PROMPT=$(echo "$RAW_ARGS" | sed "s/^'\(.*\)'.*/\1/")
  REMAINING=$(echo "$RAW_ARGS" | sed "s/^'[^']*' *//")
else
  PROMPT="$RAW_ARGS"
  REMAINING=""
fi

# 옵션 파싱
while [ -n "$REMAINING" ]; do
  case "$REMAINING" in
    --max-iter\ *)
      MAX_ITER=$(echo "$REMAINING" | sed 's/--max-iter \([0-9]*\).*/\1/')
      REMAINING=$(echo "$REMAINING" | sed 's/--max-iter [0-9]* *//')
      ;;
    --budget\ *)
      BUDGET=$(echo "$REMAINING" | sed 's/--budget \([0-9.]*\).*/\1/')
      REMAINING=$(echo "$REMAINING" | sed 's/--budget [0-9.]* *//')
      ;;
    --timeout\ *)
      TIMEOUT=$(echo "$REMAINING" | sed 's/--timeout \([0-9]*\).*/\1/')
      REMAINING=$(echo "$REMAINING" | sed 's/--timeout [0-9]* *//')
      ;;
    --promise\ *)
      PROMISE=$(echo "$REMAINING" | sed 's/--promise \([^ ]*\).*/\1/')
      REMAINING=$(echo "$REMAINING" | sed 's/--promise [^ ]* *//')
      ;;
    *)
      break
      ;;
  esac
done

rm -f "$LEGACY_FILE" ".claude/ralph-auto-loop.json" ".claude/ralph-skip-current"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > "$STATE_FILE" <<STATEEOF
---
active: true
iteration: 1
max_iterations: ${MAX_ITER}
completion_promise: "${PROMISE}"
started_at: "${TS}"
version: 2
phase: "plan"
stagnation_count: 0
stagnation_limit: 3
session_timeout_minutes: 30
last_error_hash: ""
repeated_error_count: 0
last_files_changed: 0
total_cost_usd: 0.0
token_budget_usd: ${BUDGET}
time_budget_minutes: ${TIMEOUT}
current_strategy: "default"
---

${PROMPT}
완료 시 <promise>${PROMISE}</promise>를 출력하세요.
STATEEOF
echo '{"iteration_log":[],"strategy_changes":[]}' > "$STATE_JSON"
echo "Refine Loop ON (1/${MAX_ITER}) | 예산: \$${BUDGET} | 타임아웃: ${TIMEOUT}분"
echo "프롬프트: ${PROMPT}"
```

`__ARGS__`를 실제 사용자 인자로 치환하세요.

### Step 2: 결과에 따라 응답

- **ON (프롬프트 없이)**: "Refine Loop가 활성화되었습니다 (1/10). 작업을 시작하세요. 각 iteration마다 커밋하며, 완료 시 `<promise>REFINE_DONE</promise>`를 출력합니다."
- **ON (프롬프트)**: "Refine Loop가 활성화되었습니다. 프롬프트를 기반으로 작업을 시작합니다." 그리고 즉시 프롬프트 내용을 수행하기 시작하세요.
- **OFF**: "Refine Loop가 비활성화되었습니다."
- **status**: 상태 정보를 그대로 사용자에게 표시하세요.

### Step 3: Refine Loop 활성 상태에서의 규칙

Refine Loop가 ON이면 다음 규칙을 따르세요:

1. **각 iteration마다 커밋 필수**: `refine(N/MAX): 한글 메시지`
2. **4단계 iteration**: Plan → Execute → Verify → Record
3. **Tidy First → Work → Right → Fast** 순서 준수
4. **정체 3회 시** 반드시 사용자에게 전략 변경 확인
5. **작업 완료 시** 반드시 `<promise>REFINE_DONE</promise>` 출력
6. **완료 조건**: 모든 테스트 통과 + 빌드 성공 + 요구사항 충족

## Gotchas

> Claude가 Refine Loop에서 자주 실수하는 것. 실패할 때마다 한 줄 추가.

1. **조기 완료 선언** — 테스트 1개 통과했다고 REFINE_DONE 출력. 전체 테스트 스위트 + 빌드까지 확인해야 완료.
2. **동일 전략 반복** — 실패한 접근을 미세 수정만으로 재시도. stagnation 감지 시 근본적으로 다른 전략을 시도해야 한다.
3. **Tidy와 기능을 한 커밋에 섞기** — 정리 커밋과 기능 커밋은 반드시 분리.
4. **Plan 단계 생략** — 바로 코딩에 들어가는 경향. 각 iteration에서 Plan을 먼저 하고 방향을 잡아야 한다.
