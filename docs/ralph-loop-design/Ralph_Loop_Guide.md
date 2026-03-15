# Ralph Loop 완전 가이드

## 1. Ralph Loop가 뭔가?

### 한 줄 요약
> **"AI가 한 번 답하고 끝내지 않고, 목표 달성할 때까지 최대 5번 반복하게 강제하는 시스템"**

### 비유로 설명

일반적인 AI 사용:
```
나: "로그인 기능 만들어줘"
AI: "만들었습니다!" (끝)
→ 테스트 안 돌려봄, 버그 있을 수도, 코드 정리 안 됨
```

Ralph Loop 적용 후:
```
나: "로그인 기능 만들어줘"
AI: [1회차] 초안 작성 → 커밋
AI: [2회차] 테스트 추가 → 커밋
AI: [3회차] 버그 수정 → 커밋
AI: [4회차] 코드 정리 → 커밋
AI: "완료!" (모든 테스트 통과 확인 후)
```

### 핵심 원리

```
                    ┌──────────────┐
                    │  사용자 요청  │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  Iteration 1  │──→ 커밋
                    └──────┬───────┘
                           │
                     완료? ◆ NO
                           │
                    ┌──────▼───────┐
                    │  Iteration 2  │──→ 커밋
                    └──────┬───────┘
                           │
                     완료? ◆ NO
                           │
                    ┌──────▼───────┐
                    │  Iteration 3  │──→ 커밋
                    └──────┬───────┘
                           │
                     완료? ◆ YES
                           │
                    ┌──────▼───────┐
                    │     종료      │
                    └──────────────┘
```

---

## 2. Claude Code Hooks 시스템 이해

Ralph Loop를 이해하려면 먼저 **Claude Code의 Hooks**를 알아야 합니다.

### Hooks란?

Claude Code가 특정 **이벤트**를 발생시킬 때 자동으로 실행되는 **셸 스크립트**입니다.
게임의 "트리거"와 같습니다.

```
이벤트 발생 → 훅 스크립트 실행 → 결과에 따라 동작 변경
```

### 사용하는 이벤트 4가지

| 이벤트 | 언제 발생? | 우리가 하는 일 |
|--------|-----------|---------------|
| **UserPromptSubmit** | 사용자가 메시지를 보낼 때 | Ralph Loop 초기화 + 규칙 주입 |
| **PreToolUse** | Claude가 도구를 쓰기 직전 | 커밋 메시지 형식 검증 |
| **Stop** | Claude가 응답을 끝내려 할 때 | **종료를 차단하고 루프 계속** |
| *(PostToolUse)* | *도구 사용 직후* | *(기존: prettier, console.log 체크)* |

### 훅의 종료 코드 (exit code)

```
exit 0  →  "통과" (정상 진행)
exit 2  →  "차단" (해당 동작을 막음)
```

### 훅의 통신 방식

```
                stdin (JSON)
    Claude ──────────────────→ 훅 스크립트
                                    │
              stdout (JSON)         │
    Claude ←────────────────── 결과 반환
                                    │
              stderr (텍스트)        │
    사용자 ←────────────────── 경고/정보 메시지
```

- **stdin**: Claude가 훅에게 JSON 데이터를 보냄
- **stdout**: 훅이 Claude에게 JSON 결과를 돌려줌
- **stderr**: 사용자 화면에 표시되는 메시지 (`>&2`로 출력)

---

## 3. 전체 작동 순서 (타임라인)

