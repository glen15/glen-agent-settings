---
description: "실행 중인 앱을 Sprint Contract 기준으로 라이브 평가. 코드 작성 완료 후, /refine Verify 단계에서 사용. Generator-Evaluator 분리 원칙 적용."
---

# Evaluate

실행 중인 앱을 Sprint Contract 기준으로 평가한다. evaluator 에이전트를 활성화한다.

## 프로세스

1. `.claude/tasks/*/contract.md` 확인 — 없으면 작성 요청
2. 앱 실행 상태 확인 — 미실행 시 시작
3. browser-use + curl로 라이브 평가
4. 기준별 PASS/FAIL/PARTIAL 판정
5. evaluation.md에 보고서 작성

## 다음 단계

- APPROVE → `/done`으로 완료
- REVISE → Generator가 수정 후 재평가
- REJECT → `/plan`으로 전략 재수립
