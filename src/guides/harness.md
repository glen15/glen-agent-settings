---
name: harness
description: "하네스 엔지니어링 운영 가이드. 에이전트/스킬/MCP/Hook 선택 매트릭스와 UI 파이프라인(Magic MCP + ui-ux-pro-max 조합) 포함. 모든 프로젝트에 적용."
---

# Harness Engineering Guide

Glen의 Claude Code 하네스 운영 가이드. 에이전트가 **올바른 도구를 올바른 순서로** 사용하도록 안내한다.

## 핵심 원칙

> 에이전트가 어려워하는 지점 = 하네스 개선 신호

1. **모델보다 하네스가 성능을 결정한다** — 도구·제약·피드백·컨텍스트가 결과를 좌우
2. **Skill-First** — Skill이 작업의 중심. CLI·Script·MCP·LLM 판단을 하나로 묶는 오케스트레이터
3. **Code-First (Skill 내부 원칙)** — Skill 안에서 결정론적 단계(CLI/Script)를 최대화하고, LLM 판단은 꼭 필요한 곳에만
4. **한 번에 한 기능** — 컨텍스트 부족과 조기 완료 선언을 방지

---

## 에이전트 선택 매트릭스

| 상황 | 에이전트 | 활성화 |
|------|---------|--------|
| 새 기능 설계 | 내장 Plan 모드 / `architect` | 수동 |
| 새 기능 구현 | `tdd-guide` | 수동 |
| 빌드/타입 에러 | `build-error-resolver` | **자동** (빌드 실패 시) |
| 코드 변경 후 리뷰 | `code-reviewer` | **자동** (코드 변경 후) |
| 보안 민감 코드 | `security-reviewer` | **자동** (인증/API/결제 코드) |
| E2E 테스트 | `e2e-runner` | 수동 |
| 코드 정리/죽은 코드 | `refactor-cleaner` | 수동 |
| 문서/코드맵 업데이트 | `doc-updater` | 수동 |
| 코드베이스 탐색 | `Explore` (subagent_type) | 자동 (3+ 쿼리 필요 시) |

### 에이전트 조합 패턴

```
[새 기능]  /plan (내장 Plan) → tdd-guide → code-reviewer → security-reviewer
[버그 수정] Explore → tdd-guide (재현 테스트 먼저) → build-error-resolver
[리팩토링] refactor-cleaner → code-reviewer → doc-updater
[UI 구현]  /plan (내장 Plan) → UI 파이프라인 (아래 참조) → code-reviewer
```

---

## 스킬 & 커맨드 선택 가이드

### 스킬 (SKILL.md — CLI·Script·판단을 묶는 오케스트레이터)

> Skill은 작업의 중심 단위. CLI 명령, Script, MCP 호출, LLM 판단이 하나의 절차로 통합되어 있다.
> Skill 내부에서 Code-First 적용: 결정론적 단계를 최대화하고, LLM 판단은 꼭 필요한 곳에만.

| 작업 유형 | 스킬 | 호출 |
|----------|------|------|
| 작업 시작 문서 생성 | `/begin` | 수동 |
| 프로젝트 부트스트랩 | `/init` | 수동 |
| 세션 내 반복 수렴 | `/refine` | 수동 |
| 작업 완료 (커밋+태스크) | `/done` | 수동 |
| GTD 태스크 관리 | `/nxt` | 수동 |
| UI/UX 디자인+구현 | `/ui-ux-pro-max` + Magic MCP | 수동 |
| 콘텐츠 생성 | `/create-content` | 수동 |
| 이미지 생성 | `/image` | 수동 |
| 비디오 생성 | `/video` | 수동 |
| NotebookLM 자동화 | `/notebooklm` | 수동 |
| CI/CD 배포 관리 | `/deploy` | 수동 |
| 보안 체크리스트 | `/security-review` | 수동 |
| TDD 워크플로우 | `/tdd-workflow` (참고용) | 수동 |
| 밤샘 무인 코딩 | `ralph-loop` (CLI) | 수동 |

### 커맨드 (commands/*.md — 에이전트 호출 래퍼)

