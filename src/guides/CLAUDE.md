# Global Claude Code Guidelines

Glen의 개인 코딩 원칙. 모든 프로젝트에 적용.
상세 프로필: memory/profile.md 참조

## 핵심 워크플로우

1. **Tidy First** → 정리를 먼저, 그 다음 기능. 정리와 기능을 절대 한 커밋에 섞지 말 것.
2. **Make it Work → Right → Fast** → 이 순서를 절대 건너뛰지 않음. 동작 전 최적화 금지.
3. **Boy Scout Rule** → 파일을 열었다면 최소 한 가지는 개선.

## 반복 수렴 도구

두 가지 도구가 있으며 용도가 다르다.

### Refine (세션 내 수렴)

CC 세션 내부에서 Stop Hook으로 반복 수렴. 상세: `/refine` 스킬 참조.

- `MAX_ITER=5`, `STAGNATION_LIMIT=3`
- 각 iteration: Plan → Execute → Verify → Record(커밋)
- 정체 감지 시 반드시 사용자에게 물어보고 전략 변경
- 커밋: `refine(N/MAX): 한글 설명`
- 완료 조건: 테스트 통과 + 빌드 성공 + 요구사항 충족 + 코드 정리 + 보안 체크

### Ralph Loop (밤샘 무인 오케스트레이터)

bash에서 `claude -p`를 반복 호출하는 무인 자율 코딩. `ralph-loop --project-dir /path`

- 매 반복 fresh context + 파일시스템 상태 인수인계
- 2-에이전트 아키텍처: init(환경 분석) → coding(기능 구현 루프)
- prd.json/progress.txt/git으로 상태 관리
- exponential backoff (rate limit), stagnation 감지, gate 검증

## 커밋 규칙

- **반드시 한글**로 작성
- 타입: `refine:` `ralph:` `tidy:` `feat:` `fix:` `test:` `perf:` `docs:` `style:` `chore:`
- 한 커밋 = 한 목적. 100줄+ 거대 커밋 금지
- 정리 커밋과 기능 커밋을 분리

## 코드 원칙

- 함수 20줄 이하, 한 가지 일만 수행
- Guard clauses로 중첩 최소화 (최대 3단계)
- Immutability 필수: 객체/배열 직접 수정 금지, 스프레드 연산자 사용
- 파일 크기: 권장 200-400줄, 최대 800줄
- 의미있는 변수/함수명 (동사+명사)
- 죽은 코드, 주석 처리된 코드 제거
- Input validation: Zod 등 스키마 라이브러리 권장

## 테스트

- 커버리지 목표 80%+
- 기능 추가 시 테스트 필수 (TDD 권장)
- 버그 수정 시 재현 테스트 먼저

## 보안 (커밋 전 필수)

- 하드코딩된 시크릿 금지 → 환경변수 사용
- 사용자 입력 검증
- 에러 메시지에 민감 정보 노출 금지
- .env → .gitignore 포함

## 하네스 엔지니어링

에이전트/스킬/MCP/Hook 선택 전략: `skills/harness.md` 참조.
- **Skill-First**: Skill로 해결 가능하면 MCP 호출 금지. MCP는 외부 실시간 데이터만.
- **UI 파이프라인**: Skill(디자인 결정 + 컴포넌트 선택) → MCP(소스코드만) → Skill(검증)
- **에이전트 조합**: planner → tdd-guide → code-reviewer → security-reviewer
- **CLI 우선**: gws > MCP Gmail/Calendar, gh CLI > GitHub MCP

## 도구 우선순위

- **gws CLI를 기본 사용** (MCP Gmail/Calendar 등보다 우선)
- 사용법: `gws <service> <resource> <method> --params '{...}'`
- 계정: glen.lee@nxtcloud.kr

## API-First + AI-First (B2A 방향성)

**핵심 전제: AI Agent가 새 시대의 플랫폼이다.** 상세: `skills/harness.md`
- 서비스의 1차 고객은 AI Agent (B2A: Business to Agent)
- 신규 기능은 **API 계약부터** 설계 — UI는 API 위의 한 클라이언트
- 앱 기능은 **MCP/CLI에서도 동일하게** 제공
- 응답은 **구조화된 데이터**(JSON 등)로 반환

## 예외

프로토타입/핫픽스/레거시는 원칙 유연 적용. 단, 반드시 후속 정리 커밋.