```
시간 ──────────────────────────────────────────────────────→

[사용자]         [UserPromptSubmit 훅]     [Claude]          [PreToolUse 훅]      [Stop 훅]
   │                    │                    │                    │                  │
   │  "로그인 만들어"    │                    │                    │                  │
   ├───────────────────→│                    │                    │                  │
   │                    │                    │                    │                  │
   │              ① 상태파일 생성            │                    │                  │
   │              ② 규칙 주입               │                    │                  │
   │                    │                    │                    │                  │
   │                    ├───────────────────→│                    │                  │
   │                    │  "iteration 1/5    │                    │                  │
   │                    │   규칙: ..."        │                    │                  │
   │                    │                    │                    │                  │
   │                    │                    │  코드 작성...       │                  │
   │                    │                    │                    │                  │
   │                    │                    │  git commit 시도   │                  │
   │                    │                    ├───────────────────→│                  │
   │                    │                    │                    │                  │
   │                    │                    │              ③ 형식 검증              │
   │                    │                    │              "ralph(1/5) 맞나?"       │
   │                    │                    │                    │                  │
   │                    │                    │←───────────────────┤                  │
   │                    │                    │                    │                  │
   │                    │                    │  작업 완료 시도     │                  │
   │                    │                    ├──────────────────────────────────────→│
   │                    │                    │                    │                  │
   │                    │                    │                    │           ④ 완료 확인
   │                    │                    │                    │           "RALPH_DONE 있나?"
   │                    │                    │                    │                  │
   │                    │                    │                    │           ⑤ 없으면 → 차단!
   │                    │                    │                    │           "다음 iteration"
   │                    │                    │←─────────────────────────────────────┤
   │                    │                    │                    │                  │
   │                    │                    │  [iteration 2 시작]│                  │
   │                    │                    │  테스트 추가...     │                  │
   │                    │                    │  ...               │                  │
   │                    │                    │                    │                  │
   │                    │                    │  <promise>RALPH_DONE</promise> 출력   │
   │                    │                    ├──────────────────────────────────────→│
   │                    │                    │                    │                  │
   │                    │                    │                    │           ⑥ 있으면 → 통과!
   │                    │                    │                    │           상태파일 삭제
   │                    │                    │                    │                  │
   │  결과 표시         │                    │←─────────────────────────────────────┤
   │←───────────────────────────────────────┤                    │                  │
```

---

## 4. 파일 구조

```
~/.claude/
├── settings.json                          ← 훅 등록 (어떤 이벤트에 어떤 스크립트 실행할지)
├── CLAUDE.md                              ← 행동 규칙 (원칙, 커밋 형식 등)
└── hooks/
    ├── stop-console-check.sh              ← 기존: console.log 경고
    └── ralph-loop/
        ├── prompt-init.sh                 ← 훅1: 초기화 + 규칙 주입
        ├── stop-loop.sh                   ← 훅2: 루프 제어 (핵심!)
        └── commit-check.sh               ← 훅3: 커밋 형식 검증

프로젝트/
└── .claude/
    └── ralph-auto-loop.json               ← 런타임 상태 파일 (자동 생성/삭제)
```

---

## 5. 각 스크립트 상세 설명

---

### 5-1. prompt-init.sh (UserPromptSubmit)

**역할**: "모든 대화의 시작점. Ralph Loop를 자동으로 켜는 스위치"

**언제 실행?**: 사용자가 메시지를 보낼 때마다

```bash
set -euo pipefail     # 에러 발생 시 즉시 중단 (안전장치)
input=$(cat)           # Claude가 보낸 JSON을 stdin에서 읽음
```

#### 단계 1: 플러그인 충돌 방지

```bash
if [ -f "${STATE_DIR}/ralph-loop.local.md" ]; then
  exit 0
fi
```

기존 `/ralph-loop` 플러그인이 이미 활성화되어 있으면, 이 훅은 아무것도 안 하고 빠집니다.
두 시스템이 동시에 돌면 충돌하니까 **양보**하는 것.

#### 단계 2: 상태 파일 생성

```bash
if [ ! -f "$STATE_FILE" ]; then
  jq -n \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      "iteration": 1,            # 현재 1회차
      "max_iter": 5,             # 최대 5회
      "stagnation_count": 0,     # 정체 횟수 0
      "stagnation_limit": 3,     # 3회 정체 시 전략 변경
      "completion_promise": "RALPH_DONE",  # 완료 신호
      "started_at": $ts          # 시작 시간
    }' > "$STATE_FILE"
fi
```

**핵심 포인트**: `if [ ! -f "$STATE_FILE" ]` - 파일이 **없을 때만** 생성합니다.
- 첫 메시지 → 파일 생성 (iteration=1)
- 이후 메시지 → 파일 이미 있으므로 건너뜀 (iteration 유지)
- 작업 완료 후 → Stop 훅이 파일 삭제 → 다음 작업에서 새로 생성

이 파일이 **Ralph Loop의 "스위치"** 역할을 합니다:
```
파일 있음 = Ralph Loop 활성
파일 없음 = Ralph Loop 비활성
```

#### 단계 3: 컨텍스트 주입

