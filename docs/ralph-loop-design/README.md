# Ralph Loop & Refine

밤샘 무인 자율 코딩 오케스트레이터(Ralph Loop)와 세션 내 반복 수렴 도구(Refine).

## 개요

| 도구 | 용도 | 실행 환경 | 컨텍스트 |
|------|------|----------|---------|
| **Ralph Loop** | 밤샘 무인 코딩 | bash + `claude -p` | 매 반복 fresh |
| **Refine** | 세션 내 수렴 | CC Stop Hook | 누적 (1M까지) |

## Ralph Loop

Geoffrey Huntley 원조 패턴: bash에서 `claude -p`를 반복 호출, 매번 fresh context, 파일시스템으로 상태 인수인계.

### 설치

```bash
bash deploy.sh
```

배포 대상:
- `~/.claude/ralph-loop/` — 오케스트레이터
- `~/bin/ralph-loop` — CLI 심링크

### 사용법

```bash
# 기본 실행
ralph-loop --project-dir /path/to/project

# 옵션
ralph-loop --project-dir /path/to/project \
  --max-iterations 20 \
  --max-turns 30 \
  --model sonnet \
  --branch ralph/feature-x \
  --disable-1m

# 중단된 세션 재개
ralph-loop --resume /path/to/project/.ralph-logs/20260315-230000

# 흐름 확인 (API 호출 없음)
ralph-loop --project-dir /path/to/project --dry-run
```

### 아키텍처

```
┌─────────────────────────────────────────────┐
│  ralph-loop.sh (오케스트레이터)                │
│                                             │
│  1. init 에이전트 → prd.json 생성             │
│  2. coding 에이전트 × N (반복)                │
│     ├─ prd.json에서 failing 기능 선택          │
│     ├─ 구현 + 테스트                          │
│     ├─ 커밋 + prd.json 업데이트               │
│     └─ 모든 기능 passing → 종료               │
│  3. 요약 생성                                │
│                                             │
│  안전장치:                                    │
│  ├─ exponential backoff (rate limit)         │
│  ├─ stagnation 감지 (순환 에러)               │
│  ├─ no-commit timeout (30분)                 │
│  └─ gate 검증 (lint/test)                    │
└─────────────────────────────────────────────┘
```

### 로그 구조

```
.ralph-logs/20260315-230000/
├── session.json        # 세션 메타데이터 (resume용)
├── progress.jsonl      # 구조화 이벤트 로그
├── init.json           # init 에이전트 출력
├── iteration-1.json    # 반복별 claude 출력
├── iteration-2.json
├── ...
└── summary.md          # 실행 요약
```

### JSONL 이벤트

| step | 설명 |
|------|------|
| `INIT_START` / `INIT_DONE` | 초기화 에이전트 |
| `ITERATION_START` / `ITERATION_END` | 코딩 반복 |
| `CLAUDE_CALL` | claude -p 호출 (토큰 사용량 포함) |
| `RATE_LIMIT` | rate limit 감지 |
| `STAGNATION` | 순환 에러 감지 |
| `ALL_PASSING` | 모든 기능 통과 |
| `RESUME` | 세션 재개 |

## Refine

CC 세션 내부에서 Stop Hook으로 반복 수렴. 기존 `/ralph` 스킬의 후속.

### 사용법 (CC 세션 내)

```
/refine "API 응답 캐싱 구현" --max-iter 5
/refine status
/refine off
```

### 구성

- `~/.claude/skills/refine/SKILL.md` — 스킬 정의
- `~/.claude/hooks/refine/` — 7개 훅 파일

## 테스트

```bash
bash tests/test-runner.sh
```

## 파일 구조

```
src/
├── ralph-loop/              # bash 오케스트레이터
│   ├── ralph-loop.sh        # 메인 스크립트
│   ├── lib/
│   │   ├── backoff.sh       # rate limit + backoff
│   │   ├── stagnation.sh    # 순환 감지
│   │   ├── gate.sh          # 검증 게이트
│   │   └── jsonl.sh         # JSONL 구조화 로깅
│   ├── prompts/
│   │   ├── init.md          # init 에이전트 프롬프트
│   │   └── coding.md        # coding 에이전트 프롬프트
│   └── templates/
│       ├── prd.json         # PRD 템플릿
│       └── progress.txt     # 진행 기록 템플릿
├── refine/                  # 세션 내 수렴 도구
│   ├── SKILL.md             # 스킬 정의
│   └── hooks/               # Stop/PreToolUse/UserPromptSubmit 훅
tests/
├── test-runner.sh           # 테스트 러너
├── test-backoff.sh          # backoff 단위 테스트
├── test-stagnation.sh       # stagnation 단위 테스트
├── test-gate.sh             # gate 단위 테스트
├── test-jsonl.sh            # JSONL 단위 테스트
└── test-dry-run.sh          # dry-run 통합 테스트
deploy.sh                    # ~/.claude/로 배포
```
