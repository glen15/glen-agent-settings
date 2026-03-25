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
5. **Generator-Evaluator 분리** — 만드는 자와 평가하는 자를 분리하여 자기 관대 편향 방지
6. **하네스 진화** — 모델이 좋아질수록 스캐폴딩은 줄이고, 새 능력으로 더 복잡한 작업을 활성화

---

## 에이전트 선택 매트릭스

| 상황 | 에이전트 | 활성화 |
|------|---------|--------|
| 새 기능 설계 / 사양 확장 | 내장 Plan 모드 / `architect` | 수동 |
| 새 기능 구현 | `tdd-guide` | 수동 |
| 라이브 앱 품질 평가 | `evaluator` | 수동 (/evaluate) |
| 빌드/타입 에러 | `build-error-resolver` | **자동** (빌드 실패 시) |
| 코드 변경 후 리뷰 | `code-reviewer` | **자동** (코드 변경 후) |
| 보안 민감 코드 | `security-reviewer` | **자동** (인증/API/결제 코드) |
| E2E 테스트 | `e2e-runner` | 수동 |
| 코드 정리/죽은 코드 | `refactor-cleaner` | 수동 |
| 문서/코드맵 업데이트 | `doc-updater` | 수동 |
| 코드베이스 탐색 | `Explore` (subagent_type) | 자동 (3+ 쿼리 필요 시) |

### 에이전트 조합 패턴

```
[새 기능]      /plan (architect) → tdd-guide → evaluator → code-reviewer → security-reviewer
[풀스택 앱]    /plan (architect: 사양 확장) → /begin → Generator(tdd-guide) ↔ Evaluator(contract 기반) 반복
[버그 수정]    Explore → tdd-guide (재현 테스트 먼저) → build-error-resolver
[리팩토링]     refactor-cleaner → code-reviewer → doc-updater
[UI 구현]      /plan (architect) → UI 파이프라인 (아래 참조) → evaluator (스크린샷 기반) → code-reviewer
[장시간 개발]  /plan → /begin → /refine (Generator-Evaluator 모드) → context reset → 반복
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
| 구현 계획 / 사양 확장 | `/plan` | architect |
| 라이브 앱 평가 | `/evaluate` | evaluator |
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

#### 가드레일 (차단)

| Hook | 시점 | 역할 | 대상 스킬 |
|------|------|------|----------|
| `commit-format-check.sh` | PreToolUse(Bash) | 커밋 한글 + 타입 프리픽스 검증 | `/done`, 수동 커밋 |
| `commit-check.sh` | PreToolUse(Bash) | `refine(N/MAX)` 형식 검증 | `/refine` 전용 |
| `secret-scanner.sh` | PreToolUse(Write, Edit) | 하드코딩된 시크릿 차단 | 전체 |
| git push 차단 (인라인) | PreToolUse(Bash) | git push 실수 방지 (현재 비활성) | 전체 |

#### 필수 작업 (자동 실행)

| Hook | 시점 | 역할 | 대상 스킬 |
|------|------|------|----------|
| `auto-test.sh` | PostToolUse(Write, Edit) | 소스 수정 후 관련 테스트 자동 실행 | `/tdd`, 일반 코딩 |
| prettier + console.log (인라인) | PostToolUse(Edit) | 포맷팅 + console.log 경고 | 전체 |
| PR URL 알림 (인라인) | PostToolUse(Bash) | gh pr create 후 URL + CI 상태 | `/deploy` |
| `task-context-inject.sh` | UserPromptSubmit | 활성 /begin 작업 컨텍스트 주입 | `/begin` 생명주기 |
| `prompt-init.sh` | UserPromptSubmit | Refine Loop 상태 컨텍스트 주입 | `/refine` |
| `stop-loop.sh` | Stop | Refine iteration 전환/정체 감지/예산 확인 | `/refine` |
| `stop-console-check.sh` | Stop | 세션 종료 시 console.log 잔존 경고 | 전체 |
| `post-task-commit-check.sh` | Stop | 미커밋 + 활성 작업 미종료 경고 | `/begin`-`/done` 생명주기 |

---

## 피드백 루프 전략

### 스킬 실패 → Gotcha 기록 (최우선)

> **기록이 우회보다 먼저다.** 핵심 워크플로우 #4 Gotcha-First 원칙.

스킬 실행 중 오류가 발생하면 **해결/우회 시도 전에** 반드시 해당 스킬의 SKILL.md `## Gotchas`에 기록한다.

```
스킬 실행 중 오류 발생
  1. 근본 원인 파악 (에러 메시지 + 실행 환경 분석)
  2. 해당 스킬의 SKILL.md ## Gotchas에 한 줄 추가
     형식: N. **원인 키워드** — 증상, 근본 원인, 방지책.
  3. 그 다음 우회/해결 시도
```

