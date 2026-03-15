# glen-agent-settings

Claude Code + Codex CLI 설정을 **단일 소스**에서 관리하고, 빌드 스크립트로 양쪽에 배포하는 프로젝트.

## 왜 필요한가

- 스킬 8개, 훅 10개, Ralph Loop, 가이드 문서가 `~/.claude/` 곳곳에 흩어져 있었음
- Codex CLI도 같은 스킬을 쓰고 싶지만 파일 형식이 다름 (`SKILL.md` vs `AGENTS.md`, `settings.json` vs `config.toml`)
- 하나를 고치면 다른 쪽도 수동으로 맞춰야 하는 문제

이 프로젝트는 `src/`에 원본을 두고, `build.sh`가 플랫폼별 변환을 수행하며, `deploy.sh`가 각각의 홈 디렉토리에 배포한다.

## 빠른 시작

```bash
# 빌드 (src/ → dist/claude/, dist/codex/)
bash scripts/build.sh

# 배포 (양쪽)
./deploy.sh

# Claude만 배포
./deploy.sh --claude

# Codex만 배포
./deploy.sh --codex

# 미리보기 (실제 변경 없음)
./deploy.sh --dry-run
```

## 프로젝트 구조

```
glen-agent-settings/
├── src/                    # 원본 소스 (Single Source of Truth)
│   ├── skills/             # 스킬 8개
│   │   ├── create-content/
│   │   ├── done/
│   │   ├── notebooklm/
│   │   ├── nxt/
│   │   ├── refine/
│   │   ├── security-review/
│   │   ├── tdd-workflow/
│   │   └── ui-ux-pro-max/
│   ├── hooks/              # 훅 10개
│   │   ├── root/           # 전역 훅 (stop, commit-check 등)
│   │   └── refine/         # Refine Loop 전용 훅
│   ├── ralph-loop/         # 밤샘 무인 코딩 오케스트레이터
│   │   ├── adapters/       # claude.sh, codex.sh
│   │   ├── lib/            # backoff, stagnation, gate, jsonl
│   │   ├── prompts/        # init.md, coding.md
│   │   └── templates/      # prd.json, progress.txt
│   ├── guides/             # CLAUDE.md, harness.md
│   └── settings.json       # Claude Code 설정
├── overlays/               # 플랫폼별 오버라이드 (확장용)
│   ├── claude/
│   └── codex/
├── scripts/
│   └── build.sh            # 빌드: src/ → dist/
├── tests/
│   └── test-build.sh       # 검증 테스트 (57개)
├── deploy.sh               # 배포: dist/ → ~/.claude/, ~/.codex/
└── dist/                   # 빌드 산출물 (gitignore)
    ├── claude/             # → ~/.claude/
    └── codex/              # → ~/.codex/
```

## 빌드가 하는 일

| 단계 | Claude Code | Codex CLI |
|------|-------------|-----------|
| 스킬 | `SKILL.md` 그대로 복사 | `SKILL.md` → `AGENTS.md` (frontmatter 제거) |
| 훅 | root + refine 훅 복사 | 없음 (Codex는 Starlark Rules 사용) |
| Ralph Loop | 어댑터 포함 전체 복사 | 동일 |
| 가이드 | `CLAUDE.md` + `harness.md` | `CLAUDE.md` → `AGENTS.md` |
| 설정 | `settings.json` | `config.toml` 생성 |

## 배포가 하는 일

1. **백업** — `~/.claude/backups/<timestamp>/`에 기존 파일 자동 백업
2. **스킬/훅/Ralph Loop** — `dist/` → 대상 디렉토리에 복사
3. **settings.json 병합** — 기존 설정을 보존하면서 `jq -s '.[0] * .[1]'`로 deep merge
4. **심볼릭 링크** — `~/bin/ralph-loop` → `~/.claude/ralph-loop/ralph-loop.sh`

## 포함된 스킬

| 스킬 | 설명 |
|------|------|
| `create-content` | URL/파일/GitHub 소스에서 구조화된 한글 콘텐츠 생성 |
| `done` | 작업 완료 처리: 커밋 + nxtflow 태스크 자동 관리 |
| `notebooklm` | Google NotebookLM 전체 API (팟캐스트, 노트북 생성) |
| `nxt` | nxtflow GTD 태스크/프로젝트 관리 |
| `refine` | Refine Loop — 세션 내 반복 수렴 (Stop Hook 기반) |
| `security-review` | 보안 체크리스트 기반 코드 리뷰 |
| `tdd-workflow` | TDD 우선 개발 (80%+ 커버리지) |
| `ui-ux-pro-max` | UI/UX 디자인 인텔리전스 (67 스타일, 96 팔레트, 13 스택) |

## Ralph Loop

밤샘 무인 자율 코딩 오케스트레이터. 매 반복마다 fresh context로 에이전트를 실행하고, 파일시스템으로 상태를 인수인계한다.

```bash
# Claude Code로 실행
ralph-loop --project-dir /path/to/project

# Codex CLI로 실행
ralph-loop --project-dir /path/to/project --adapter codex

# 이전 세션 재개
ralph-loop --resume /path/to/.ralph-logs/<session>
```

주요 기능:
- **어댑터 패턴** — Claude/Codex 엔진 교체 (`--adapter`)
- **JSONL 구조화 로깅** — 토큰 사용량, 이벤트 타임라인
- **Exponential Backoff** — Rate limit 자동 감지 및 대기
- **순환 에러 감지** — 정체 시 루프 자동 중단
- **세션 재개** — `--resume`으로 중단 지점부터 이어서 실행

## 테스트

```bash
bash tests/test-build.sh
```

57개 테스트 항목: 스킬 존재, SKILL.md/AGENTS.md 생성, frontmatter 제거, 훅 배포, Ralph Loop 실행 권한 등.

## 설정 수정 워크플로우

```
1. src/에서 원본 수정
2. bash scripts/build.sh     # 빌드
3. bash tests/test-build.sh  # 검증
4. ./deploy.sh               # 배포
5. git commit & push         # 버전 관리
```

## 향후 계획

- `overlays/` 활용: 플랫폼별 스킬 커스텀 (예: Codex 전용 프롬프트 튜닝)
- `united_skills` 프로젝트와 통합 (팀 템플릿 시스템)
- CI/CD: push 시 자동 빌드 + 테스트
