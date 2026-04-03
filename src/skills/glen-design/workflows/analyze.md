# Analyze 모드 — 기존 프로젝트 분석 → DESIGN.md 추출

Stitch 프로젝트 또는 HTML/CSS를 분석하여 9섹션 DESIGN.md를 역추출한다.

## 입력

```
/design analyze --project-id 123456
/design analyze --url https://example.com
/design analyze --file ./index.html
```

## 프로세스

### Stitch 프로젝트 분석 (--project-id)

1. **프로젝트 조회**: `list_projects` → `get_project`
2. **화면 조회**: `list_screens` → `get_screen`
3. **에셋 다운로드**: `htmlCode.downloadUrl`에서 HTML 가져오기
4. **디자인 테마 추출**: `designTheme` 객체에서 색상/폰트/스타일 추출

### URL 분석 (--url)

1. `web_fetch`로 HTML 다운로드
2. CSS 파싱: 색상, 폰트, 스페이싱, border-radius, shadow 추출
3. 컴포넌트 패턴 감지: 버튼, 카드, 네비게이션 등

### 로컬 파일 분석 (--file)

1. HTML/CSS 파일 읽기
2. Tailwind 클래스 또는 인라인 스타일에서 토큰 추출

## 추출 항목

| 항목 | 소스 | 매핑 |
|------|------|------|
| 색상 팔레트 | CSS custom properties, Tailwind config | 섹션 2 |
| 폰트 스택 | font-family 선언 | 섹션 3 |
| 타이포 계층 | h1-h6, p 스타일 | 섹션 3 테이블 |
| 컴포넌트 스타일 | button, card, input 패턴 | 섹션 4 |
| 레이아웃 | grid, max-width, gap | 섹션 5 |
| 그림자/깊이 | box-shadow 선언 | 섹션 6 |
| 반응형 | @media 쿼리 | 섹션 8 |

## 출력

9섹션 [output-format.md](../resources/output-format.md) 형식의 DESIGN.md를 `.stitch/DESIGN.md`에 저장.
커스텀 폰트 발견 시 → 대체 폰트 매핑 제안.
