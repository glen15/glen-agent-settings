---
name: harness
description: "하네스 엔지니어링 운영 가이드. 에이전트/스킬/MCP/Hook 선택 매트릭스와 UI 파이프라인(Magic MCP + ui-ux-pro-max 조합) 포함. 모든 프로젝트에 적용."
---

# Harness Engineering Guide

Glen의 Claude Code 하네스 운영 가이드. 에이전트가 **올바른 도구를 올바른 순서로** 사용하도록 안내한다.

## 핵심 원칙

> 에이전트가 어려워하는 지점 = 하네스 개선 신호

1. **모델보다 하네스가 성능을 결정한다** — 도구·제약·피드백·컨텍스트가 결과를 좌우
2. **결정론적 검증을 LLM 판단보다 우선** — 린터, 빌드, 테스트로 확인
3. **한 번에 한 기능** — 컨텍스트 부족과 조기 완료 선언을 방지
4. **Skill-First** — 동일 기능이라면 MCP보다 Skill 우선. MCP는 외부 실시간 데이터가 필요할 때만

---

## 에이전트 선택 매트릭스

| 상황 | 에이전트 | 활성화 |
|------|---------|--------|
| 새 기능 설계 | `planner` / `architect` | 수동 |
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
[새 기능]  planner → tdd-guide → code-reviewer → security-reviewer
[버그 수정] Explore → tdd-guide (재현 테스트 먼저) → build-error-resolver
[리팩토링] refactor-cleaner → code-reviewer → doc-updater
[UI 구현]  planner → UI 파이프라인 (아래 참조) → code-reviewer
```

---

## 스킬 선택 가이드

| 작업 유형 | 스킬 | 호출 |
|----------|------|------|
| 세션 내 반복 수렴 | `/refine` | 수동 |
| 밤샘 무인 코딩 | `ralph-loop` (CLI) | 수동 |
| UI/UX 디자인+구현 | `/ui-ux-pro-max` + Magic MCP | 수동 |
| 콘텐츠 생성 | `/create-content` | 수동 |
| 보안 체크리스트 | `/security-review` | 수동 |
| TDD 워크플로우 | `/tdd-workflow` | 수동 |
| CI/CD 배포 관리 | `/deploy` | 수동 |
| 프로젝트 부트스트랩 | `/init` | 수동 |
| 코드맵 업데이트 | `/update-codemaps` | 수동 |
| 문서 업데이트 | `/update-docs` | 수동 |
| 빌드 오류 수정 | `/build-fix` | 수동 |
| 코드 리뷰 | `/code-review` | 수동 |
| 리팩토링/정리 | `/refactor-clean` | 수동 |
| E2E 테스트 | `/e2e` | 수동 |
| 구현 계획 | `/plan` | 수동 |

---

## 도구 선택 원칙: Skill-First

### 왜 Skill 우선인가

| | Skill | MCP |
|---|---|---|
| 속도 | 즉시 (로컬 파일) | 네트워크 왕복 |
| 안정성 | 항상 가용 | 서버 다운/API 제한 가능 |
| 제어권 | 완전 커스텀 | 외부 의존 |
| 컨텍스트 | 에이전트 행동 자체를 형성 | 데이터만 반환 |
| 비용 | 0 | API 호출 비용 가능 |

### 선택 흐름

```
작업 요청 → Skill로 해결 가능한가?
  ├─ YES → Skill 사용
  └─ NO → 외부 실시간 데이터가 필요한가?
       ├─ YES → MCP 사용 (최소 범위)
       └─ NO → CLI 도구 (gws, gh, supabase 등)
```

### Skill vs MCP 매핑

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
| **웹 수집** | `/create-content` — 구조화/정리 | `firecrawl` | 스크래핑 필요 시 |

### MCP 사용 규칙

1. **Skill이 커버하는 영역은 MCP를 호출하지 않는다**
2. MCP는 **외부 시스템의 실시간 데이터 조회/조작**에만 사용
3. MCP로 가져온 데이터도 **Skill의 규칙/체크리스트로 검증**
4. CLI 도구가 있으면 MCP보다 CLI 우선: `gws > MCP Gmail/Calendar`, `gh > GitHub MCP`

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

## Hook 기반 자동 검증

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
│  Layer 4: 피드백 루프                              │
│  빌드/테스트 결과 → 에러 주입 → 자동 수정 시도      │
├─────────────────────────────────────────────────┤
│  Layer 3: 자동 검증 (Hooks)                       │
│  prettier, console.log 감지, 커밋 규칙, 린트       │
├─────────────────────────────────────────────────┤
│  Layer 2: 도구 오케스트레이션                       │
│  에이전트 9종 + 스킬 15+ + MCP 10+               │
├─────────────────────────────────────────────────┤
│  Layer 1: 컨텍스트 엔지니어링                       │
│  CLAUDE.md, MEMORY.md, 코드맵, context7           │
├─────────────────────────────────────────────────┤
│  Layer 0: 아키텍처 제약                            │
│  코딩 규칙, 커밋 규칙, 보안 체크리스트              │
└─────────────────────────────────────────────────┘
```
