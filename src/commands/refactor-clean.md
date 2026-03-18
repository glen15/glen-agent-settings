---
description: "죽은 코드 정리, 미사용 export/의존성 제거 시 사용. knip, depcheck, ts-prune으로 분석 후 안전한 삭제만 수행. 삭제 전후 테스트 필수."
---

# Refactor Clean

refactor-cleaner 에이전트를 호출하여 죽은 코드를 안전하게 제거한다.

1. 분석 도구 실행 (knip, depcheck, ts-prune)
2. 심각도 분류 (SAFE/CAUTION/DANGER)
3. SAFE 항목만 자동 삭제, CAUTION은 사용자 확인
4. 삭제 전후 테스트 실행 → 실패 시 롤백
