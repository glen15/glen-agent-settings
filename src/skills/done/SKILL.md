---
name: done
description: "작업 완료 처리: 커밋 + nxtflow 태스크 자동 생성/완료. /done 또는 /done \"작업 설명\""
user_invocable: true
argument-hint: ["작업 설명"]
---

# Done — 작업 완료 파이프라인

작업이 끝나면 커밋과 nxtflow 처리를 한 번에 수행한다.

> **`/done` vs `/nxt done`**: `/done`은 **git 커밋 + nxtflow 태스크 자동 처리**를 한 번에 수행. `/nxt done`은 **커밋 없이 순수 GTD 태스크만 완료 처리**. 코드 작업 후에는 `/done`, 코드 외 태스크 완료는 `/nxt done`.

## 입력

- `__ARGS__`: 선택적 작업 설명. 비어있으면 diff에서 자동 추론.

## 실행 순서

### Step 1: 변경사항 확인

`git status`와 `git diff`로 변경사항을 확인한다.

- 변경사항이 **없으면**: "커밋할 변경사항이 없습니다." 출력 후 nxtflow 처리만 진행 (Step 3).
- 변경사항이 **있으면**: Step 2로 진행.

### Step 2: 커밋

1. 변경된 파일과 diff를 분석하여 커밋 메시지를 작성한다.
2. 커밋 메시지 규칙:
   - **반드시 한글**
   - 타입: `feat:` `fix:` `tidy:` `test:` `perf:` `docs:` `style:` `chore:` `refactor:`
   - `__ARGS__`가 있으면 참고하여 메시지 작성
   - Co-Authored-By 포함
3. 관련 파일만 `git add`하고 커밋한다.
   - `.env`, credentials 등 민감 파일은 제외
4. `git status`로 커밋 성공 확인.

### Step 3: nxtflow 처리 (현황 기반)

커밋 후 nxtflow 현황을 파악하고 적절한 액션을 수행한다.

#### 3-0. 프로젝트 ID 확인 (토큰 절약 핵심)

아래 매핑에서 현재 cwd에 맞는 projectId를 먼저 확인한다.
매핑에 없으면 `mcp__nxtflow__list_projects`로 cwd 매칭 후 여기에 추가할 것을 사용자에게 제안.

**cwd → projectId 매핑** (하드코딩으로 list_projects 호출 제거):
- `/Users/glen/Desktop/work/dxai` → `2127cff5-b87a-42c7-bf60-d76d636ff886`

#### 3-1. 기존 태스크 매칭 확인

1. `mcp__nxtflow__list_tasks`로 **projectId 필터링**하여 해당 프로젝트 태스크만 조회
   - 반드시 `projectId` 파라미터 사용 (전체 조회 금지 — 토큰 낭비)
   - `status: ["pending"]` 필터도 함께 사용
2. 이번 작업과 관련된 기존 태스크가 있는지 제목/설명으로 매칭

#### 3-2. 매칭 결과에 따른 분기

**기존 태스크가 있고, 이번 커밋으로 완료된 경우:**
```
mcp__nxtflow__update_task:
  id: <기존 태스크 ID>
  update: { "status": "completed" }
```

**기존 태스크가 있고, 진행 중인 경우:**
```
mcp__nxtflow__update_task:
  id: <기존 태스크 ID>
  update: { "description": "기존 설명 + \n진행: <커밋 요약> (<commit hash>)" }
```

**관련 태스크가 없는 경우 (새로 생성):**
```
mcp__nxtflow__create_task:
  subject: 커밋 메시지 요약
  description: 변경 내용 + 커밋 해시
  gtdStatus: "reference"
  projectId: <매칭된 프로젝트 ID>
  contexts: ["src:claude-code", "capture:implicit", "domain:code"]
  priority: fix→high, feat→medium, tidy/chore→low
```

### Step 4: 완료 보고

한 줄 요약: 커밋 해시 + nxtflow 액션 (생성/완료/업데이트)

## 주의사항

- 정리 커밋과 기능 커밋이 섞여있으면 **분리하여** 각각 처리
- 100줄+ 거대 변경은 분리 가능 여부를 사용자에게 확인
- `git push`는 하지 않는다 (사용자 명시 요청 시만)
- 태스크 완료 처리가 애매하면 사용자에게 확인

## Gotchas

> Claude가 /done에서 자주 실수하는 것. 실패할 때마다 한 줄 추가.

1. **projectId 매핑 없이 list_projects 호출** — 매핑 테이블을 먼저 확인. 전체 조회는 ~40K 토큰 낭비.
2. **민감 파일을 git add** — `.env`, `.env.local`, credentials 파일을 스테이징에 포함. 반드시 파일명 기반 add.
3. **커밋 메시지 영어로 작성** — 반드시 한글. 타입 프리픽스(`feat:`, `fix:` 등)만 영어.
4. **기존 태스크 무시하고 새로 생성** — 유사 태스크가 이미 있으면 업데이트가 맞다.
