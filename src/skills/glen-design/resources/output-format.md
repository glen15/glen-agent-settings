# DESIGN.md 9섹션 표준 포맷

모든 모드(generate, analyze, preset)의 출력은 이 형식을 따른다.

```markdown
# Design System: [프로젝트/사이트명]

## 1. Visual Theme & Atmosphere
(분위기, 밀도, 디자인 철학. 감성적 형용사로 분위기 전달.
예: "정제된 갤러리 같은 에어리한 인터페이스, 비대칭 레이아웃과 유체적 모션")

**Key Characteristics:**
- (5-8개 핵심 특성 불릿)

## 2. Color Palette & Roles
각 색상: **서술적 이름** (`#hex`) — 기능적 역할

### Background Surfaces
- **이름** (`#hex`) — 역할

### Text & Content
- **이름** (`#hex`) — 역할

### Brand & Accent
- **이름** (`#hex`) — 역할 (최대 1 액센트, 채도 < 80%)

### Status Colors
- **이름** (`#hex`) — 역할

### Border & Divider
- **이름** (`#hex` 또는 `rgba(...)`) — 역할

## 3. Typography Rules

### Font Family
- **Primary**: `폰트명`, 폴백 목록
- **Monospace**: `폰트명`, 폴백 목록
- **OpenType Features**: (있으면 명시)

### Hierarchy

| Role | Font | Size | Weight | Line Height | Letter Spacing | Notes |
|------|------|------|--------|-------------|----------------|-------|
| Display XL | | | | | | |
| Display | | | | | | |
| Heading 1 | | | | | | |
| Body | | | | | | |
| Caption | | | | | | |
| Code | | | | | | |

### Principles
- (타이포 설계 원칙 3-5개)

## 4. Component Stylings

### Buttons
**Primary** — bg, text, padding, radius, hover, focus
**Secondary/Ghost** — bg, text, border, hover
**Icon Button** — 사이즈, radius

### Cards & Containers
- Background, border, radius, shadow, hover

### Inputs & Forms
- Border, radius, focus, label 위치

### Badges & Pills
- Background, text, radius, font

### Navigation
- 구조, 폰트, 활성 상태, 모바일 동작

## 5. Layout Principles

### Spacing System
- Base unit, scale

### Grid & Container
- Max width, 컬럼 구조

### Whitespace Philosophy
- 핵심 원칙

### Border Radius Scale
- Micro → Standard → Card → Pill → Circle

## 6. Depth & Elevation

| Level | Treatment | Use |
|-------|-----------|-----|
| Flat | | |
| Subtle | | |
| Elevated | | |
| Dialog | | |

**Shadow Philosophy**: (그림자 시스템 설계 의도)

## 7. Do's and Don'ts

### Do
- (5-8개)

### Don't
- (5-8개)

## 8. Responsive Behavior

### Breakpoints
| Name | Width | Key Changes |
|------|-------|-------------|

### Touch Targets
- (규칙)

### Collapsing Strategy
- (축소 규칙)

## 9. Agent Prompt Guide

### Quick Color Reference
- Primary CTA: 이름 (`#hex`)
- Background: 이름 (`#hex`)
- (주요 색상 빠른 참조)

### Example Component Prompts
- "Create a hero section on ..."
- "Design a card ..."
- (즉시 복사 가능한 프롬프트 3-5개)

### Iteration Guide
1. (에이전트가 따라야 할 순서)
```

## 포맷 규칙

1. **색상**: 반드시 `서술적 이름 (#hex) — 역할` 형식
2. **타이포**: 반드시 테이블로 전체 계층 표시
3. **컴포넌트**: 최소 default + hover 상태 포함
4. **Agent Prompt Guide**: 복사-붙여넣기 가능한 구체적 프롬프트
5. **언어**: 기술 값(hex, px, rem)은 영어, 설명은 사용자 언어
