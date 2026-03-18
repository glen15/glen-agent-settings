---
description: "코드 구조가 크게 변경된 후 사용. import/export 의존성 스캔 → 아키텍처 코드맵 업데이트. 30%+ 차이 시 사용자 확인 필요."
---

# Update Codemaps

doc-updater 에이전트를 호출하여 코드맵을 갱신한다.

1. 전체 소스에서 import/export/의존성 스캔
2. codemaps/ 디렉토리에 아키텍처 문서 생성/갱신
3. 이전 버전과 diff 비율 계산
4. 30%+ 변경 시 사용자 승인 요청