**왜 우회보다 먼저인가**: 우회에 성공하면 기록 동기가 사라진다. 다음 세션에서 같은 오류를 또 만나고, 또 우회하고, 또 기록 안 하는 악순환이 된다.

**기록 대상**: 인프라/툴링 오류(tsx CJS, ESM resolve 등), 환경 의존성, API 변경, 반복되는 판단 오류 모두 포함.

### 에이전트가 실패할 때

```
  1. 에러 메시지를 컨텍스트에 주입
  2. build-error-resolver 에이전트 활성화
  3. 3회 반복 실패 → 사용자에게 전략 변경 확인
```

### 에이전트가 정체할 때 (Refine/Ralph Loop)

```
  1. 정체 감지: 동일 에러 반복 또는 파일 변경 없음
  2. stagnation_count 증가
  3. stagnation_limit(3) 도달 → 사용자에게 물어보고 전략 변경
```

---

## 하네스 레이어 요약

```
┌─────────────────────────────────────────────────┐
│  Layer 6: 하네스 진화                              │
│  모델 개선 → 스캐폴딩 축소 → 새 능력으로 복잡한 작업  │
├─────────────────────────────────────────────────┤
│  Layer 5: 라이프사이클 관리                        │
│  Memory, Refine/Ralph Loop, Context Reset, git    │
├─────────────────────────────────────────────────┤
│  Layer 4: 피드백 루프                              │  결정론적
│  Generator-Evaluator 분리, Sprint Contract 검증    │
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

---

## Long-Running App 개발 패턴

> *"22배 비용 증가가 기능성에서 20배+ 개선을 달성한다."* — Anthropic, Harness Design

단순 작업(20분)과 장시간 앱 개발(3~6시간)은 근본적으로 다른 하네스가 필요하다.

### 3단계 에이전트 아키텍처

```
[Planner]  1~4문장 프롬프트 → 완전한 제품 사양 (architect)
     ↓
[Generator] 사양 기반 구현 (tdd-guide + 코딩)
     ↓  ↑ (반복)
[Evaluator] 라이브 앱 평가 (evaluator — Sprint Contract 기준)
```

**Planner (architect 에이전트)**:
- 야심찬 범위 지향, 세밀한 구현 세부사항은 배제
- AI 기능 통합 기회 식별
- Sprint Contract 초안 작성 (완료 기준 정의)

**Generator (tdd-guide + 코딩)**:
- 한 번에 한 기능 구현 + git 버전 관리
- 각 기능 완료 후 자기 평가 (단, 최종 판정은 Evaluator가)

**Evaluator (evaluator 에이전트)**:
- 실행 중인 앱을 **직접 조작** (browser-use/curl)
- Sprint Contract 기준으로 PASS/FAIL/PARTIAL 판정
- 구체적 수정 제안 포함한 피드백

### 파일 기반 에이전트 통신

에이전트 간 통신은 **파일**을 통해 이루어진다. 구두 전달이 아닌 구조화된 문서로 합의를 유지한다.

```
.claude/tasks/<작업명>/
├── plan.md          ← Planner가 작성, Generator가 참조
├── contract.md      ← Planner 초안 → Generator-Evaluator 합의
├── progress.md      ← Generator가 업데이트
├── evaluation.md    ← Evaluator가 작성, Generator가 참조
├── context.md       ← 모든 에이전트가 업데이트
└── failures.md      ← 모든 에이전트가 업데이트
```

| 파일 | 작성자 | 소비자 | 역할 |
|------|--------|--------|------|
| plan.md | Planner | Generator | 무엇을 만들 것인가 |
| contract.md | Planner → 합의 | Evaluator | "완료"의 정의 |
| progress.md | Generator | 전체 | 현재 어디까지 왔는가 |
| evaluation.md | Evaluator | Generator | 무엇이 통과/실패인가 |

### 실전 흐름 예시

```
1. /plan "브라우저 기반 DAW 구축"
   → architect: 제품 사양 확장 + contract.md 초안

2. /begin "browser-daw"
   → 5개 문서 생성, contract.md에 완료 기준 채우기

3. /refine "DAW 핵심 기능 구현" --max-iter 15
   → Generator: 기능별 구현 + 커밋
   → Verify 단계마다 /evaluate 호출
   → Evaluator: PASS/FAIL 판정 → evaluation.md 작성
   → Generator: 피드백 반영 → 다음 iteration
   → context 과부하 시 → progress.md에 상태 기록 → context reset

