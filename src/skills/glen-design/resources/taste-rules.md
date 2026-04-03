# Taste Rules — 프리미엄 디자인 규칙

모든 glen-design 출력에 적용되는 품질 규칙과 안티패턴.

## 분위기 다이얼

| 다이얼 | 범위 | 기본값 | 설명 |
|--------|------|--------|------|
| Creativity | 1-10 | 9 | 1=울트라 미니멀 ↔ 10=에디토리얼, 볼드 |
| Density | 1-10 | 5 | 1=갤러리 에어리 ↔ 10=콕핏 덴스 |
| Variance | 1-10 | 8 | 1=대칭 그리드 ↔ 10=아트시 카오틱 |
| Motion | 1-10 | 6 | 1=정적 ↔ 10=시네마틱 |

## 색상 규칙

- 액센트 색상 최대 1개. 채도 80% 미만
- 순수 검정(`#000000`) 금지 → Off-Black, Zinc-950, Charcoal 사용
- AI 보라/파랑 네온 그라디언트 금지
- 중성 베이스: Zinc 또는 Slate 계열 일관 사용 (warm/cool 혼용 금지)

### 추천 액센트

| 용도 | 색상 | hex |
|------|------|-----|
| 성장/성공/데이터 | Emerald Signal | #10B981 |
| 생산성/SaaS/개발 | Electric Blue | #3B82F6 |
| 크리에이티브/에디토리얼 | Deep Rose | #E11D48 |
| 커뮤니티/소셜 | Amber Warmth | #F59E0B |

## 타이포 규칙

### 허용 폰트 (Google Fonts 무료)
- **Display**: Geist, Satoshi, Outfit, Cabinet Grotesk, Space Grotesk, Manrope
- **Body**: Display와 동일 패밀리 weight 400
- **Mono**: Geist Mono, JetBrains Mono, Fira Code
- **세리프 (에디토리얼 전용)**: Fraunces, Instrument Serif

### 금지 폰트
- `Inter` — 프리미엄/크리에이티브 컨텍스트에서 금지
- 제네릭 세리프 (`Times New Roman`, `Georgia`, `Garamond`, `Palatino`)
- 대시보드/소프트웨어 UI에서 세리프 전면 금지

### 타이포 원칙
- Display: track-tight (-0.025em), weight 700-900, line-height 1.1
- Body: 여유 있는 leading (1.65), 65ch max-width
- 스케일: Display `clamp(2.25rem, 5vw, 3.75rem)`, Body `1rem`

## Hero 섹션 규칙

- Variance > 4: 중앙 정렬 Hero 금지 → Split Screen / Left-Aligned / 비대칭
- CTA 최대 1개. "Learn more" 보조 링크 금지
- "Scroll to explore", 스크롤 화살표, 바운싱 셰브론 금지
- Creativity > 7: 인라인 이미지 타이포 적용 (단어 사이에 작은 사진)
- 텍스트가 이미지를 덮지 않음 — 깨끗한 공간 분리

## 레이아웃 규칙

- CSS Grid 우선. `calc(33% - 1rem)` 같은 flexbox 수학 금지
- "3열 동일 카드" 패턴 금지 → 2컬럼 지그재그, 비대칭 Bento, 수평 스크롤
- 요소 겹침 금지 — 모든 요소가 자신만의 공간 차지
- max-width 1400px 컨테인먼트
- `min-h-[100dvh]` 사용 (`h-screen` 금지 — iOS Safari 주소바 점프)

## 컴포넌트 규칙

- **버튼**: 외부 글로우 금지. 눌림 피드백(translateY -1px 또는 scale 0.98)
- **카드**: elevation이 계층을 전달할 때만 사용. Density > 7이면 border-top 구분자
- **로더**: 스켈레톤 쉬머만. 원형 스피너 금지
- **빈 상태**: 구성된 일러스트레이션. "No data" 텍스트만 금지

## 반응형 규칙

- 모바일 퍼스트 (< 768px): 단일 컬럼, 예외 없음
- 모바일 가로 스크롤: 치명적 실패
- 터치 타겟: 최소 44px
- 타이포 스케일링: `clamp()` 사용, body 최소 14px
- 인라인 이미지 타이포: 모바일에서 헤드라인 아래로 스택

## 모션 규칙 (코드 단계용)

- 스프링 물리: stiffness 100, damping 20. 선형 easing 금지
- 리스트/그리드: 캐스케이드 딜레이로 워터폴 마운트
- `transform`과 `opacity`만 애니메이트. `top`, `left`, `width`, `height` 금지
- 60fps 최소

## 안티패턴 (전면 금지)

1. 이모지를 UI 아이콘으로 사용
2. Inter 폰트 (프리미엄 컨텍스트)
3. 순수 검정 (#000000)
4. 네온 외부 글로우
5. 과포화 액센트 (채도 > 80%)
6. 큰 헤더에 과도한 그라디언트 텍스트
7. 커스텀 마우스 커서
8. 요소 겹침
9. 3열 동일 카드 레이아웃
10. 제네릭 이름 ("John Doe", "Acme", "Nexus")
11. 가짜 라운드 숫자 (99.99%, 50%)
12. 가짜 통계/메트릭 — 사용자가 제공하지 않은 데이터
13. "SYSTEM // 2024" 형식 포매팅
14. AI 카피라이팅 클리셰 ("Elevate", "Seamless", "Unleash", "Next-Gen")
15. "Scroll to explore" 등 필러 UI 텍스트
16. 깨진 Unsplash 링크 (picsum.photos 또는 SVG 아바타 사용)
17. 기본 shadcn/ui 설정 — 반드시 커스터마이징
18. z-index 남용 — Navbar/Modal/Overlay만
19. `h-screen` — `min-h-[100dvh]` 사용
20. 원형 로딩 스피너 — 스켈레톤 쉬머만
