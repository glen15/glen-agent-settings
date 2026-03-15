# 코드맵 업데이트

코드베이스 구조 분석 및 아키텍처 문서 업데이트:

1. 모든 소스 파일에서 import, export, 의존성 스캔
2. 다음 형식으로 토큰 효율적인 코드맵 생성:
   - codemaps/architecture.md - 전체 아키텍처
   - codemaps/backend.md - 백엔드 구조
   - codemaps/frontend.md - 프론트엔드 구조
   - codemaps/data.md - 데이터 모델 및 스키마

3. 이전 버전과의 차이 비율 계산
4. 변경사항이 30% 초과 시 업데이트 전 사용자 승인 요청
5. 각 코드맵에 최신성 타임스탬프 추가
6. 보고서를 .reports/codemap-diff.txt에 저장

분석에는 TypeScript/Node.js 사용. 구현 세부사항이 아닌 상위 수준 구조에 집중.