| 작업 유형 | 커맨드 | 에이전트 |
|----------|--------|---------|
| 구현 계획 | `/plan` | architect |
| TDD 테스트 작성 | `/tdd` | tdd-guide |
| 테스트 커버리지 확보 | `/test-coverage` | tdd-guide |
| 빌드 오류 수정 | `/build-fix` | build-error-resolver |
| 코드 리뷰 | `/code-review` | code-reviewer |
| E2E 테스트 | `/e2e` | e2e-runner |
| 리팩토링/정리 | `/refactor-clean` | refactor-cleaner |
| 코드맵 업데이트 | `/update-codemaps` | doc-updater |
| 문서 업데이트 | `/update-docs` | doc-updater |

---

## 도구 선택 원칙: Skill-First + Code-First

> *"Workflows offer **predictability and consistency** for well-defined tasks, whereas agents are the better option when **flexibility and model-driven decision-making** are needed."* — Anthropic, Building Effective Agents

### 두 원칙의 관계

- **Skill-First** = 도구 선택의 중심. 작업이 오면 먼저 Skill을 찾는다.
- **Code-First** = Skill 내부 설계 원칙. Skill 안에서 결정론적 단계를 최대화한다.

```
[Skill-First: 작업의 중심은 Skill]
작업 요청 → 해당 Skill이 있는가?
  ├─ YES → Skill 사용 (내부에서 CLI + Script + MCP + LLM 판단을 오케스트레이션)
  └─ NO  → 외부 데이터 필요? → CLI (gws, gh, browser-use) > MCP (최소 범위)
                             → 자율 판단 필요? → Agent (에이전트)
```

### Skill 내부 신뢰도 계층 (Code-First)

Skill은 단일 계층이 아니라 **여러 신뢰도의 단계를 포함하는 컨테이너**다.

```
[Code-First: Skill 내부에서 결정론적 단계를 최대화]

/done 예시:
  Step 1: git status, git diff           ← 결정론적 (CLI)
  Step 2: git add, git commit            ← 결정론적 (CLI)
  Step 3: 커밋 메시지 작성, 태스크 매칭     ← LLM 판단 (꼭 필요한 곳)
  Step 4: nxtflow 태스크 생성/완료          ← 외부 서비스 (MCP)
```

| 단계 유형 | 신뢰도 | Skill 내 역할 | 진화 방향 |
|----------|--------|-------------|----------|
| CLI / Script | **결정론적** — 매번 동일 | 실행의 뼈대 | 유지·확대 |
| LLM 판단 | **확률적** — 변동 가능 | 판단이 필요한 접합부 | 패턴화되면 코드로 전환 |
| MCP 호출 | **외부 의존** — API 상태 좌우 | 외부 데이터 조회/조작 | CLI 대안 있으면 전환 |

**진화 방향**: Skill 안의 LLM 판단 단계가 패턴화되면 Script로 추출. Skill은 "결정론적 단계 + 판단이 진짜 필요한 곳만" 담당하는 구조로 성숙시킨다.

### 도구 영역별 매핑

| 영역 | Skill (우선) | MCP (보완) | MCP가 필요한 경우 |
|------|------------|-----------|-----------------|
| **UI 디자인** | `/ui-ux-pro-max` — 스타일/컬러/폰트/레이아웃 결정 | `magic` | 컴포넌트 최신 소스코드 가져올 때만 |
| **UI 구현** | `/frontend-design`, `frontend-patterns.md` — 패턴/구조 | `magic` | 특정 컴포넌트 예제 코드 필요 시 |
| **코드 품질** | `/code-review`, `coding-standards.md` — 규칙/체크리스트 | - | 불필요 |
| **보안** | `/security-review` — OWASP 체크리스트 | - | 불필요 |
| **테스트** | `/tdd`, `/e2e` — 워크플로우/패턴 | - | 불필요 |
| **백엔드** | `backend-patterns.md` — API/DB 패턴 | - | 불필요 |
| **라이브러리 문서** | - (로컬에 없음) | `context7` | **항상** (최신 API 확인) |
| **작업 관리** | - | `nxtflow`, `Notion` | **항상** (외부 데이터) |
| **일정/메일** | - | `gws CLI` 우선 | **항상** (외부 데이터) |
| **PR/이슈** | - | `gh CLI` 우선, `github` MCP 보완 | **항상** (외부 데이터) |
| **배포** | - | `cloudflare` | 배포 관리 시 |
| **웹 수집 (단순)** | `/create-content` — 구조화/정리 | `firecrawl` | 대량 크롤링/사이트맵 필요 시 |
| **웹 자동화 (인터랙션/인증)** | - | - | `browser-use` CLI 사용 (아래 참조) |

