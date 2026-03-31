---
name: pretext
description: "Pretext로 DOM 없이 텍스트 레이아웃 계산. /pretext measure \"텍스트\" — 높이/줄 수 측정. /pretext shrinkwrap — 최적 너비 계산. /pretext frames — Remotion 프레임 타이밍 자동 배분. 텍스트 레이아웃, 가상 스크롤, 영상 캡션 자동화 시 사용."
user_invocable: true
argument-hint: measure "텍스트" [--width N] | shrinkwrap "텍스트" [--max-width N] | frames "캡션들..." [--fps 30] | install
---

# Pretext — DOM-Free 텍스트 레이아웃 엔진

Pretext(`@chenglou/pretext`)를 활용한 텍스트 측정·레이아웃 계산 스킬.
DOM 측정 없이 순수 산술로 텍스트 높이, 줄 수, 최적 너비를 계산한다.

## 핵심 제약

- **브라우저 환경 필수**: Canvas API(또는 OffscreenCanvas) 필요. 순수 Node.js에서는 동작하지 않음
- **Remotion 호환**: Remotion은 React(브라우저) 기반이므로 자연스럽게 호환
- **폰트 동기화 필수**: CSS `font` 선언과 prepare()의 font 인자를 반드시 일치시켜야 함

## 명령어

| 명령 | 설명 | 예시 |
|------|------|------|
| `install` | 현재 프로젝트에 Pretext 설치 | `/pretext install` |
| `measure "텍스트"` | 텍스트 높이/줄 수 측정 코드 생성 | `/pretext measure "안녕하세요" --width 300` |
| `shrinkwrap "텍스트"` | 최적 너비 계산 코드 생성 | `/pretext shrinkwrap "채팅 메시지"` |
| `frames "캡션들"` | Remotion 프레임 타이밍 자동 배분 | `/pretext frames --fps 30` |
| (인자 없음) | 설치 여부 + API 가이드 표시 | `/pretext` |

## 실행 로직

### `__ARGS__` 파싱

```
RAW_ARGS="__ARGS__"

case:
  "install"         → install 플로우
  "measure ..."     → measure 플로우
  "shrinkwrap ..."  → shrinkwrap 플로우
  "frames ..."      → frames 플로우
  "" (빈값)         → 상태 확인 + API 가이드
```

### `install` — Pretext 설치

1. `package.json` 확인 → 없으면 안내
2. `@chenglou/pretext` 이미 있는지 확인
3. 설치:
```bash
npm install @chenglou/pretext
```
4. 설치 확인 후 간단한 사용법 안내

### `measure` — 텍스트 높이/줄 수 측정

사용자가 제공한 텍스트를 측정하는 코드를 생성한다.

#### 옵션
| 옵션 | 기본값 | 설명 |
|------|--------|------|
| `--width` | 300 | 컨테이너 너비 (px) |
| `--font` | `"16px Inter, sans-serif"` | CSS font shorthand |
| `--line-height` | 20 | 줄 높이 (px) |

#### 생성하는 코드 패턴

```typescript
import { prepare, layout } from '@chenglou/pretext'

const prepared = prepare(text, font)
const { height, lineCount } = layout(prepared, maxWidth, lineHeight)
```

프로젝트 컨텍스트에 맞게 코드를 삽입한다:
- **Remotion 프로젝트**: 컴포넌트 내부에 직접 삽입
- **React 프로젝트**: 커스텀 훅 `useTextLayout()` 생성
- **일반 프로젝트**: 유틸리티 함수로 생성

### `shrinkwrap` — 최적 너비 계산

줄 수를 유지하면서 가장 좁은 너비를 찾는다. CSS `fit-content`로는 불가능한 기능.

#### 핵심 API: `walkLineRanges()`

```typescript
import { prepareWithSegments, walkLineRanges } from '@chenglou/pretext'

function shrinkwrap(text: string, font: string, maxWidth: number): number {
  const prepared = prepareWithSegments(text, font)
  let maxLineWidth = 0
  walkLineRanges(prepared, maxWidth, line => {
    if (line.width > maxLineWidth) maxLineWidth = line.width
  })
  return Math.ceil(maxLineWidth)
}
```

#### 활용 시나리오
- 채팅 말풍선 너비 최적화
- 툴팁/팝오버 크기 자동 조정
- 버튼/태그 내 텍스트 맞춤

### `frames` — Remotion 프레임 타이밍 자동 배분

캡션 텍스트의 줄 수를 기반으로 Remotion `<Sequence>` 프레임 타이밍을 자동 계산한다.

#### 옵션
| 옵션 | 기본값 | 설명 |
|------|--------|------|
| `--fps` | 30 | 프레임 레이트 |
| `--width` | 400 | 캡션 영역 너비 (px) |
| `--font` | `"14px Inter, sans-serif"` | 캡션 폰트 |
| `--line-height` | 20 | 줄 높이 |
| `--sec-per-line` | 1.0 | 줄당 표시 시간 (초) |

#### 생성하는 코드 패턴

```tsx
import { prepare, layout } from '@chenglou/pretext'

// 캡션별 프레임 계산
const captions = [
  { text: '첫 번째 캡션', font: '14px Inter, sans-serif' },
  { text: '두 번째 캡션', font: '14px Inter, sans-serif' },
]

const FPS = 30
const SEC_PER_LINE = 1.0
const CAPTION_WIDTH = 400
const LINE_HEIGHT = 20

const sequences = captions.map((cap, i) => {
  const prepared = prepare(cap.text, cap.font)
  const { lineCount, height } = layout(prepared, CAPTION_WIDTH, LINE_HEIGHT)
  const durationInFrames = Math.ceil(lineCount * SEC_PER_LINE * FPS)
  return { ...cap, lineCount, height, durationInFrames }
})

// Remotion <Sequence> 자동 생성
let frameOffset = 0
const sequenceElements = sequences.map((seq, i) => {
  const el = { from: frameOffset, durationInFrames: seq.durationInFrames, caption: seq.text }
  frameOffset += seq.durationInFrames
  return el
})
```

