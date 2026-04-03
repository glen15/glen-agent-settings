---
name: glen-design
description: "디자인 시스템 통합 스킬. DESIGN.md 생성/분석/프리셋/추천/검증을 하나로. /design — UI 디자인 작업의 단일 진입점."
user_invocable: true
argument-hint: <"프롬프트"|analyze|generate|preset|recommend|review> [옵션]
allowed-tools:
  - "stitch*:*"
  - "Read"
  - "Write"
  - "Bash"
  - "Glob"
  - "web_fetch"
---

# Glen Design — 디자인 시스템 통합 스킬

디자인 시스템의 **생성, 분석, 추천, 프리셋 적용, 품질 검증**을 하나의 진입점으로 통합한다.
출력 표준: [9섹션 DESIGN.md 포맷](resources/output-format.md)

## 명령어 라우팅

```
RAW_ARGS="__ARGS__"
```

| 명령 | 설명 | 예시 |
|------|------|------|
| `generate "바이브"` | 프리미엄 DESIGN.md 생성 | `/design generate "다크 SaaS 대시보드"` |
| `analyze` | 기존 Stitch 프로젝트 분석 → DESIGN.md 추출 | `/design analyze --project-id 123` |
| `preset <이름>` | 프리셋 DESIGN.md 적용 | `/design preset linear` |
| `recommend "키워드"` | DB에서 스타일/팔레트/폰트 추천 | `/design recommend "fintech dark"` |
| `review` | Pre-delivery 체크리스트 실행 | `/design review` |
| `"프롬프트"` (기본) | 의도 파악 후 자동 라우팅 | `/design "Stripe 느낌 결제 페이지"` |

### 자동 라우팅 규칙

인자가 위 명령어와 매칭되지 않으면 의도를 파악한다:

| 사용자 의도 | 라우팅 대상 |
|------------|-----------|
| "~스타일로 만들어" / 사이트 이름 언급 | → preset |
| "바이브", "분위기", "느낌" 등 감성 키워드 | → generate |
| "--project-id", Stitch 프로젝트 언급 | → analyze |
| "추천해", "뭐가 좋을까", 스타일/팔레트 질문 | → recommend |
| "검토", "체크", "확인", "리뷰" | → review |

## 워크플로우

각 모드의 상세 지침:

| 모드 | 워크플로우 파일 |
|------|---------------|
| generate | [workflows/generate.md](workflows/generate.md) |
| analyze | [workflows/analyze.md](workflows/analyze.md) |
| preset | [workflows/preset.md](workflows/preset.md) |
| recommend | [workflows/recommend.md](workflows/recommend.md) |
| review | [workflows/review.md](workflows/review.md) |

## 공통 원칙

모든 모드에 적용되는 규칙:

### 출력 포맷
- DESIGN.md는 반드시 [9섹션 표준](resources/output-format.md)을 따른다
- 색상: 서술적 이름 + hex 코드 + 기능적 역할
- 타이포: 폰트명 + weight/size/spacing 테이블
- 컴포넌트: 상태별(default/hover/focus/disabled) 스타일

### 품질 규칙
- [taste-rules.md](resources/taste-rules.md)의 안티패턴은 모든 모드에서 강제
- 핵심 금지: Inter(프리미엄 컨텍스트), 순수 검정(#000000), 이모지, AI 보라 네온
- 단일 액센트 색상, 채도 80% 미만

### 폰트 정책
- 라이선스 필요 커스텀 폰트는 사용 금지
- 허용 폰트: Google Fonts 무료 폰트, 시스템 폰트
- 권장: `Geist`, `Satoshi`, `Outfit`, `Cabinet Grotesk`, `Manrope`, `Space Grotesk`
- 모노: `Geist Mono`, `JetBrains Mono`, `Fira Code`
- 프리셋의 커스텀 폰트는 대체 폰트로 매핑됨

## 참조

- [resources/output-format.md](resources/output-format.md) — 9섹션 DESIGN.md 표준
- [resources/taste-rules.md](resources/taste-rules.md) — 안티패턴 + 프리미엄 규칙
- [resources/presets/](resources/presets/) — 실전 사이트 DESIGN.md 프리셋
- [examples/DESIGN.md](examples/DESIGN.md) — 골드 스탠다드 예시

## Gotchas

> **필수**: 오류 발생 시 우회 전에 여기 기록.

1. **모드 미지정 시 혼란** — 자동 라우팅 실패 시 사용자에게 모드를 명시적으로 물어본다.
2. **preset + generate 혼동** — 프리셋은 기존 사이트 복제, generate는 새 바이브 생성. 사이트 이름이 있으면 preset.
3. **Stitch MCP 미설치** — analyze 모드는 Stitch MCP 필수. 없으면 안내 메시지.