### 도구 사용 규칙

1. **Skill이 커버하는 작업은 Skill을 중심으로 실행한다** — Skill 없이 Agent나 MCP만으로 처리하지 않는다
2. **Skill 내부에서는 결정론적 단계를 우선한다** — CLI/Script로 가능한 부분은 LLM 판단에 맡기지 않는다
3. **CLI 도구가 있으면 MCP보다 CLI 우선**: `gws > MCP Gmail/Calendar`, `gh > GitHub MCP`, `browser-use > firecrawl`
4. MCP는 **외부 시스템의 실시간 데이터 조회/조작**에만 사용
5. **CLAUDE.md는 권고(advisory), Hook은 강제(deterministic)** — 반드시 실행되어야 하는 것은 Hook으로

---

## Browser Use CLI — 웹 브라우저 자동화

커맨드라인에서 브라우저를 직접 제어하는 CLI 도구. 백그라운드 데몬으로 ~50ms 레이턴시.

### 언제 사용하는가

```
웹 콘텐츠 접근 필요
  ├─ 대량 크롤링 (sitemap, 100+ 페이지)  → firecrawl
  ├─ 단순 URL 1-5개 읽기               → WebFetch / firecrawl
  ├─ JS 렌더링 필요 (SPA)              → browser-use
  ├─ 인증/로그인 필요                   → browser-use --profile
  ├─ 폼 작성/클릭 등 인터랙션           → browser-use
  ├─ UI 시각 검증 (스크린샷)            → browser-use
  └─ 배포 후 스모크 테스트              → browser-use
```

### 핵심 명령어

```bash
# 페이지 열기
browser-use open <url>

# 현재 상태 (URL, 제목, 클릭 가능 요소 인덱스)
browser-use state

# 스크린샷
browser-use screenshot [path]

# 요소 클릭/입력
browser-use click <index>
browser-use input <index> "text"

# JS 실행
browser-use eval "document.title"

# HTML 가져오기
browser-use get html
browser-use get html --selector "main"

# 실제 Chrome 프로필로 열기 (기존 로그인 유지)
browser-use --profile open <url>

# 세션 관리
browser-use --session work open <url>
browser-use close
```

### 스킬 연동 포인트

| 스킬 | 연동 단계 | browser-use 역할 |
|------|----------|-----------------|
| `/create-content` | Step 1 fallback | 인증/SPA 콘텐츠 읽기 (`get html`) |
| `/ui-ux-pro-max` | Phase 4+ 추가 | 렌더링 결과 시각 검증 (`screenshot`) |
| `/deploy` | status 확장 | 배포 후 스모크 테스트 (`open` → `state` → `screenshot`) |
| `/video` | Step 5 확장 | Remotion 프리뷰 캡처 (`screenshot`) |
| `/e2e` | 테스트 작성 전 | 흐름 탐색 + 셀렉터 파악 (`state`) |

### 주의사항

- E2E 테스트에는 Playwright 사용 — browser-use는 테스트 프레임워크가 아님
- `extract` 명령은 미구현 — `eval` + JS로 데이터 추출
- 데몬이 백그라운드에서 실행됨 — `browser-use close`로 정리

---

## UI 구현 파이프라인

Skill-First 원칙 적용: **Skill로 결정 → MCP로 소스코드만 가져오기**

### Phase 1: 디자인 결정 (Skill — ui-ux-pro-max)

스타일, 컬러, 타이포그래피, 레이아웃을 **로컬 Skill로 결정**한다. MCP 호출 없음.

```bash
# 1. 디자인 시스템 생성 (필수 — Skill만으로 완결)
python3 skills/ui-ux-pro-max/scripts/search.py "<제품유형> <키워드>" --design-system -p "프로젝트명"

# 2. 필요 시 상세 조회 (여전히 Skill)
python3 skills/ui-ux-pro-max/scripts/search.py "<키워드>" --domain style
python3 skills/ui-ux-pro-max/scripts/search.py "<키워드>" --domain color
python3 skills/ui-ux-pro-max/scripts/search.py "<키워드>" --domain typography
```

