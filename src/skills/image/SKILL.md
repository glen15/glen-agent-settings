---
name: image
description: "Gemini API로 교육용 인포그래픽/다이어그램 이미지 생성. /image \"설명\" — 설명 기반 단일 이미지 생성. 이미지, 그림, 인포그래픽, 다이어그램 생성 요청 시 사용."
user_invocable: true
argument-hint: <"이미지 설명"> [--resolution 1K|4K] [--output-dir ./path]
---

# Image — 이미지 생성

Gemini API(`gemini-3.1-flash-image-preview`)로 교육용 인포그래픽/다이어그램을 생성한다.
`create-content`의 이미지 생성 기능을 독립 스킬로 분리한 것.

## 프로젝트 경로

```
IMAGE_SKILL_DIR="${HOME}/.claude/skills/image"
```

## 실행

```bash
npx tsx "${IMAGE_SKILL_DIR}/scripts/generate.ts" "__ARGS__"
```

`__ARGS__`를 사용자 인자로 치환. 결과는 JSON으로 `{ filePath, description, resolution }` 반환.

## 옵션

| 옵션 | 기본값 | 설명 |
|------|--------|------|
| `--resolution 1K\|4K` | `1K` | 이미지 해상도 |
| `--output-dir ./path` | 현재 디렉토리 | 저장 경로 |

## 예시

```
/image "마이크로서비스 아키텍처 다이어그램"
/image "TDD Red-Green-Refactor 사이클" --resolution 4K
/image "OAuth2 인증 흐름" --output-dir ./docs/images
```

## 필수 환경변수

- `GEMINI_API_KEY` — 없으면 에러 발생

## Gotchas

> **필수**: 오류 발생 시 우회 전에 여기 기록. 형식: **원인** — 증상, 근본 원인, 방지책. (Gotcha-First 원칙)

1. **설명이 너무 추상적** — "좋은 아키텍처"가 아니라 "3개의 마이크로서비스가 API Gateway를 통해 통신하는 구조도"처럼 구체적으로.
2. **GEMINI_API_KEY 미확인** — 실행 전 환경변수 존재 여부 확인. 없으면 사용자에게 안내.
3. **output-dir 미존재** — 스크립트가 자동 생성하지만, 사용자가 기대하는 경로가 맞는지 확인.
4. **텍스트 과다 요청** — 이미지 안에 긴 문장을 넣으려 하면 품질 저하. 라벨/키워드 수준이 최적.
5. **top-level await 금지** — `tsx`는 기본 CJS 모드로 실행되어 top-level `await`가 `SyntaxError` 발생. 반드시 `async function main() { ... } main();` 패턴 사용. `.mjs` 래퍼는 임시방편이므로 금지.
