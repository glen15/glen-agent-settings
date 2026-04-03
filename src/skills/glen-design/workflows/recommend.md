# Recommend 모드 — DB 기반 디자인 시스템 추천

키워드로 스타일, 색상 팔레트, 폰트 페어링, UX 가이드라인을 검색·추천한다.
ui-ux-pro-max의 CSV 데이터베이스(67 스타일, 96 팔레트, 57 폰트 페어링) 활용.

## 입력

```
/design recommend "fintech dark dashboard"
/design recommend "beauty spa wellness" --design-system
/design recommend "animation accessibility" --domain ux
```

## 사용법

### 디자인 시스템 생성 (종합 추천)

```bash
python3 src/skills/glen-design/scripts/search.py "<키워드>" --design-system [-p "프로젝트명"]
```

5개 도메인을 병렬 검색하여 완성된 디자인 시스템 반환:
- 패턴, 스타일, 색상, 타이포그래피, 이펙트
- 안티패턴 포함

### 도메인별 상세 검색

```bash
python3 src/skills/glen-design/scripts/search.py "<키워드>" --domain <도메인> [-n 개수]
```

| 도메인 | 용도 | 예시 키워드 |
|--------|------|-----------|
| `product` | 제품 유형별 추천 | SaaS, e-commerce, portfolio |
| `style` | UI 스타일, 이펙트 | glassmorphism, minimalism, dark |
| `typography` | 폰트 페어링 | elegant, playful, professional |
| `color` | 색상 팔레트 | saas, fintech, beauty |
| `landing` | 페이지 구조, CTA | hero, testimonial, pricing |
| `chart` | 차트 유형 | trend, comparison, funnel |
| `ux` | UX 가이드라인 | animation, accessibility |

### 스택별 가이드라인

```bash
python3 src/skills/glen-design/scripts/search.py "<키워드>" --stack <스택>
```

지원 스택: `html-tailwind`(기본), `react`, `nextjs`, `vue`, `svelte`, `shadcn`, `swiftui`, `react-native`, `flutter`

### 결과 저장

```bash
python3 src/skills/glen-design/scripts/search.py "<키워드>" --design-system --persist -p "프로젝트명"
```

`design-system/MASTER.md` + 페이지별 오버라이드 생성.

## 추천 결과 → DESIGN.md 변환

recommend 결과를 `/design generate`에 입력으로 활용:

1. `/design recommend "fintech dark"` → 추천 확인
2. `/design generate "fintech 다크 대시보드"` → 추천 기반 DESIGN.md 생성

또는 `--design-system --persist`로 바로 저장.
