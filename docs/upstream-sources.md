# Upstream Sources

이 프로젝트에 통합된 외부 스킬/플러그인/라이브러리/리소스의 원본 출처를 추적한다.
새로운 외부 자산을 통합할 때마다 이 파일을 업데이트할 것.

## 왜 필요한가

- **라이선스 준수**: MIT/Apache 등 원본 라이선스의 출처 명시 요구 충족
- **재싱크 가능성**: 업스트림 업데이트 반영 시 어디서 왔는지 추적
- **크레딧**: 원작자에게 합당한 인정

## Skills (`src/skills/`)

### Stitch 디자인 스킬 6개
- **스킬**: `stitch-design`, `stitch-enhance-prompt`, `stitch-loop`, `stitch-react-components`, `stitch-remotion`, `stitch-shadcn-ui`
- **출처**: https://github.com/google-labs-code/stitch-skills
- **라이선스**: Apache License 2.0
- **통합 방식**: `npx skills add google-labs-code/stitch-skills --skill <name> --global` + frontmatter 조정 (한글 description, user_invocable, argument-hint)
- **통합일**: 2026-03-31 (커밋 `85df73f`)
- **글렌 커스터마이징**: glen-design 스킬로 일부 기능 통합 (stitch-design + stitch-taste-design + ui-ux-pro-max → /design 단일 진입점)

### pretext — DOM-Free 텍스트 레이아웃
- **스킬**: `pretext`
- **출처**: https://github.com/chenglou/pretext (npm: `@chenglou/pretext`)
- **라이선스**: MIT
- **통합 방식**: 래퍼 스킬 — 라이브러리는 npm install, 스킬은 자체 작성. Remotion CaptionSequence 템플릿 포함
- **통합일**: 2026-03-31 (커밋 `8407adb`)
- **용도**: 텍스트 측정, shrinkwrap, Remotion 프레임 타이밍 자동 배분

### video — Remotion 비디오 생성
- **스킬**: `video`
- **출처**: https://github.com/remotion-dev/skills (공식 Remotion 스킬)
- **라이선스**: MIT
- **통합 방식**: 글렌 자체 진입점 스킬(`/video`)이 공식 스킬을 자동 설치 + 래핑. 사용 시 `.claude/skills/remotion/`에서 필요한 rule 파일만 로드
- **용도**: React + Remotion 기반 비디오 생성

### notebooklm — Google NotebookLM 통합
- **스킬**: `notebooklm`
- **출처**: https://github.com/teng-lin/notebooklm-py
- **라이선스**: 저장소 참조 (Unofficial Python API)
- **통합 방식**: PyPI/태그 기반 pip 설치 + 스킬 래퍼. Web UI에 없는 기능까지 프로그래매틱 접근
- **주의**: `main` 브랜치 직접 설치 금지. 반드시 PyPI 또는 릴리스 태그 사용

### better-icons — 200,000+ 아이콘 검색/가져오기
- **스킬**: `better-icons`
- **출처**: https://github.com/better-auth/better-icons (892 stars, MIT)
- **라이선스**: MIT License
- **통합 방식**: SKILL.md 복제 (본문 영어 유지) + glen frontmatter 조정 (user_invocable, 한글 description, argument-hint)
- **의존성**: `npm install -g better-icons` CLI (또는 npx/bunx). MCP 서버 모드 지원.
- **Gotchas 추가**: glen-design의 anti-emoji 정책 연결 (UI 아이콘은 이모지 대신 Iconify 컬렉션)
- **용도**: Lucide, Heroicons, Material Design 등 150+ 컬렉션에서 SVG 아이콘 검색·다운로드
- **결핍 해소**: glen에 완전히 비어있던 아이콘 영역

---

## Plugins (`src/plugins.json`)

`deploy.sh`가 이 매니페스트를 기반으로 Claude Code 플러그인을 자동 설치한다.

| ID | 출처 | 용도 |
|----|------|------|
| `claude-hud@claude-hud` | https://github.com/jarrodwatts/claude-hud | Claude Code HUD 상태바 |
| `notion-workspace-plugin@notion-plugin-marketplace` | https://github.com/makenotion/claude-code-notion-plugin | Notion 워크스페이스 통합 |
| `swift-lsp@claude-plugins-official` | https://github.com/anthropics/claude-plugins-official | Swift LSP 지원 |
| `frontend-design@claude-plugins-official` | https://github.com/anthropics/claude-plugins-official | Stitch 프론트엔드 디자인 MCP |
| `slack@claude-plugins-official` | https://github.com/anthropics/claude-plugins-official | Slack 채널 연동 |
| `telegram@claude-plugins-official` | https://github.com/anthropics/claude-plugins-official | Telegram 봇 채널 연동 |
| `last30days@last30days-skill` | https://github.com/mvanhorn/last30days-skill | 지난 30일 딥 리서치 (Reddit, X, YouTube, HN 등) |
| `frontend-slides@frontend-slides` | https://github.com/zarazhangrui/frontend-slides | 제로 디펜던시 HTML 프레젠테이션 생성 (12 스타일 프리셋, PPT 변환, PDF export) |