4. Evaluator APPROVE → /done
```

---

## Context Reset 전략

> 모델이 context window가 차오르면 **맥락 불안(context anxiety)**이 발생한다.

### 증상

- 조기 완료 선언 ("이 정도면 충분합니다")
- 응답 품질 저하 (세부사항 누락, 반복)
- 기존 코드를 잊고 중복 작성

### 대응

compaction(자동 압축)만으로는 부족하다. **구조화된 핸드오프**로 상태를 전달한다.

```
Context 과부하 감지
  ↓
progress.md + context.md에 현재 상태 기록
  ↓
"Context reset 후 이 파일들을 읽고 이어서 진행하세요" 메시지
  ↓
새 context에서 5개 추적 문서 로드 → 작업 재개
```

**Refine Loop에서**: iteration 5회+ 진행 후 품질 저하 시 자동 감지
**Ralph Loop에서**: 매 라운드가 fresh context — 이미 구현됨 (`scope-state.json`)

---

## 품질 루브릭 시스템

> *"주관적 판단도 기준을 정의하면 측정 가능하다."*

### 범용 루브릭 (contract.md에 적용)

| 영역 | 기준 | 측정 방법 |
|------|------|----------|
| **기능성** | 사용자가 핵심 작업을 완료할 수 있는가 | 라이브 클릭스루 (browser-use) |
| **설계 품질** | 색상, 타이포, 레이아웃이 조화로운가 | 스크린샷 + 일관성 체크 |
| **독창성** | 맞춤형 결정이 있는가 vs AI 템플릿 그대로인가 | 코드 리뷰 |
| **장인정신** | 간격 일관성, 에러 처리, 엣지 케이스 | 엣지 케이스 테스트 |

### 프롬프트 언어의 영향

프롬프트에 사용하는 언어가 품질 수렴 방향을 결정한다:
- "박물관 수준의 디자인" → 시각적 수렴 유도 (미학적 전환까지)
- "프로덕션 레벨" → 기능적 완성도 수렴
- "MVP" → 핵심 기능만 빠르게 수렴

---

## Evaluator 캘리브레이션

> *"초기 실행에서는 합법적 문제를 식별한 후 자신을 설득해 괜찮다고 판단했다."*

LLM은 자신이 생성한 결과물에 관대하다. Evaluator도 예외가 아니므로 **단계적 조율**이 필요하다.

- **1회차**: 방향 피드백 중심 (관대 허용)
- **2회차~**: Contract 기준 엄격 적용. 부분 구현 = FAIL, 스크린샷 증거 필수
- **3회차~**: 세밀한 품질 지적 (간격, 에러 처리, 엣지 케이스)

판정 규칙 상세: `evaluator` 에이전트 정의 참조.

---

## 비용-품질 트레이드오프

| 티어 | 투자 | 패턴 | 적합한 작업 |
|------|------|------|-----------|
| **Quick** | $1~10, 20분 | 단일 에이전트 | 버그 수정, 유틸리티, 스크립트 |
| **Standard** | $10~50, 1~2시간 | /refine (단일 Generator) | 중간 규모 기능, 리팩토링 |
| **Deep** | $50~200, 3~6시간 | Planner → Generator ↔ Evaluator | 풀스택 앱, 복잡한 UI, 장시간 개발 |

**핵심 인사이트**: Quick 티어에서 기능이 "완전히 손상"인 작업이 Deep 티어에서 "완전히 작동"이 된다. 비용이 22배 늘어도 품질이 20배+ 개선되면 합리적이다.

### 티어 선택 기준

```
작업 복잡도 판단
  ├─ 파일 1~3개 수정        → Quick
  ├─ 파일 5~15개, 기능 1~2개 → Standard
  └─ 풀스택, UI+API+DB 통합  → Deep
```

---

## 하네스 진화 원칙

> *"모델이 개선될수록 스캐폴딩의 필요성이 줄어들지만, 새로운 능력을 활용한 더 복잡한 작업이 활성화된다."*

### 원칙

1. **스캐폴딩 축소**: 모델이 더 오래 집중하고, 더 큰 코드베이스를 다루면 → 스프린트 분해 같은 보조 구조를 제거
2. **복잡성 상향**: 줄어든 스캐폴딩 비용으로 → 더 야심찬 작업을 시도 (DAW, 게임 엔진 등)
3. **하네스 공간은 이동한다**: 흥미로운 하네스 조합의 공간이 축소되지 않고, 더 높은 복잡도로 이동

### 실천

- Opus 4.5에서 필요했던 스프린트 분해가 Opus 4.6에서 불필요해짐
- **정기적으로 하네스를 재평가**: 모델 업그레이드 후 기존 스캐폴딩이 여전히 필요한지 확인
- **새 능력 발견 시 하네스에 반영**: 모델이 새로 할 수 있는 것을 활용하는 패턴 추가
