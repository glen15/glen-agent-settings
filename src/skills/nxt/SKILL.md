---
name: nxt
description: "nxtflow GTD 태스크/프로젝트 관리. /nxt [명령] — tasks, done, delegate, project, plan, review"
user_invocable: true
argument-hint: <명령> [인자...]
---

# Nxt — nxtflow GTD 관리 스킬

nxtflow MCP를 통해 태스크, 프로젝트, 데일리플랜을 관리한다.

## 명령어

| 명령 | 설명 | 예시 |
|------|------|------|
| `tasks` | 현재 태스크 조회 (필터 가능) | `/nxt tasks`, `/nxt tasks next_action` |
| `done <검색어>` | 태스크 완료 처리 | `/nxt done Apple Developer` |
| `add <제목>` | 새 태스크 생성 | `/nxt add 웹 배포 자동화` |
| `delegate <검색어> to <대상>` | 태스크 위임 (waiting_for) | `/nxt delegate 인프라 to 엘라` |
| `project [명령]` | 프로젝트 관리 | `/nxt project`, `/nxt project create 새프로젝트` |
| `plan` | 오늘의 데일리플랜 조회/설정 | `/nxt plan`, `/nxt plan set` |
| `review` | GTD 위클리 리뷰 | `/nxt review` |
| (인자 없음) | 전체 현황 요약 | `/nxt` |

## 실행 로직

### 인자 없음 — 전체 현황

1. `mcp__nxtflow__list_tasks` (status: ["pending"])로 전체 태스크 조회
2. GTD 상태별 카운트 요약:
   - inbox: 처리 안 된 것 (정리 필요)
   - next_action: 실행 대기
   - waiting_for: 위임 중
   - someday: 나중에
   - reference: 참조용
3. 현재 프로젝트(cwd)와 연결된 태스크가 있으면 우선 표시
4. inbox가 있으면 "정리 필요한 태스크가 N개 있습니다" 알림

### `tasks [필터]` — 태스크 조회

- 필터 없으면: `next_action` + `inbox` 태스크 표시
- 필터 있으면: 해당 gtdStatus로 조회 (next_action, waiting_for, someday, reference, inbox)
- 현재 프로젝트(cwd 기반) 태스크만 보려면: `/nxt tasks here`

### `done <검색어>` — 태스크 완료

1. `mcp__nxtflow__list_tasks`에서 검색어와 매칭되는 태스크 찾기
2. 여러 개 매칭되면 사용자에게 선택 요청
3. `mcp__nxtflow__update_task`로 status를 `done`으로 변경:
   ```
   id: <태스크 ID>
   update: { "status": "completed" }
   ```
4. 완료된 태스크 제목 출력

### `add <제목>` — 태스크 생성

1. 먼저 `mcp__nxtflow__list_tasks`로 유사 제목 중복 확인
2. 중복 없으면 `mcp__nxtflow__create_task` 호출:
   - subject: 입력된 제목
   - gtdStatus: "next_action" (기본)
   - contexts: ["src:claude-code", "capture:explicit", "domain:code"]
   - projectId: 현재 cwd에 매칭되는 프로젝트가 있으면 자동 연결
3. 중복 있으면 사용자에게 확인

### `delegate <검색어> to <대상>` — 위임

1. 태스크 검색
2. `mcp__nxtflow__list_entities`에서 대상 entity 찾기
   - 없으면 `mcp__nxtflow__create_entity`로 생성
3. `mcp__nxtflow__update_task`로 업데이트:
   ```
   id: <태스크 ID>
   update: {
     "gtd_status": "waiting_for",
     "waiting_for_entity": "<entity name>"
   }
   ```

### `project` — 프로젝트 관리

- `/nxt project`: 활성 프로젝트 목록
- `/nxt project create <이름>`: 새 프로젝트 생성 (현재 cwd 자동 연결)
- `/nxt project done <검색어>`: 프로젝트 완료 처리
- `/nxt project link <검색어>`: 현재 프로젝트에 태스크 연결

### `plan` — 데일리플랜

- `/nxt plan`: 오늘의 데일리플랜 조회 (`mcp__nxtflow__get_daily_plan`)
- `/nxt plan set`: next_action 태스크 중 우선순위 높은 3개를 Top Priorities로 설정

### `review` — 위클리 리뷰

GTD 위클리 리뷰 체크리스트:
1. **inbox 정리**: 미정리 태스크를 next_action/someday/waiting_for/reference로 분류
2. **waiting_for 점검**: 위임 태스크 진행 상황 확인 → 완료된 것은 done 처리
3. **someday 재검토**: 지금 할 수 있는 것은 next_action으로 전환
4. **완료 태스크 정리**: 지난 주 완료된 항목 확인
5. 각 단계마다 사용자에게 판단을 물어보고 진행

## 프로젝트 자동 매칭 (토큰 절약)

**cwd → projectId 매핑** (list_projects 호출 없이 즉시 매칭):
- `/Users/glen/Desktop/work/dxai` → `2127cff5-b87a-42c7-bf60-d76d636ff886`

매핑에 없는 cwd면 `mcp__nxtflow__list_projects`로 1회 조회 후 매핑 추가를 제안.
태스크 조회 시 **반드시 projectId 필터 사용** — 전체 조회(148개+)는 ~40K 토큰 낭비.

## 주의사항

- 삭제(`delete_task`, `delete_project`)는 반드시 사용자 확인 후 실행
- 대량 변경(10개 이상 태스크 일괄 처리)은 미리 목록 보여주고 확인
- 태스크 업데이트 시 기존 데이터를 덮어쓰지 않도록 필요한 필드만 전달