---

## Resources / Data

### glen-design 프리셋 58개
- **위치**: `src/skills/glen-design/resources/presets/*.md`
- **출처**: https://github.com/VoltAgent/awesome-design-md
- **라이선스**: MIT License (Copyright (c) VoltAgent)
- **통합 방식**: `scripts/sync-presets.sh` 자동 싱크 — tarball 다운로드 → 헤더 주입 → 폰트 치환 → 저장
- **수정 내역**:
  - 라이선스 필요 커스텀 폰트 → 무료 대체 (`scripts/font-substitutions.tsv`, 121 규칙)
  - 제목 정규화: "Design System Inspiration of X" → "Design System: X"
  - 파일명 정규화: 도메인 접미사 제거 (`linear.app` → `linear`, `mistral.ai` → `mistral` 등)
- **통합일**: 2026-04-08 (커밋 `40c0ce6`)
- **재싱크**: `./src/skills/glen-design/scripts/sync-presets.sh`

### Vercel Web Interface Guidelines (참조 통합)
- **위치**: `src/skills/glen-design/workflows/review.md`에서 Layer 2로 원격 fetch
- **출처**:
  - 스킬 원본: https://github.com/vercel-labs/agent-skills (24.6k stars) — `skills/web-design-guidelines/`
  - 규칙 원본: https://github.com/vercel-labs/web-interface-guidelines (`command.md`)
- **라이선스**: 저장소 참조 (Vercel 공식)
- **통합 방식**: **복제하지 않음**. glen-design review 모드에 `--strict` 플래그 추가 — 실행 시 WebFetch로 최신 `command.md`를 가져와 100+ 규칙 적용
- **카테고리**: Accessibility, Typography, Layout, Interactivity, Performance
- **통합일**: 2026-04-08
- **이유**: 원격 fetch 방식이 원본 스킬 철학과 일치. 항상 최신 규칙 자동 반영, 로컬 유지보수 불필요.

### Taste Skill 개념 차용 검토 결과
- **원본**: https://github.com/Leonxlnx/taste-skill (Leonxlnx)
- **검토 결과**: **흡수하지 않음 — 이미 중복**
- **근거**: `glen-design/resources/taste-rules.md`에 이미 4개 다이얼 (Creativity/Density/Variance/Motion) 존재. 원본의 3축 (DESIGN_VARIANCE/MOTION_INTENSITY/VISUAL_DENSITY)과 개념 동일.
- **기록 이유**: 향후 같은 스킬을 재평가할 때 중복 작업 방지

---

## Libraries (`src/lib/`)

### contents-creator — URL/파일/폴더 → 한글 마크다운 파이프라인
- **위치**: `src/lib/contents-creator/`
- **출처**: 원래 별도 레포 `glen-contents-creator` (글렌 자작, 현재 폐기)
- **통합 방식**: 2026-03-30 외부 레포 → `src/lib/contents-creator/`로 완전 내부화
- **구성**: CLI, source-reader(6종), renderer, image-gen, pipeline, adapters 15개 파일
- **사용처**: `create-content`, `image` 스킬에서 `__CLAUDE_HOME__/lib/contents-creator/`로 참조
- **커밋**: `4e6c316`

---

## 글렌 자체 개발 스킬

다음 스킬들은 외부 통합 없이 글렌이 직접 작성한 자체 개발:
`begin`, `deploy`, `done`, `failures`, `glen-design` (코어), `harness-stats`, `image`, `init`, `nxt`, `refine`, `security-review`, `tdd-workflow`, `trend-scan`, `create-content` (래퍼)

단, `glen-design`의 **프리셋 데이터**와 `create-content`의 **라이브러리 코드**는 위에 기록된 외부 출처를 사용한다.

---

## 유지 관리 규칙

1. **새 외부 스킬/플러그인/라이브러리 통합 시** 반드시 이 파일에 항목 추가
2. **재싱크 스크립트가 있으면** 실행 방법 명시
3. **라이선스 표기**는 원본 파일 상단 주석 또는 LICENSE 파일로 병행
4. **커밋 해시**를 기록하여 언제 통합됐는지 추적