사용자에게 계산 결과 표로 보여준 뒤, 확인 후 코드를 삽입한다:
```
씬 1: "첫 번째 캡션" → 2줄, 60프레임 (2.0초)
씬 2: "두 번째 캡션" → 1줄, 30프레임 (1.0초)
총: 90프레임 (3.0초)
```

## 다른 스킬에서 참조하는 방법

### `/video` 스킬에서 사용

`/video` 실행 중 텍스트 오버레이/캡션이 필요할 때:

1. Pretext 설치 여부 확인 (`package.json`에 `@chenglou/pretext`)
2. 미설치면 자동 설치
3. 캡션 텍스트 배열 → `frames` 로직으로 프레임 배분 계산
4. 결과를 `<Sequence>` 구성에 반영

```
참조: /pretext의 "frames" 섹션 → Remotion Sequence 자동 생성 패턴
```

### `/stitch-remotion` 스킬에서 사용

워크스루 영상의 텍스트 오버레이 배치 시:

1. 각 스크린의 description 텍스트를 Pretext로 측정
2. 줄 수 기반으로 해당 스크린의 표시 시간 자동 결정
3. shrinkwrap으로 캡션 박스 너비 최적화

```
참조: /pretext의 "shrinkwrap" + "frames" 섹션
```

### 임의의 스킬에서 Pretext 패턴 사용

Pretext의 핵심 패턴 3가지:

```typescript
// 패턴 1: 높이 측정 (가장 기본)
import { prepare, layout } from '@chenglou/pretext'
const { height, lineCount } = layout(prepare(text, font), width, lineHeight)

// 패턴 2: 최적 너비 (shrinkwrap)
import { prepareWithSegments, walkLineRanges } from '@chenglou/pretext'
let maxW = 0
walkLineRanges(prepareWithSegments(text, font), width, l => { if (l.width > maxW) maxW = l.width })

// 패턴 3: 줄별 상세 정보
import { prepareWithSegments, layoutWithLines } from '@chenglou/pretext'
const { lines } = layoutWithLines(prepareWithSegments(text, font), width, lineHeight)
// lines[i].text, lines[i].width 사용 가능

// 패턴 4: 가변 너비 (플로팅 이미지 주변 텍스트)
import { prepareWithSegments, layoutNextLine } from '@chenglou/pretext'
let cursor = { segmentIndex: 0, graphemeIndex: 0 }
while (true) {
  const line = layoutNextLine(prepared, cursor, currentWidth)
  if (!line) break
  cursor = line.end
}
```

## API 레퍼런스 (빠른 참조)

| 함수 | 입력 | 출력 | 용도 |
|------|------|------|------|
| `prepare(text, font, opts?)` | 텍스트, CSS font | `PreparedText` (불투명) | 1회 분석 (비싼 단계) |
| `layout(prepared, maxWidth, lineHeight)` | PreparedText, px, px | `{ height, lineCount }` | 높이 계산 (싼 단계) |
| `prepareWithSegments(text, font, opts?)` | 텍스트, CSS font | `PreparedTextWithSegments` | 줄별 정보 필요 시 |
| `layoutWithLines(prepared, maxWidth, lineHeight)` | PreparedTextWithSegments, px, px | `{ height, lineCount, lines[] }` | 줄별 텍스트/너비 |
| `walkLineRanges(prepared, maxWidth, onLine)` | PreparedTextWithSegments, px, 콜백 | 줄 수 (number) | shrinkwrap, 너비 탐색 |
| `layoutNextLine(prepared, cursor, maxWidth)` | PreparedTextWithSegments, cursor, px | `LayoutLine \| null` | 가변 너비 레이아웃 |
| `clearCache()` | - | void | 캐시 정리 |
| `setLocale(locale?)` | locale 문자열 | void | 로케일 변경 |

### 성능 특성

- `prepare()`: ~19ms / 500건 (비싼 단계, 1회만 실행)
- `layout()`: ~0.09ms / 500건 (싼 단계, 반복 호출 OK)
- 외부 의존성 없음, 수 KB 크기

### 주의사항

- `font` 인자는 CSS font shorthand 형식: `"16px Inter"`, `"bold 18px 'Helvetica Neue'"`
- `system-ui`는 macOS에서 정확도 낮음 → 명시적 폰트명 사용
- `{ whiteSpace: 'pre-wrap' }` 옵션으로 textarea 모드 가능 (공백/탭/줄바꿈 보존)

## Gotchas

> **필수**: 오류 발생 시 우회 전에 여기 기록. 형식: **원인** — 증상, 근본 원인, 방지책. (Gotcha-First 원칙)

1. **Node.js에서 직접 실행 불가** — `OffscreenCanvas or DOM canvas context` 에러 발생. Pretext는 브라우저 Canvas API 필요. Remotion/React 프로젝트 내에서 사용하거나, 브라우저 기반 스크립트로 실행.
2. **폰트 불일치** — prepare()의 font와 실제 CSS font가 다르면 높이 계산이 틀림. 반드시 동일한 font shorthand 사용.
3. **system-ui 폰트 부정확** — macOS에서 system-ui 사용 시 레이아웃 정확도 낮음. `"16px Inter"` 등 명시적 폰트명 사용.
4. **prepare() 반복 호출** — prepare()는 비싼 연산. 같은 텍스트+폰트 조합은 결과를 캐싱하거나 1회만 호출. layout()은 반복 호출 OK.