**출력물**: 스타일 방향, 컬러 팔레트, 폰트 페어링, 레이아웃 패턴, 안티패턴

### Phase 2: 컴포넌트 선택 (Skill — 아래 컴포넌트 맵 참조)

디자인 결정에 맞는 컴포넌트를 **이 문서의 컴포넌트 맵**에서 선택한다.
이 단계까지 MCP 호출 없이 어떤 컴포넌트를 쓸지 결정 완료.

### Phase 3: 소스코드 가져오기 (MCP — Magic, 최소 호출)

선택된 컴포넌트의 **실제 소스코드**만 MCP로 가져온다.

```
mcp__magic__getRegistryItem(name, includeSource: true)  → 소스코드 1회 가져오기
```

- `searchRegistryItems`는 Phase 2에서 맵으로 대체 — **호출 불필요**
- `listRegistryItems`도 맵으로 대체 — **호출 불필요**
- MCP는 오직 `getRegistryItem`으로 **확정된 컴포넌트의 소스코드**만 가져옴

### Phase 4: 조합 구현 + 검증 (Skill)

디자인 시스템 + Magic UI 소스코드를 조합하여 구현.
ui-ux-pro-max **Pre-Delivery Checklist**로 검증 (Skill, MCP 없음).

### 용도별 Magic UI 컴포넌트 맵 (Phase 2 참조용)

| 용도 | 추천 컴포넌트 |
|------|-------------|
| **히어로 섹션** | `animated-gradient-text`, `aurora-text`, `typing-animation`, `word-rotate`, `blur-fade`, `particles`, `retro-grid` |
| **CTA 버튼** | `shimmer-button`, `pulsating-button`, `rainbow-button`, `shiny-button`, `interactive-hover-button`, `ripple-button` |
| **기능 소개** | `bento-grid`, `magic-card`, `neon-gradient-card`, `animated-beam`, `orbiting-circles`, `icon-cloud` |
| **소셜 프루프** | `marquee`, `avatar-circles`, `tweet-card`, `client-tweet-card`, `number-ticker` |
| **배경/장식** | `dot-pattern`, `grid-pattern`, `flickering-grid`, `animated-grid-pattern`, `retro-grid`, `warp-background`, `meteors`, `light-rays` |
| **텍스트 효과** | `animated-shiny-text`, `hyper-text`, `morphing-text`, `sparkles-text`, `text-reveal`, `text-animate`, `line-shadow-text`, `comic-text`, `spinning-text` |
| **프로그레스/상태** | `animated-circular-progress-bar`, `scroll-progress`, `animated-list`, `border-beam`, `shine-border` |
| **디바이스 목업** | `safari`, `iphone`, `android`, `terminal` |
| **네비게이션** | `dock`, `scroll-based-velocity`, `progressive-blur` |
| **인터랙션** | `cool-mode`, `confetti`, `pointer`, `smooth-cursor`, `lens`, `pixel-image` |
| **파일/코드** | `file-tree`, `code-comparison`, `highlighter` |
| **영상** | `hero-video-dialog`, `video-text` |

### UI 파이프라인 실전 예시

**요청**: "Vanguard 랭킹 페이지에 히어로 섹션 리디자인"

```
Phase 1 (Skill): 디자인 결정
  → ui-ux-pro-max: "gaming leaderboard dark futuristic" --design-system
  → 결과: 다크 모드, 네온 악센트, Inter/JetBrains Mono, glassmorphism

Phase 2 (Skill): 컴포넌트 선택 — 이 문서의 맵 참조
  → 히어로 텍스트: aurora-text
  → 배경: particles
  → 숫자 강조: number-ticker
  → (MCP 호출 0회)

Phase 3 (MCP): 소스코드만 가져오기 — 최소 호출
  → getRegistryItem("aurora-text", includeSource: true)
  → getRegistryItem("particles", includeSource: true)
  → getRegistryItem("number-ticker", includeSource: true)
  → (MCP 호출 3회 — 필요한 것만)

Phase 4 (Skill): 조합 + 검증
  → 디자인 시스템 컬러/타이포 적용
  → Magic UI 소스코드 커스텀 통합
  → ui-ux-pro-max Pre-Delivery Checklist 확인
```

### 주의사항

