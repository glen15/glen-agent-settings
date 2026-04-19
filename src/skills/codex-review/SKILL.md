---
name: codex-review
description: OpenAI Codex CLI를 교차 리뷰어로 호출하고 결과를 한글로 후처리. 공식 codex-plugin-cc 위에 얹은 얇은 래퍼. Claude 자체 리뷰(`/claude-review`)와 짝을 이룸.
---

# Codex Review (한글 래퍼)

OpenAI 공식 `codex-plugin-cc`의 review 기능을 직접 호출하고, stdout을 한글로 후처리하여 보고한다.

## 전제

- **공식 플러그인 그대로 사용** — 포크/수정 금지. `${CLAUDE_PLUGIN_ROOT}` 경로의 companion 스크립트를 호출한다.
- **Generator-Evaluator 분리** — Codex가 리뷰어(evaluator), 내가 generator. 내 작업을 내가 자체 검토하는 편향을 피하기 위해 사용.
- **리뷰 온리** — 이슈를 받더라도 이 스킬 안에서 자동 수정하지 않음. 사용자에게 보고 후 STOP.

## 프로세스

### 1. Codex 준비 확인

Codex가 설치/로그인되어 있어야 한다. 미설정이면 `/codex:setup` 먼저 실행하도록 안내하고 중단.

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" setup --json
```

### 2. 리뷰 실행

기본은 foreground(`--wait`). 변경 규모가 크면 사용자에게 background 권유 후 실행.

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" review --wait
```

옵션:
- `--base <ref>` — 비교 대상 지정 (기본: auto)
- `--scope auto|working-tree|branch` — 리뷰 범위
- `--background` — 백그라운드 실행 (`/codex:status`로 확인, `/codex:result`로 수거)

### 3. stdout 한글 후처리

Codex는 영문 구조화 출력을 반환한다. 아래 규칙으로 한글화하여 사용자에게 보고.

**헤더 치환**:
- `# Codex Review` → `# Codex 리뷰`
- `# Codex Adversarial Review` → `# Codex 적대적 리뷰`
- `Target: <ref>` → `대상: <ref>`
- `Verdict: approve` → `판정: ✅ 승인`
- `Verdict: needs-attention` → `판정: ❌ 수정 필요`
- `Findings:` → `이슈:`
- `Recommendation:` → `권장:`
- `Next steps:` → `다음 단계:`
- `No material findings.` → `중대한 이슈 없음.`

**severity 대문자화** (단순 변환만):
- `[critical]` → `[CRITICAL]`
- `[high]` → `[HIGH]`
- `[medium]` → `[MEDIUM]`
- `[low]` → `[LOW]`

**본문 번역**: summary / body / recommendation / next_steps 각 항목의 영문 설명을 자연스러운 한글로 번역. 코드 식별자·파일 경로·라인 번호는 원문 유지.

### 4. 보고

한글 후처리한 결과를 그대로 출력. 추가 해설·요약·자화자찬 금지.

판정별 후속 행동 안내:
- ✅ 승인 → "Codex 교차 리뷰 통과. 머지 진행 가능."
- ❌ 수정 필요 → "CRITICAL/HIGH 이슈 확인 후 수정 요청 주시면 진행합니다."

## Gotchas

1. **자동 수정 시도** — 리뷰어는 findings만 보고. 내가 `/codex-review` 안에서 곧바로 코드를 고치지 않는다. 공식 플러그인의 `codex-result-handling` 스킬도 동일 원칙("리뷰 findings 제시 후 STOP").
2. **stdout을 영문 그대로 출력** — 후처리 없이 그대로 전달하지 않는다. `/codex:review`(공식)는 verbatim 반환이 원칙이지만, `/codex-review`(이 래퍼)는 한글 후처리가 존재 이유.
3. **severity 매핑 재설계** — critical→CRITICAL, high→HIGH, medium→MEDIUM, low→LOW. Claude `/claude-review`의 CRITICAL/HIGH/WARNING/NITPICK 체계와 의도적으로 다르게 둠(대소문자 구분만). 임의로 바꾸지 말 것.
4. **공식 커맨드 덮어쓰기** — `/codex:review`는 공식 플러그인 네임스페이스. 내 래퍼는 `/codex-review` 또는 skill 호출로만 사용. 공식 커맨드 수정 금지.
5. **base branch 누락** — `--scope branch`인데 `--base` 없으면 companion이 자동 추론. 명시적 비교가 필요하면 `--base origin/main` 등으로 전달.
6. **background 결과 수거 누락** — `--background`로 시작한 잡은 `/codex:status`·`/codex:result`로 확인. 잊고 넘어가면 리뷰 결과 없이 머지하는 사고 발생.

## 관련

- `/claude-review` — Claude Opus 자체 리뷰 (pair)
- `/codex:review` — 공식 영문 리뷰 (원본)
- `/codex:adversarial-review` — 확신 깨뜨리기 프레이밍 버전
- `/codex:setup` — Codex 설치/로그인 확인
