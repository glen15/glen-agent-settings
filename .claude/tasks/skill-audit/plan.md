# 스킬셋 총 점검 — 계획

## 목표
glen-agent-settings의 스킬(12개), 에이전트(8개), 커맨드(9개), harness.md 정합성을 점검하고 수정한다.

## 범위
- frontmatter 완전성/일관성
- harness.md ↔ 실제 파일 정합성
- 스킬 간 중복/충돌 해소
- 누락된 정보 보완

## 우선순위별 작업

### P0 — 즉시 수정
- [ ] #1 harness.md "planner" 유령 참조 → "내장 Plan 모드 / architect"로 수정
- [ ] #2 harness.md `/tdd-workflow` → `/tdd`로 명칭 통일
- [ ] #3 `ui-ux-pro-max` frontmatter에 user_invocable, argument-hint 추가
- [ ] #4 `create-content` frontmatter에 user_invocable: true 추가

### P1 — harness.md 정합성
- [ ] #5 harness.md 스킬 테이블에 미등록 스킬 추가 (/image, /video, /done, /nxt, /notebooklm)
- [ ] #6 harness.md 스킬 테이블에 /test-coverage 추가
- [ ] #7 스킬 vs 커맨드 구분 명확화 (테이블 분리 또는 표기)

### P2 — 품질 개선
- [ ] #8 notebooklm에 Gotchas 섹션 추가
- [ ] #9 argument-hint 형식 통일
- [ ] #10 done ↔ nxt done 역할 구분 description에 명시

### P3 — 스킬 신규
- [ ] #11 작업 시작 시 4개 문서 생성 스킬 정의

## 제약
- 한 커밋 = 한 목적
- 정리(tidy)와 기능(feat)을 한 커밋에 섞지 않기
- 각 수정 후 harness.md와의 정합성 재확인