- Magic UI는 **React + Tailwind + Framer Motion** 기반 — 다른 스택에서는 직접 포팅 필요
- `getRegistryItem`에서 `includeSource: true` 필수 — 소스 없이는 커스텀 불가
- MCP `search`/`list`는 위 컴포넌트 맵으로 대체 — **불필요한 MCP 호출 금지**
- ui-ux-pro-max의 **Pre-Delivery Checklist** 반드시 수행 (접근성, 커서, 라이트/다크 모드)
- **이모지 아이콘 금지** — SVG 아이콘 사용 (Lucide, Heroicons)

---

## Hook — 결정론적 강제 계층

> *"Unlike CLAUDE.md instructions which are **advisory**, hooks are **deterministic** and guarantee the action happens."* — Claude Code Best Practices

Hook은 하네스에서 **유일하게 100% 결정론적인 계층**이다. 셸 스크립트로 매번 동일하게 실행되며, LLM이 무시하거나 건너뛸 수 없다. 두 가지 역할을 담당한다:

```
Hook
  ├─ 가드레일: 하면 안 되는 것을 차단 (PreToolUse → block)
  │    예: commit-check.sh — 커밋 규칙 위반 차단
  └─ 필수 작업: 반드시 해야 하는 것을 실행 (PostToolUse → run)
       예: prettier 자동 포맷팅, console.log 잔존 체크
```

가드레일은 Hook과 CLAUDE.md 모두 담당하지만 강도가 다르다:
- **Hook**: 결정론적 강제 — 위반하면 차단되거나 자동 실행됨
- **CLAUDE.md**: 권고 — LLM이 대체로 따르지만 100%는 아님

| Hook | 시점 | 역할 |
|------|------|------|
| `prompt-init.sh` | UserPromptSubmit | Refine Loop 초기화/상태 주입 |
| `commit-check.sh` | PreToolUse(Bash) | 커밋 규칙 검증 (refine/ralph 형식) |
| `stop-loop.sh` | Stop | Refine iteration 전환/종료 |
| `stop-console-check.sh` | Stop | console.log 잔존 체크 |
| PostToolUse(Edit) | Edit 후 | prettier 포맷팅 + console.log 경고 |
| PostToolUse(Bash) | gh pr create 후 | PR URL + CI 상태 알림 |

---

## 피드백 루프 전략

```
에이전트가 실패할 때:
  1. 에러 메시지를 컨텍스트에 주입
  2. build-error-resolver 에이전트 활성화
  3. 3회 반복 실패 → 사용자에게 전략 변경 확인

에이전트가 정체할 때 (Refine/Ralph Loop):
  1. 정체 감지: 동일 에러 반복 또는 파일 변경 없음
  2. stagnation_count 증가
  3. stagnation_limit(3) 도달 → 사용자에게 물어보고 전략 변경
```

---

## 하네스 레이어 요약

```
┌─────────────────────────────────────────────────┐
│  Layer 5: 라이프사이클 관리                        │
│  Memory, Refine/Ralph Loop, git 체크포인트           │
├─────────────────────────────────────────────────┤
│  Layer 4: 피드백 루프                              │  결정론적
│  빌드/테스트 결과 → 에러 주입 → 자동 수정 시도      │
├─────────────────────────────────────────────────┤
│  Layer 3: 결정론적 강제 (Hook)                      │  결정론적
│  가드레일(차단) + 필수 작업(자동 실행)              │  (LLM 우회 불가)
├─────────────────────────────────────────────────┤
│  Layer 2: 도구 오케스트레이션                       │  Skill 중심
│  Skill(오케스트레이터) + Agent + MCP               │  (Code-First 내부 적용)
├─────────────────────────────────────────────────┤
│  Layer 1: 컨텍스트 엔지니어링                       │  권고
│  CLAUDE.md, MEMORY.md, 코드맵, context7            │  (advisory)
├─────────────────────────────────────────────────┤
│  Layer 0: 아키텍처 제약                            │  코드 강제
│  코딩 규칙, 커밋 규칙, 보안 체크리스트              │
└─────────────────────────────────────────────────┘

Skill-First: Layer 2의 중심은 Skill (CLI·Script·MCP·판단을 묶는 오케스트레이터)
Code-First:  Skill 내부에서 결정론적 단계를 최대화 (LLM 판단은 접합부에만)
진화 방향:   Skill 내 LLM 판단 단계가 패턴화되면 Script로 추출
```
