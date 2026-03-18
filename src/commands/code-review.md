---
description: "코드 작성 또는 수정 완료 후 사용. git diff를 분석하여 보안 취약점, 누락된 테스트, 동작 리그레션을 검토. CRITICAL/HIGH 이슈 발견 시 머지 차단."
---

# Code Review

code-reviewer 에이전트를 호출하여 변경사항을 리뷰한다.

1. `git diff`로 변경사항 확인
2. 심각도별 이슈 분류 (CRITICAL → NITPICK)
3. CRITICAL/HIGH 없으면 승인, 있으면 차단