```bash
jq -n --arg ctx "[Ralph Loop 활성] iteration: 1/5 | 정체: 0/3
규칙:
(1) 각 iteration 커밋 필수: ralph(1/5): 한글메시지
(2) Tidy First -> Work -> Right -> Fast 순서 준수
(3) 정체 3회 시 반드시 사용자에게 전략 변경 확인
(4) 작업 완료 시 반드시 <promise>RALPH_DONE</promise> 출력
(5) 완료 조건: 모든 테스트 통과 + 빌드 성공 + 요구사항 충족" \
  '{
    "hookSpecificOutput": {
      "additionalContext": $ctx
    }
  }'
```

`additionalContext`에 넣은 텍스트는 Claude의 **시스템 프롬프트에 추가**됩니다.
즉, Claude는 매번 이 규칙을 "보면서" 작업합니다. 사람에게 포스트잇을 붙여주는 것과 같습니다.

---

### 5-2. stop-loop.sh (Stop) - 핵심 스크립트

**역할**: "Ralph Loop의 심장. Claude의 종료를 가로채서 루프를 강제하는 핵심 메커니즘"

**언제 실행?**: Claude가 응답을 끝내려고 할 때마다

이 스크립트가 **가장 중요**합니다. 이것 없이는 Ralph Loop가 작동하지 않습니다.

#### 단계 1: 루프 활성 여부 확인

```bash
HOOK_INPUT=$(cat)  # Claude가 보낸 정보 (트랜스크립트 경로 포함)

# 플러그인 활성이면 위임
if [ -f ".claude/ralph-loop.local.md" ]; then
  exit 0    # → 종료 허용 (플러그인이 처리)
fi

# 상태 파일 없으면 종료 허용
if [ ! -f "$STATE_FILE" ]; then
  exit 0    # → 종료 허용 (Ralph Loop 비활성)
fi
```

**`exit 0`의 의미**: Stop 훅에서 exit 0은 "종료를 허용한다"는 뜻입니다.

#### 단계 2: 완료 프로미스 확인 (가장 복잡한 부분)

Claude가 마지막으로 출력한 텍스트에서 `<promise>RALPH_DONE</promise>`를 찾습니다.

```bash
# 트랜스크립트 파일 경로 추출
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // ""')
```

Claude Code는 모든 대화를 **JSONL 파일**(한 줄에 하나의 JSON)로 기록합니다:
```jsonl
{"role":"user","message":{"content":[{"type":"text","text":"로그인 만들어"}]}}
{"role":"assistant","message":{"content":[{"type":"text","text":"만들었습니다! <promise>RALPH_DONE</promise>"}]}}
```

이 파일에서 마지막 assistant 메시지를 꺼냅니다:

```bash
# 마지막 assistant 메시지 찾기
LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)

# JSON에서 텍스트만 추출
LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
  .message.content |
  map(select(.type == "text")) |   # text 타입만 선택
  map(.text) |                     # .text 필드만 추출
  join("\n")                       # 여러 개면 줄바꿈으로 합침
')
```

그리고 `<promise>...</promise>` 태그 안의 내용을 추출:

```bash
PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe \
  's/.*?<promise>(.*?)<\/promise>.*/$1/s;   # <promise>와 </promise> 사이 추출
   s/^\s+|\s+$//g;                          # 앞뒤 공백 제거
   s/\s+/ /g'                               # 연속 공백을 하나로
)
```

**왜 perl?**: 정규식이 여러 줄에 걸칠 수 있어서. `sed`나 `grep`으로는 어려움.

일치하면 → 종료 허용 + 상태 파일 삭제:

```bash
if [ "$PROMISE_TEXT" = "$completion_promise" ]; then
  echo "Ralph Loop 완료: iteration ${iteration}/${max_iter}에서 완료 감지" >&2
  rm -f "$STATE_FILE"    # 상태 파일 삭제 → Ralph Loop 비활성화
  exit 0                 # 종료 허용
fi
```

#### 단계 3: MAX_ITER 확인

```bash
if [ "$iteration" -ge "$max_iter" ]; then
  echo "Ralph Loop: MAX_ITER(${max_iter}) 도달. 루프를 종료합니다." >&2
  rm -f "$STATE_FILE"
  exit 0   # 강제 종료 (무한 루프 방지 안전장치)
fi
```

5회 반복했으면 완료 여부와 상관없이 **강제 종료**. 비용 폭주를 막는 안전장치.

#### 단계 4: 루프 계속 (핵심 중의 핵심)

완료도 아니고 MAX_ITER도 아닌 경우 → **종료를 차단하고 다음 iteration으로**:

