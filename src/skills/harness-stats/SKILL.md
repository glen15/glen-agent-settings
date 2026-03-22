---
name: harness-stats
description: "하네스 도구 사용 통계 조회. /harness-stats [명령] — 스킬, 훅, MCP, CLI 사용 패턴을 SQLite 기반으로 분석. 도구 사용 빈도, 미사용 도구, 실패율, 프로젝트별 통계 제공."
user_invocable: true
argument-hint: [today|week|month|top|unused|skills|project|trend|fails|cleanup|raw]
---

# Harness Stats — 도구 사용 통계

하네스 도구(스킬, 훅, MCP, CLI, 에이전트)의 사용 패턴을 SQLite로 추적·분석한다.

## 프로젝트 경로

```
HARNESS_STATS_DIR="${HOME}/.claude/skills/harness-stats"
```

## 실행

```bash
bash "${HARNESS_STATS_DIR}/scripts/query.sh" __ARGS__
```

`__ARGS__`를 사용자 인자로 치환. 결과는 JSON 배열로 반환.

## 명령어

| 명령 | 설명 |
|------|------|
| `today` | 오늘 카테고리별 호출 수 (기본값) |
| `week` | 최근 7일 도구별 호출 수 |
| `month` | 최근 30일 도구별 호출 수 |
| `top` | 최근 7일 Top 15 도구 |
| `unused` | 30일 이상 미사용 도구 |
| `skills` | 스킬별 호출 빈도·최초/최근 사용일 |
| `project` | 현재 프로젝트 통계 |
| `trend` | 최근 14일 일별 추세 |
| `fails` | 최근 7일 실패 Top 10 |
| `cleanup [일수]` | N일 이전 데이터 삭제 (기본 90일) |
| `raw "SQL"` | 직접 SQL 쿼리 |

## 예시

```
/harness-stats
/harness-stats top
/harness-stats skills
/harness-stats trend
/harness-stats unused
/harness-stats cleanup 60
/harness-stats raw "SELECT COUNT(*) FROM tool_usage"
```

## DB 위치

```
~/.claude/harness-usage.db
```

PostToolUse + UserPromptSubmit 훅이 자동으로 모든 도구 호출을 기록한다.
DB가 없으면 첫 호출 시 자동 생성된다.

## 카테고리 분류

| 카테고리 | 대상 |
|----------|------|
| `skill` | `/스킬명` 호출 |
| `skill_script` | 스킬 내 스크립트 실행 |
| `cli` | git, gh, gws 등 CLI 명령 |
| `file_write` | Write 도구 |
| `file_edit` | Edit 도구 |
| `file_read` | Read 도구 |
| `search` | Glob, Grep 도구 |
| `mcp` | MCP 서버 호출 |
| `agent` | 서브에이전트 위임 |

## Gotchas

1. **DB 파일 크기** — 일 500건 기준 1년 ~10MB. `cleanup` 명령으로 주기적 정리.
2. **sqlite3 미설치** — macOS 기본 탑재. Linux에서 `apt install sqlite3` 필요할 수 있음.
3. **동시 쓰기** — WAL 모드로 동시 읽기/쓰기 허용. 충돌 없음.
