# Review 모드 — Pre-Delivery 품질 검증

UI 코드 작성 후 배포 전에 실행하는 품질 체크리스트.

## 입력

```
/design review
/design review --file ./src/pages/index.tsx
/design review --strict   # Vercel Web Interface Guidelines 100+ 규칙 추가 적용
```

## 검증 레이어

1. **Layer 1 — glen 내장 체크리스트** (아래 7개 섹션, 항상 실행)
2. **Layer 2 — Vercel Web Interface Guidelines** (`--strict` 또는 사용자 요청 시)
   - 원격 fetch: `https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md`
   - 출처: [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) web-design-guidelines 스킬
   - 100+ 규칙: Accessibility (ARIA, 키보드, 시맨틱 HTML), Typography (ellipsis, curly quotes, tabular-nums), Layout (truncate, CLS 방지, lazy loading), Interactivity (focus-visible, autocomplete, 에러 처리), Performance (가상화, preconnect, font preload)
   - WebFetch로 최신 규칙을 가져와 지정된 파일에 적용 → `file:line` 형식으로 출력

## 체크리스트

### 1. 시각 품질 (CRITICAL)

- [ ] 이모지를 아이콘으로 사용하지 않음 (SVG: Heroicons/Lucide)
- [ ] 모든 아이콘이 일관된 아이콘 세트에서 제공됨
- [ ] 브랜드 로고가 정확함 (Simple Icons 검증)
- [ ] hover 상태가 레이아웃 시프트를 유발하지 않음
- [ ] 순수 검정(#000000) 미사용 — Off-Black/Zinc-950 사용

### 2. 인터랙션 (CRITICAL)

- [ ] 클릭 가능 요소에 `cursor-pointer` 적용
- [ ] hover 상태가 명확한 시각 피드백 제공
- [ ] 트랜지션 150-300ms 범위
- [ ] 키보드 네비게이션용 focus 상태 표시
- [ ] 비동기 작업 중 버튼 비활성화

### 3. 라이트/다크 모드 (HIGH)

- [ ] 라이트 모드 텍스트 대비 4.5:1 이상
- [ ] 투명 요소가 라이트 모드에서 보임
- [ ] 보더가 양쪽 모드에서 보임
- [ ] 양쪽 모드 테스트 완료

### 4. 레이아웃 & 반응형 (HIGH)

- [ ] 375px, 768px, 1024px, 1440px 뷰포트 확인
- [ ] 모바일에서 가로 스크롤 없음
- [ ] 고정 네비바 뒤에 콘텐츠 숨김 없음
- [ ] 일관된 max-width 사용
- [ ] `min-h-[100dvh]` 사용 (`h-screen` 아님)

### 5. 접근성 (HIGH)

- [ ] 이미지에 alt 텍스트
- [ ] 폼 입력에 label 연결
- [ ] 색상만으로 정보 전달하지 않음
- [ ] `prefers-reduced-motion` 존중
- [ ] 터치 타겟 최소 44x44px

### 6. 타이포그래피 (MEDIUM)

- [ ] body 줄 높이 1.5-1.75
- [ ] 줄 길이 65-75자 제한
- [ ] heading/body 폰트 성격 매칭
- [ ] 모바일 body 최소 16px

### 7. 안티패턴 검출 (MEDIUM)

- [ ] AI 보라 네온 그라디언트 없음
- [ ] "3열 동일 카드" 패턴 없음
- [ ] AI 카피라이팅 클리셰 없음 ("Elevate", "Seamless", "Unleash")
- [ ] 가짜 통계/메트릭 없음
- [ ] `LABEL // YEAR` 포매팅 없음
- [ ] 깨진 Unsplash 링크 없음

## 브라우저 시각 검증 (선택)

개발 서버 실행 중이면:

```bash
# 라이트 모드 스크린샷
browser-use open http://localhost:3000/<path>
browser-use screenshot ./artifacts/ui-light.png

# 다크 모드 스크린샷
browser-use eval "document.documentElement.classList.toggle('dark')"
browser-use screenshot ./artifacts/ui-dark.png

# 모바일 뷰포트 (375px)
browser-use eval "document.body.style.maxWidth='375px'"
browser-use screenshot ./artifacts/ui-mobile.png

# 가로 스크롤 확인
browser-use eval "document.documentElement.scrollWidth > document.documentElement.clientWidth"

browser-use close
```

## Layer 2 — Vercel Web Interface Guidelines (선택)

`--strict` 플래그 또는 "엄격한 리뷰" 요청 시 실행. 외부 의존 — 네트워크 필요.

### 실행 절차

1. WebFetch로 최신 규칙 로드:
   ```
   https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md
   ```
2. 사용자가 지정한 파일(`--file`) 또는 프롬프트로 받은 파일 읽기
3. 가져온 규칙 전체에 대해 파일 검사
4. `file:line` 형식으로 위반 항목 출력 (규칙명 + 수정 제안)

### 규칙 카테고리 요약

| 카테고리 | 주요 검증 항목 |
|---------|--------------|
| **Accessibility** | 아이콘 버튼 `aria-label`, 폼 `<label>`, 키보드 핸들러, 시맨틱 HTML, 헤딩 계층, `scroll-margin-top` |
| **Typography** | ellipsis `…` (… 아님), curly quotes, `&nbsp;`, `tabular-nums`, `text-wrap: balance` |
| **Layout** | `truncate`, `line-clamp`, `min-w-0`, 빈 상태, 이미지 `width`/`height`, `loading="lazy"` |
| **Interactivity** | `focus-visible:ring-*`, `autocomplete`, 페이스트 차단 금지, 라벨 클릭 가능, 인라인 에러 |
| **Performance** | 리스트 >50 가상화, `preconnect`, 폰트 `preload` + `font-display: swap` |

### 출력 예시

```
src/components/Button.tsx:12  [a11y] 아이콘 버튼에 aria-label 누락
src/pages/index.tsx:45  [typography] ellipsis가 "..." — "…"로 변경
src/layouts/Main.tsx:78  [layout] 이미지에 width/height 없음 — CLS 위험
```

## 결과 보고

체크리스트 결과를 요약하여 보고:
- PASS: 모든 항목 통과
- WARN: MEDIUM 항목 미통과 (개선 권장)
- FAIL: CRITICAL/HIGH 항목 미통과 (수정 필수)
- STRICT-FAIL: Layer 2 Vercel 규칙 미통과 (CI 블록)
