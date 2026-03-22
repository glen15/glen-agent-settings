---
name: video
description: "Remotion으로 React 기반 비디오 생성. /video \"설명\" — 프롬프트 기반 비디오 제작. /video init — 프로젝트 초기화. /video render — 렌더링. 비디오, 애니메이션, 모션 그래픽 요청 시 사용."
user_invocable: true
argument-hint: <"비디오 설명"> | init | render [composition-id]
---

# Video — Remotion 비디오 생성

프롬프트로 React 기반 비디오를 생성한다. Remotion + TailwindCSS 스택.

## 명령어

| 명령 | 설명 | 예시 |
|------|------|------|
| `init` | Remotion 프로젝트 생성 + 공식 스킬 설치 | `/video init` |
| `"설명"` | 프롬프트 기반 비디오 제작 | `/video "30초 서비스 소개 숏폼"` |
| `render [id]` | Composition 렌더링 (MP4) | `/video render MyVideo` |
| (인자 없음) | 현재 프로젝트 상태 확인 | `/video` |

## 실행 로직

### `__ARGS__` 파싱

```
RAW_ARGS="__ARGS__"

case:
  "init"            → init 플로우
  "render ..."      → render 플로우
  "" (빈값)         → 상태 확인
  그 외             → 비디오 생성 플로우 (RAW_ARGS = 비디오 설명)
```

### `init` — 프로젝트 초기화

1. **기존 프로젝트 감지**: `package.json`에 `remotion` 의존성이 있는지 확인
   - **있으면**: "이미 Remotion 프로젝트입니다. 스킬만 재설치할까요?" 확인
   - **없으면**: 프로젝트명을 사용자에게 확인 후 진행

2. **프로젝트 생성**:
```bash
npx create-video@latest --template blank --tailwind
cd <프로젝트명> && npm install
```

3. **Remotion 공식 스킬 설치**:
```bash
npx skills add remotion-dev/skills
```

4. **개발 서버 시작 안내**:
```bash
npm run dev
```

### `"설명"` — 비디오 생성

#### Step 1: 환경 확인

1. `package.json`에 `remotion` 의존성 확인 → 없으면 `/video init` 안내
2. `.claude/skills/remotion/` 존재 확인 → 없으면 `npx skills add remotion-dev/skills` 실행

#### Step 2: 도메인 지식 로드

프로젝트의 `.claude/skills/remotion/` 에서 필요한 rule 파일을 읽는다.

**항상 읽을 파일:**
- `rules/compositions.md` — Composition 정의
- `rules/animations.md` — 애니메이션 기본 (useCurrentFrame 필수)
- `rules/timing.md` — interpolate, spring, easing

**주제에 따라 추가 로드:**
| 요청 키워드 | rule 파일 |
|-------------|-----------|
| 자막, 캡션 | `rules/subtitles.md`, `rules/display-captions.md` |
| 오디오, 음악, 소리 | `rules/audio.md`, `rules/audio-visualization.md`, `rules/sfx.md` |
| 트랜지션, 전환 | `rules/transitions.md`, `rules/sequencing.md` |
| 텍스트 애니메이션 | `rules/text-animations.md`, `rules/fonts.md` |
| 이미지, 사진 | `rules/images.md`, `rules/assets.md` |
| 비디오 삽입 | `rules/videos.md`, `rules/trimming.md` |
| 3D | `rules/3d.md` |
| 차트, 데이터 | `rules/charts.md` |
| GIF | `rules/gifs.md` |
| 지도 | `rules/maps.md` |
| Lottie | `rules/lottie.md` |
| 보이스오버, TTS | `rules/voiceover.md` |
| 투명 배경 | `rules/transparent-videos.md` |

#### Step 3: 구성 설계 → 사용자 확인

비디오 설명을 기반으로 설계안을 작성하고 **사용자 확인을 받은 후** 코딩 시작:

1. **Composition 설정** — 해상도, FPS, 길이
   - 기본: 1080x1920 (세로, 숏폼), 30fps
   - 가로: 1920x1080 (유튜브)
   - 정사각: 1080x1080 (인스타)
2. **씬 분해** — 비디오를 씬 단위로 나눔
3. **타이밍 계획** — 각 씬의 시작/끝 프레임

사용자 승인 후 Step 4로.

#### Step 4: 코드 작성

**필수 규칙 (Remotion 공식):**
- 모든 애니메이션은 `useCurrentFrame()` 기반 — CSS transition/animation **금지**
- Tailwind 애니메이션 클래스 **금지** (`animate-*` 등)
- `interpolate()` 또는 `spring()`으로 값 계산
- `<Sequence>`로 씬 시퀀싱
- props는 `type` 선언 (interface 아님)

**파일 구조:**
```
src/
  Root.tsx              — Composition 등록
  compositions/
    MyVideo.tsx         — 메인 컴포지션
    scenes/
      Scene1.tsx        — 개별 씬
      Scene2.tsx
  styles/               — 공유 스타일
```

#### Step 5: 프리뷰 확인

개발 서버가 실행 중이면 브라우저에서 바로 확인 가능.
사용자에게 프리뷰 확인 후 피드백 요청.

### `render [composition-id]` — 렌더링

1. composition-id 생략 시 `src/Root.tsx`에서 기본 Composition을 찾음
2. 사용자에게 출력 설정 확인:
```bash
npx remotion render <composition-id> --output out/video.mp4
```

### 인자 없음 — 상태 확인

1. Remotion 프로젝트 여부: `package.json` 확인
2. 공식 스킬 설치 여부: `.claude/skills/remotion/` 확인
3. Composition 목록: `src/Root.tsx`에서 Composition id 추출
4. 개발 서버 실행 여부 확인

## Gotchas

> Claude가 비디오 생성에서 자주 실수하는 것. 실패할 때마다 한 줄 추가.

1. **CSS 애니메이션 사용** — `transition`, `animation`, Tailwind `animate-*` 모두 금지. 반드시 `useCurrentFrame()` + `interpolate()`/`spring()`.
2. **Remotion 스킬 미로드** — 코드 작성 전 반드시 관련 rule 파일을 읽어야 한다. 읽지 않으면 잘못된 패턴 사용.
3. **프레임 계산 오류** — 초 단위 × fps = 프레임. `2초 × 30fps = 60프레임`. 직접 프레임 숫자를 하드코딩하지 말고 `초 * fps` 패턴 사용.
4. **extrapolate 미설정** — `interpolate()`에 `extrapolateRight: "clamp"` 누락하면 값이 범위를 벗어남.
5. **Remotion 스킬 미설치** — `.claude/skills/remotion/` 없으면 `npx skills add remotion-dev/skills` 실행 안내.
6. **설계 확인 없이 코딩 시작** — 씬 구성과 타이밍을 사용자에게 확인받은 후 코드 작성.