```bash
# iteration 카운터 증가
next_iter=$((iteration + 1))
jq --argjson iter "$next_iter" '.iteration = $iter' "$STATE_FILE" \
  > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
```

임시 파일에 쓰고 mv하는 이유: **원자적 쓰기**. 쓰는 도중 읽히면 깨질 수 있으므로.

```bash
# 종료를 차단하는 JSON 출력
jq -n \
  --arg prompt "Ralph Loop 계속: 이전 iteration 결과를 확인하고..." \
  --arg msg "Ralph Loop iteration 2/5 | ..." \
  '{
    "decision": "block",     # ← 핵심! "종료하지 마라"
    "reason": $prompt,       # ← Claude에게 다시 보내는 프롬프트
    "systemMessage": $msg    # ← 상태 표시줄에 보이는 메시지
  }'
```

**`"decision": "block"`이 마법의 열쇠입니다.**

이 JSON이 stdout으로 나가면 Claude Code는:
1. 종료를 취소하고
2. `reason`의 내용을 **새로운 사용자 프롬프트로** Claude에게 다시 보냅니다
3. Claude는 이전 작업의 맥락을 기억한 채로 다음 iteration을 수행합니다

```
Claude 응답 끝 → Stop 이벤트 발생
                      │
                 stop-loop.sh 실행
                      │
               ┌──────┴──────┐
               │ 완료 신호?   │
               └──────┬──────┘
                      │
           YES ←──────┴──────→ NO
            │                    │
       exit 0               "decision":"block"
       (종료 허용)            (종료 차단)
                                │
                          Claude에게 다시:
                          "계속 작업하세요"
                                │
                          Iteration N+1 시작
```

---

### 5-3. commit-check.sh (PreToolUse)

**역할**: "커밋할 때 메시지 형식을 확인하는 검문소"

**언제 실행?**: Claude가 Bash 도구를 사용하기 직전

```bash
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
```

Claude가 `Bash` 도구로 실행하려는 명령어를 추출합니다.

```bash
# git commit이 아니면 → 그냥 통과
if ! printf '%s' "$cmd" | grep -qE 'git commit'; then
  printf '%s' "$input"    # 입력을 그대로 출력 (통과)
  exit 0
fi
```

git commit이면 형식 검증:

```bash
if [ -f "$STATE_FILE" ]; then
  # ralph(N/N) 패턴이 없으면 경고
  if ! printf '%s' "$cmd" | grep -qE 'ralph\([0-9]+/[0-9]+\)'; then
    echo "[Ralph Loop] 커밋 메시지에 ralph(1/5) 형식을 사용하세요." >&2
    echo "[Ralph Loop] 예시: ralph(1/5): 기능 초안 작성" >&2
  fi
fi

printf '%s' "$input"   # 경고만 하고 통과시킴 (차단하지 않음)
exit 0
```

**차단하지 않는 이유**: `exit 2`로 차단하면 커밋 자체를 못 하게 됩니다.
경고만 주고 Claude가 스스로 고치도록 유도합니다.

---

### 5-4. stop-console-check.sh (기존 Stop 훅)

**역할**: Ralph Loop와는 별개. 세션 종료 시 `console.log` 잔재를 경고

```bash
# git 저장소인지 확인
if git rev-parse --git-dir > /dev/null 2>&1; then
  # 수정된 JS/TS 파일 목록
  modified_files=$(git diff --name-only HEAD | grep -E '\.(ts|tsx|js|jsx)$')

  # 각 파일에서 console.log 검색
  while IFS= read -r file; do
    if grep -q "console\.log" "$file"; then
      echo "[훅] 경고: console.log 발견 - $file" >&2
    fi
  done <<< "$modified_files"
fi

printf '%s' "$input"   # 항상 통과 (경고만)
```

이 훅은 항상 `printf '%s' "$input"`으로 끝나므로 종료를 차단하지 않습니다.
stop-loop.sh와 **순서대로** 실행됩니다:

```
Stop 이벤트 →  ① stop-console-check.sh (경고만)
              ② stop-loop.sh (차단 여부 결정)
```

---

## 6. settings.json 구조 설명

