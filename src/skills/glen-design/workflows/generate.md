# Generate 모드 — 프리미엄 DESIGN.md 생성

바이브 설명을 받아 [taste-rules](../resources/taste-rules.md) 기반 프리미엄 DESIGN.md를 생성한다.

## 입력

```
/design generate "다크 SaaS 대시보드, 미니멀, 데이터 중심"
```

## 프로세스

### 1. 분위기 다이얼 설정

사용자 설명에서 4개 다이얼을 추론한다:

| 다이얼 | 범위 | 기본값 |
|--------|------|--------|
| Creativity | 1-10 | 9 |
| Density | 1-10 | 5 |
| Variance | 1-10 | 8 |
| Motion | 1-10 | 6 |

- "미니멀" → Creativity 3-4, Variance 2-3
- "대시보드" → Density 7-8
- "크리에이티브" → Creativity 8-9, Variance 7-8
- "랜딩" → Density 3-4, Motion 6-7

### 2. 색상 팔레트 결정

[taste-rules.md](../resources/taste-rules.md)의 색상 규칙 적용:
- 단일 액센트 색상 선택 (채도 < 80%)
- 순수 검정(#000000) 금지 → Off-Black / Zinc-950
- AI 보라 네온 금지
- neutral 베이스: Zinc 또는 Slate 계열

### 3. 폰트 선택

라이선스 무료 폰트만 사용:
- Display: `Geist`, `Satoshi`, `Outfit`, `Cabinet Grotesk`, `Space Grotesk`
- Body: Display와 동일 패밀리 weight 400
- Mono: `Geist Mono`, `JetBrains Mono`
- Inter는 프리미엄 컨텍스트에서 금지

### 4. 9섹션 DESIGN.md 생성

[output-format.md](../resources/output-format.md) 구조를 따라 생성한다.
각 섹션에서 taste-rules의 관련 규칙을 적용.

### 5. 출력

```
.stitch/DESIGN.md  ← 생성된 디자인 시스템
```

## 다이얼 → 규칙 매핑

| 다이얼 조합 | 적용 규칙 |
|------------|----------|
| Variance > 4 | 중앙 정렬 Hero 금지, 비대칭 레이아웃 강제 |
| Density > 7 | 모든 숫자에 Mono 폰트, 카드 대신 border-top 구분자 |
| Creativity > 7 | 인라인 이미지 타이포 적용, 강한 스케일 대비 |
| Motion > 5 | 스프링 물리, 스태거 캐스케이드 문서화 |
