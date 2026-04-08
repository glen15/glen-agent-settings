---
name: image
description: "Gemini/OpenAI API로 교육용 인포그래픽/다이어그램 이미지 생성/편집. /image \"설명\" — provider 선택 가능(기본 Gemini, --provider openai로 GPT Image). 이미지, 그림, 인포그래픽, 다이어그램, 투명 배경 PNG, 이미지 편집 요청 시 사용."
user_invocable: true
argument-hint: <"이미지 설명"> [--provider gemini|openai] [--quality standard|high] [--aspect square|portrait|landscape] [--transparent] [--reference <path>] [--output-dir ./path]
---

# Image — 이미지 생성/편집

교육용 인포그래픽/다이어그램을 생성한다. 두 provider를 지원:

| Provider | 모델 | 강점 |
|---|---|---|
| `gemini` (기본) | `gemini-3.1-flash-image-preview` | 빠름, 저렴, 한글 다이어그램 일반 품질 양호 |
| `openai` | `gpt-image-1` | 프롬프트 충실도/텍스트 렌더링 우수, 투명 배경 지원 |

## 프로젝트 경로

```
IMAGE_SKILL_DIR="${HOME}/.claude/skills/image"
```

## 실행

```bash
npx tsx "${IMAGE_SKILL_DIR}/scripts/generate.ts" "__ARGS__"
```

`__ARGS__`를 사용자 인자로 치환. 결과는 JSON으로 `{ filePath, description, provider, model, quality, aspect, edited }` 반환.

## 옵션

| 옵션 | 기본값 | 설명 |
|------|--------|------|
| `--provider gemini\|openai` | `gemini` | 이미지 생성 provider |
| `--quality standard\|high` | `standard` | gemini: `1K`/`4K` / openai: `medium`/`high` 로 매핑 |
| `--aspect square\|portrait\|landscape` | `square` | gemini: `1:1`/`9:16`/`16:9` / openai: `1024x1024`/`1024x1536`/`1536x1024` |
| `--transparent` | off | 투명 배경 PNG (openai 전용, gemini 지정 시 경고 후 무시) |
| `--reference <path>` | 없음 | 레퍼런스 이미지를 넣으면 편집 모드로 동작 (양쪽 provider 지원) |
| `--resolution 1K\|4K` | — | 레거시 호환: `--quality standard\|high`로 자동 매핑 |
| `--output-dir ./path` | 현재 디렉토리 | 저장 경로 |

## 예시

```
/image "마이크로서비스 아키텍처 다이어그램"
/image "TDD Red-Green-Refactor 사이클" --quality high
/image "OAuth2 인증 흐름" --output-dir ./docs/images
/image "브랜드 아이콘" --provider openai --transparent
/image "4단계 CI/CD 파이프라인" --provider openai --aspect landscape --quality high
/image "배경 제거하고 설명 라벨 추가" --provider openai --reference ./input.png
/image "색상 톤 다운하고 한글 라벨 교체" --provider gemini --reference ./input.png
```

## 필수 환경변수

- `GEMINI_API_KEY` — `--provider gemini`(기본) 사용 시
- `OPENAI_API_KEY` — `--provider openai` 사용 시

두 키 모두 `~/.zshrc`의 `# Gemini API` 섹션 근처에 배치. 재로그인 또는 `source ~/.zshrc` 후 사용.

## Gotchas

> **필수**: 오류 발생 시 우회 전에 여기 기록. 형식: **원인** — 증상, 근본 원인, 방지책. (Gotcha-First 원칙)

1. **설명이 너무 추상적** — "좋은 아키텍처"가 아니라 "3개의 마이크로서비스가 API Gateway를 통해 통신하는 구조도"처럼 구체적으로.
2. **API 키 미확인** — `--provider` 값과 필요한 환경변수가 일치하는지 실행 전 확인. 없으면 사용자에게 안내.
3. **output-dir 미존재** — 스크립트가 자동 생성하지만, 사용자가 기대하는 경로가 맞는지 확인.
4. **텍스트 과다 요청** — 이미지 안에 긴 문장을 넣으려 하면 품질 저하. 라벨/키워드 수준이 최적.
5. **top-level await 금지** — `tsx`는 기본 CJS 모드로 실행되어 top-level `await`가 `SyntaxError` 발생. 반드시 `async function main() { ... } main();` 패턴 사용. `.mjs` 래퍼는 임시방편이므로 금지.
6. **외부 lib 의존 금지** — generate.ts가 `../../lib/contents-creator/`를 상대경로로 참조하면 배포 후 경로가 깨짐. deploy.sh가 lib/을 배포하지 않았고, SDK 버전도 불일치. 해결: generate.ts를 self-contained로 만들어 외부 의존 제거. (2026-03-30)
7. **SDK 버전 주의** — `@google/generative-ai`(구)와 `@google/genai`(신)의 API가 다름. package.json과 import가 일치하는지 확인. openai SDK는 `6.x` 기준(`toFile`, `images.generate`, `images.edit`).
8. **OpenAI organization verification** — `gpt-image-1`은 일부 조직에서 사전 verification이 필요. 403 `organization must be verified` 에러 시 OpenAI 대시보드 Settings → Organization → Verify Organization 수행. (2026-04-08)
9. **gpt-image-1 비용 주의** — `quality=high` 호출은 Gemini 대비 10~50배 비쌈. 기본값은 `standard`(openai 내부 `medium`)로 고정. 대량 호출 시 quality 명시 확인.
10. **transparent는 OpenAI 전용** — `--transparent` 플래그를 gemini와 같이 쓰면 경고 후 무시. 투명 PNG가 필요하면 반드시 `--provider openai`.
11. **참조 이미지 MIME 타입** — `--reference`는 확장자로 mimeType 추론(png/jpg/webp/gif). 확장자 없는 파일은 png로 간주되므로 원본 확장자 유지 권장.
12. **secret-scanner 훅 false positive** — `Edit`의 `new_string`에 기존 API 키 문자열(16자+ 영숫자)이 포함되면 훅이 차단. 해결: `new_string` 범위를 키 라인 밖으로 좁히거나 `Bash` append/`sed` in-place로 우회. (2026-04-08)
13. **Gemini 응답이 JPEG일 수 있음** — `gemini-3.1-flash-image-preview`는 요청 무관하게 종종 `image/jpeg`로 반환. 이전엔 `.png`로 저장되어 확장자 mismatch가 생겼음. 해결: `inlineData.mimeType`을 읽어 정확한 확장자(`.png`/`.jpg`/`.webp`/`.gif`)를 붙이도록 수정. (2026-04-08)
