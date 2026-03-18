---
name: init
description: "새 프로젝트 디렉토리에서 Claude Code 환경 자동 설정. /init — CLAUDE.md, memory, nxtflow 프로젝트 연결, 초기 계획 생성을 한 번에 처리. 새 프로젝트 시작, 환경 설정, 부트스트랩 시 사용."
user_invocable: true
argument-hint: ["프로젝트 설명 (선택)"]
---

# Init — 프로젝트 부트스트랩

새 프로젝트 디렉토리에서 Claude Code 작업 환경을 한 번에 설정한다.
반복적인 "계획 세워줘", "메모리 설정해줘", "프로젝트 연결해줘"를 자동화.

## 실행 순서

### Step 1: 프로젝트 분석

현재 디렉토리의 상태를 파악한다:

1. `git status` — git 초기화 여부
2. `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod` 등 — 스택 감지
3. 기존 `CLAUDE.md`, `.claude/` 여부 — 이미 설정되어 있는지 확인
4. `__ARGS__` — 사용자가 프로젝트 설명을 제공했는지

**이미 설정되어 있으면** 사용자에게 "이미 초기화된 프로젝트입니다. 재설정할까요?" 확인.

### Step 2: CLAUDE.md 생성

프로젝트 루트에 `CLAUDE.md`를 생성한다. 글로벌 CLAUDE.md(`~/.claude/CLAUDE.md`)는 이미 로드되므로, 프로젝트 CLAUDE.md에는 **프로젝트 고유 정보만** 넣는다.

```markdown
# [프로젝트명]

## 프로젝트 개요
[Step 1에서 감지한 스택 + 사용자 설명]

## 스택
- 런타임: [감지된 런타임]
- 프레임워크: [감지된 프레임워크]
- 테스트: [감지된 테스트 도구]
- 패키지 매니저: [npm/pnpm/yarn/pip/cargo]

## 프로젝트 컨벤션
[빈 상태 — 작업하면서 채워나감]

## 빌드 & 실행
- 설치: `[감지된 install 명령]`
- 개발: `[감지된 dev 명령]`
- 테스트: `[감지된 test 명령]`
- 빌드: `[감지된 build 명령]`
```

### Step 3: 메모리 디렉토리 설정

프로젝트별 메모리를 설정한다:

```bash
# 프로젝트별 메모리 경로 확인
# ~/.claude/projects/<프로젝트-경로-해시>/memory/
```

1. `MEMORY.md` 생성 (인덱스)
2. 프로젝트 컨텍스트를 `project_overview.md`로 저장:

```markdown
---
name: 프로젝트 개요
description: [프로젝트명] — [한줄 설명]
type: project
---

[프로젝트 설명, 스택, 목표]
```

### Step 4: nxtflow 프로젝트 연결

1. `mcp__nxtflow__list_projects`로 현재 cwd와 매칭되는 프로젝트 확인
2. **매칭 있으면**: projectId를 `/done`, `/nxt` 스킬의 매핑 테이블에 추가 제안
3. **매칭 없으면**: 사용자에게 새 프로젝트 생성 여부 확인
   ```
   mcp__nxtflow__create_project:
     name: [프로젝트명]
     description: [설명]
   ```

### Step 5: 초기 계획 (선택)

사용자에게 "초기 작업 계획을 세울까요?" 확인.

- **YES**: `/plan` 스킬 호출하여 구현 계획 생성
- **NO**: "필요할 때 `/plan`을 사용하세요." 안내

### Step 6: 완료 보고

설정 완료 요약:

```
프로젝트 초기화 완료:
- CLAUDE.md: ✓ (프로젝트 루트)
- Memory: ✓ (project_overview.md)
- nxtflow: ✓ (projectId: xxx)
- 빌드 명령: npm ci → npm test → npm run build
```

## Gotchas

> Claude가 프로젝트 초기화에서 자주 실수하는 것. 실패할 때마다 한 줄 추가.

1. **글로벌 CLAUDE.md 내용을 프로젝트에 복사** — 글로벌은 이미 로드됨. 프로젝트 CLAUDE.md에는 프로젝트 고유 정보만.
2. **빌드 명령 추측** — package.json의 scripts를 실제로 읽어서 확인. `npm run dev`가 없는 프로젝트도 있다.
3. **git init 없이 진행** — git 저장소가 아니면 먼저 `git init` 제안.
4. **nxtflow 프로젝트 중복 생성** — 비슷한 이름의 기존 프로젝트가 있는지 검색 먼저.
5. **메모리 경로 오류** — 프로젝트별 메모리는 `~/.claude/projects/` 하위 해시 경로. 프로젝트 루트에 memory/ 만들지 않기.
