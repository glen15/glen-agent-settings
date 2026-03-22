# 스킬셋 총 점검 — 컨텍스트

## 프로젝트 구조
```
src/
  skills/     12개 스킬 (SKILL.md)
  agents/     8개 에이전트 (.md)
  commands/   9개 커맨드 (.md)
  guides/     harness.md, CLAUDE.md
```

## 핵심 결정 사항
- 스킬: SKILL.md + user_invocable로 사용자 직접 호출 가능
- 커맨드: commands/*.md로 에이전트를 호출하는 래퍼
- 에이전트: agents/*.md로 특정 역할의 서브에이전트 정의
- harness.md: 위 3가지의 선택 매트릭스 + 조합 패턴 정의

## 참조
- 분석 결과: 3개 탐색 에이전트가 병렬 수행 (스킬 점검, 에이전트·커맨드 점검, harness 정합성)
- browser-use CLI 하네스 통합 커밋: e24db62

## 발견한 패턴
- frontmatter 완전한 스킬: done, nxt, init, image, video, deploy (6개)
- frontmatter 불완전한 스킬: ui-ux-pro-max, create-content, notebooklm, security-review, tdd-workflow, refine (6개)
- 불완전한 6개 중 security-review, tdd-workflow는 참고용 스킬이라 user_invocable 불필요할 수 있음