```json
{
  "hooks": {
    "UserPromptSubmit": [           // 사용자 메시지 전송 시
      {
        "hooks": [{
          "command": ".../prompt-init.sh",
          "timeout": 10              // 10초 안에 끝나야 함
        }]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",          // Bash 도구 사용 시에만
        "hooks": [{ ... git push 차단 ... }]
      },
      {
        "matcher": "Bash",          // Bash 도구 사용 시에만
        "hooks": [{
          "command": ".../commit-check.sh"
        }]
      },
      {
        "matcher": "Write",         // Write 도구 사용 시에만
        "hooks": [{ ... .md 파일 차단 ... }]
      }
    ],
    "Stop": [
      {
        "matcher": "*",             // 모든 Stop 이벤트
        "hooks": [{ "command": ".../stop-console-check.sh" }]
      },
      {
        "matcher": "*",             // 모든 Stop 이벤트
        "hooks": [{ "command": ".../stop-loop.sh" }]
      }
    ]
  }
}
```

**`matcher`**: 어떤 도구에 반응할지 필터링
- `"Bash"` → Bash 도구만
- `"Write"` → Write 도구만
- `"*"` → 모든 경우

**`timeout`**: 훅이 무한 루프에 빠지는 것 방지 (초 단위)

---

## 7. 상태 파일의 생명주기

```
[탄생]
사용자 첫 메시지 → prompt-init.sh가 생성
  .claude/ralph-auto-loop.json
  { "iteration": 1, "max_iter": 5, ... }

[성장]
Stop 이벤트 → stop-loop.sh가 iteration 증가
  { "iteration": 2, "max_iter": 5, ... }
  { "iteration": 3, "max_iter": 5, ... }

[죽음 - 정상 완료]
Claude가 <promise>RALPH_DONE</promise> 출력
  → stop-loop.sh가 감지 → rm -f (파일 삭제)

[죽음 - 강제 종료]
iteration이 5에 도달
  → stop-loop.sh가 감지 → rm -f (파일 삭제)
```

---

## 8. 종료 조건 정리

Stop 훅이 **종료를 허용**하는 3가지 경우:

| 조건 | 코드 | 의미 |
|------|------|------|
| 상태 파일 없음 | `[ ! -f "$STATE_FILE" ]` → `exit 0` | Ralph Loop 비활성 |
| 완료 프로미스 감지 | `"RALPH_DONE"` 발견 → `exit 0` | 작업 정상 완료 |
| MAX_ITER 도달 | `iteration >= 5` → `exit 0` | 안전장치 (무한 루프 방지) |

그 외 모든 경우 → **`"decision": "block"`** → 루프 계속

---

## 9. 안전장치 요약

| 장치 | 위치 | 역할 |
|------|------|------|
| **MAX_ITER = 5** | stop-loop.sh:57 | 5회 넘으면 무조건 종료 |
| **timeout: 15** | settings.json | 훅이 15초 넘으면 강제 종료 |
| **플러그인 충돌 방지** | prompt-init.sh:17, stop-loop.sh:13 | 기존 플러그인과 동시 실행 방지 |
| **원자적 파일 쓰기** | stop-loop.sh:65 | `.tmp` → `mv`로 파일 깨짐 방지 |
| **set -euo pipefail** | 모든 스크립트 첫 줄 | 에러 시 즉시 중단 |

---

## 10. CLAUDE.md와의 관계

```
CLAUDE.md (규칙서)           hooks (강제 장치)
────────────────            ────────────────
"Ralph Loop로 작업해라"  ←→  상태 파일 자동 생성
"커밋 형식: ralph(N/5)"  ←→  commit-check.sh가 검증
"정체 시 물어봐라"       ←→  additionalContext로 주입
"Tidy First 원칙"        ←→  additionalContext로 주입
"MAX_ITER = 5"           ←→  stop-loop.sh가 강제
```

CLAUDE.md는 **"이렇게 해라"라는 지침**이고,
hooks는 **"안 하면 못 지나간다"는 강제 장치**입니다.

둘이 합쳐져서 Ralph Loop가 완성됩니다.

---

## 11. 핵심 3문장 요약

1. **"AI가 응답을 끝내려 할 때 Stop 훅이 가로채서, 아직 끝나지 않았으면 다시 작업하게 만든다"**

2. **"매번 반복할 때마다 커밋을 남기기 때문에, 어떤 과정을 거쳤는지 git 히스토리에 다 남는다"**

3. **"5회 반복이 안전 상한선이고, 진짜 끝났으면 `<promise>RALPH_DONE</promise>`를 출력해야만 빠져나올 수 있다"**
