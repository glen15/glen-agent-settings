---
name: create-content
description: "URL, 파일(.md/.pdf/.json), GitHub 레포, 로컬 폴더를 입력받아 구조화된 한글 마크다운 콘텐츠와 이미지를 생성한다. 콘텐츠 생성, 글 정리, 요약이 필요할 때 사용."
user_invocable: true
argument-hint: <입력> [--images]
allowed-tools: Bash, Read, Write, Glob, Grep
---

# Contents Creator

입력 소스 → 구조화된 한글 콘텐츠 생성 파이프라인.

## 프로젝트 경로

```
CONTENTS_CREATOR_DIR="/Users/glen/Desktop/work/glen-contents-creator"
```

## 워크플로우 (3단계)

### Step 1: 소스 읽기

```bash
cd "${CONTENTS_CREATOR_DIR}" && npx tsx src/index.ts read $ARGUMENTS[0]
```

이 명령은 JSON을 stdout에 출력한다. `text` 필드에 원문 텍스트가 담긴다.

**Fallback — 인증/SPA 페이지**: 위 명령이 빈 텍스트를 반환하거나 JS 렌더링이 필요한 경우:

```bash
# 1. 실제 Chrome 프로필로 열기 (로그인 유지)
browser-use --profile open "<URL>"
# 2. 페이지 로드 대기
browser-use wait text "<페이지 핵심 텍스트>"
# 3. 본문 HTML 추출
browser-use get html --selector "article, main, .content"
# 4. 무한 스크롤 페이지인 경우
browser-use scroll down && browser-use scroll down && browser-use get html
# 5. 세션 정리
browser-use close
```

추출한 HTML에서 텍스트를 파싱하여 Step 2의 `text` 입력으로 사용한다.

### Step 2: Plan JSON 생성 (너=Claude Code가 직접 수행)

Step 1의 `text`를 분석하여 아래 스키마의 JSON을 생성한다.
`${CONTENTS_CREATOR_DIR}/tmp/plan.json`에 저장한다.

**Plan JSON 스키마:**

```json
{
  "title": "한글 제목 (원문 제목 그대로 복사 금지, 재구성)",
  "author": "원문 저자/출처",
  "category": "카테고리",
  "keywords": ["키워드1", "키워드2", ...],
  "summary": "한글 3~5문장 요약",
  "tldrBullets": ["핵심1", "핵심2", "핵심3", "핵심4", "핵심5"],
  "sections": [
    {
      "heading": "섹션 제목",
      "imagePlaceholder": "이 섹션을 설명하는 이미지 묘사 (선택)",
      "toggleTitle": "토글 제목",
      "bullets": ["포인트1", "포인트2", ...]
    }
  ]
}
```

**검증 규칙 (hard):**
- `title`: 한글 포함 필수
- `summary`: 한글 3~5문장
- `tldrBullets`: 정확히 5개
- `sections`: 최소 2개
- `imagePlaceholder`: 전체 3~5개 (섹션당 0~1개)

**품질 규칙 (soft):**
- 개발 경험 없는 사람도 이해할 수 있게
- 전문 용어는 한글 풀이 + 괄호로 영어 병기
- 토글 펼치면 A4 약 2장 분량 체감
- 비유/사례/실무 관점 포함

### Step 3: 렌더링 (+ 이미지)

```bash
cd "${CONTENTS_CREATOR_DIR}" && npx tsx src/index.ts render tmp/plan.json --output file
```

이미지 생성이 필요하면:

```bash
cd "${CONTENTS_CREATOR_DIR}" && npx tsx src/index.ts render tmp/plan.json --images --output file
```

결과물은 `output/` 디렉토리에 저장된다:
- `output/<제목>.md` — 마크다운
- `output/<제목>.plan.json` — Plan JSON

## 입력 타입

| 입력 | 감지 기준 |
|------|-----------|
| URL | `https?://` (GitHub 외) |
| .md | 확장자 `.md` |
| .pdf | 확장자 `.pdf` |
| .json | 확장자 `.json` |
| GitHub | `github.com/owner/repo` |
| 폴더 | 디렉토리 경로 |

## Gotchas

> Claude가 콘텐츠 생성에서 자주 실수하는 것. 실패할 때마다 한 줄 추가.

1. **원문 제목 그대로 복사** — title은 반드시 한글로 재구성. 원문 영어 제목을 그대로 넣지 않기.
2. **tldrBullets 개수 틀림** — 정확히 5개여야 한다. 4개나 6개로 생성하는 경향.
3. **전문 용어 풀이 누락** — 개발 경험 없는 독자 기준. 전문 용어는 한글 풀이 + 괄호 영어 병기.
4. **imagePlaceholder 과다/과소** — 전체 3~5개 범위. 모든 섹션에 넣거나 하나도 안 넣는 경향.
