# Claude Code 기반 장시간 무인 코딩 루프 운영 설계안

앞선 답변은 계획만 제시되어 있었고, 아래는 요청하신 “밤새 무인으로 안정 실행”을 목표로 한 운영 가능한 설계안이다.

핵심 결론(7줄 이내):
1) 밤샘 무인 루프 실패의 대부분은 **모델 성능 부족이 아니라 운영 시스템의 “비결정성(환경/테스트/리소스)”과 “제한(usage/rate/timeouts)”을 설계로 흡수하지 못해서** 발생한다. citeturn5search0turn0search0turn3search8turn3search5turn2search18  
2) 안정성은 “큰 작업을 잘하는 에이전트”가 아니라 **작은 작업을 확실히 끝내는 루프(작은 배치 + 빠른 피드백 + 롤백)**에서 나온다. citeturn5search5turn0search9turn5search0  
3) 무인 운영의 핵심 안전장치는 **보호 브랜치 + 필수 상태체크 + 최소권한 토큰 + 위험 작업 승인지점(Policy Gate)** 이다. citeturn1search0turn4search3turn1search12  
4) usage limit은 “우회”가 아니라 **세션을 짧게, 검증을 자주, 산출을 작게** 설계해 “한도에 걸리지 않는 작업량 프로파일”을 만드는 문제다. citeturn6search9turn0search22turn0search0  
5) 컨텍스트 한계는 1회 대화에 다 넣는 방식이 아니라 **상태를 파일로 외부화(작업큐/결정로그/요약팩)** 하고, 대화는 그 상태를 소비하는 방식으로 해결한다. citeturn0search1turn0search27  
6) 대규모 생성에서 테스트 비중이 커지는 이유는 **변경 표면적(interfaces) + 회귀 방지 비용 + 격리/픽스처/헬퍼 코드**가 기능 코드보다 더 빨리 누적되기 때문이다(추정). citeturn0search6turn2search4turn2search0turn2search18  
7) 가장 재현 가능한 현실 패턴은 **“PR/브랜치 기반의 단계적 커밋 + CI 게이트 + 자동 중단/재시도 + 아침에 요약 리포트”**이며, “자동 머지”는 범위를 강하게 제한할 때만 가능하다. citeturn1search0turn1search4turn5search0  

## 실패 원인 분석

**왜 중요한가**  
밤샘 무인 루프는 “사람이 즉시 개입해 작은 이상을 즉시 바로잡는” 안전망이 사라진 상태다. 따라서 실패 원인은 대개 (a) **제한에 의한 강제 중단**(usage/rate/timeouts), (b) **비결정성**(플래키 테스트/환경 드리프트), (c) **상태 관리 실패**(컨텍스트 드리프트/작업 큐 꼬임), (d) **변경 관리 실패**(충돌/대규모 diff/롤백 불가)로 구조화된다. citeturn3search8turn3search5turn2search18turn5search0turn0search1  
또한 외부 서비스 자체의 장애도 현실 변수다. 예를 들어 entity["company","Anthropic","ai research company"]의 공식 상태 페이지는 2026-03-11에 Claude.ai(Claude Code 로그인 포함)에서 오류가 상승했고 API는 영향이 없었다고 기록한다. “밤샘 무인”은 이런 외부 요인까지 흡수해야 한다. citeturn6search0  

**어떻게 설계하는가**  
실패 원인을 “증상”이 아니라 “구조/메커니즘” 단위로 분해하고, 각 메커니즘에 대응하는 예방 설계를 붙이는 방식이 가장 재현성이 높다.

- **제한 기반 중단(usage/rate/세션 길이/CI 시간 제한)**  
  - Claude API는 조직 단위 **rate limit**과 **spend limit**이 존재하며(서버가 용량 관리를 위해 제한을 둠), 이를 넘기면 요청이 실패한다. citeturn0search0  
  - Claude는 “usage limits(기간 내 사용량)”과 “length limits(대화 길이/복잡도)”를 구분해서 설명한다. 무인 루프는 이 두 축 모두에서 한계에 닿기 쉽다. citeturn6search9turn0search22  
  - CI 자체에서도 제한이 있다. 예컨대 GitHub-hosted runner의 job 실행 시간은 6시간이며, self-hosted는 5일까지 가능하다고 명시돼 있다. 즉 “밤샘=한 job에서 8시간”은 구조적으로 깨질 수 있다. citeturn3search8  
  - GitLab은 기본 job timeout이 60분이고, 60분 동안 로그 출력이 없으면 종료될 수 있다고 문서에 적는다(무인 루프에서 “조용한 빌드”가 치명적). citeturn3search5turn3search17  
  - CircleCI는 “10분 no-output timeout” 같은 플랫폼 제약이 존재한다. citeturn3search34  

- **비결정성(테스트/빌드/환경)**  
  - 큰(large) 테스트는 플래키할 확률이 유의미하게 높다는 측정 결과가 있다(구글 내부 데이터로 small 0.5%, medium 1.6%, large 14%). 무인 루프에서 플래키는 “가짜 실패→재시도 폭발→한도/시간 초과”로 바로 연결된다. citeturn2search18  
  - 비결정적 테스트를 격리(quarantine)하거나 메인 파이프라인에서 분리하지 않으면 CI 가치가 급격히 떨어진다는 경험칙도 정리돼 있다. citeturn0search25  
  - 재현 가능한 빌드를 위해서는 파일 순서/시간/환경 차이 같은 통제하기 어려운 요인을 제거해야 한다(결정적 빌드 시스템). citeturn4search1turn4search9  

- **상태/컨텍스트 관리 실패(길 잃음)**  
  - Claude 문서에는 컨텍스트 윈도우와 토큰 예산이 명시되고, tool call 이후 남은 용량이 갱신되는 형태가 소개된다. 장시간 루프에서는 “대화 1개”가 결국 포화된다. citeturn0search1turn0search27  
  - 컨텍스트 포화는 “요구사항/결정/금지사항”이 대화에서 누락되는 형태로 나타나며, 그 순간부터 위험한 명령/잘못된 리팩터링/불필요한 대규모 변경이 증가한다(추정: 운영 관찰 기반). citeturn0search1  

- **변경 관리 실패(대규모 diff/충돌/롤백 불가)**  
  - entity["company","Google","technology company"] SRE는 “라이브 시스템의 장애 중 대략 70%가 변경에서 기인”한다고 밝히며, 완화책으로 **점진 롤아웃, 빠른 탐지, 안전한 롤백**을 제시한다. 무인 코딩 루프도 “변경 관리 시스템”으로 봐야 한다. citeturn5search0  

**흔한 안 좋은 예**  
- “한 번에 크게 만들고, 마지막에 전체 테스트 돌려서 통과하면 끝” 구조(대개 새벽에 플래키/리소스/한도 문제로 붕괴). citeturn2search18turn3search8  
- CI에서 6시간 제한인데도 단일 job에 “8시간짜리 에이전트 루프”를 그대로 태우는 구성. citeturn3search8  
- 컨텍스트가 길어질수록 규칙을 잊는데도, 상태를 파일로 외부화하지 않고 “대화만 계속 이어감”. citeturn0search1  
- 플래키 테스트를 “재시도 3번”으로 땜질하고 루프를 계속 돌림(결국 재시도 폭발). citeturn2search18turn0search25  

**더 나은 대안**  
- “작은 배치(작은 변경) → 즉시 검증 → 체크포인트 커밋 → 다음 작업”을 강제하고, 대화는 짧게 쪼개며 상태는 로그/큐로 외부화한다. citeturn5search5turn0search9turn0search1  
- CI 제약(시간/무출력 종료/동시성)을 고려해 “job 체이닝” 또는 self-hosted runner로 분리한다(제약을 인정하고 구조를 맞춘다). citeturn3search8turn3search5  
- 플래키 방지: 큰 테스트를 줄이고 작은/중간 테스트 중심으로 빠른 피드백을 구성한다. citeturn2search0turn2search18turn0search6  

## 안정적인 밤샘 실행 아키텍처

**왜 중요한가**  
무인 루프는 “에이전트 1개를 오래 실행”하는 문제가 아니라, **작업 큐/상태/검증/롤백/한도/관측(Observability)** 이 결합된 운영 시스템 문제다. 특히 SRE 관점에서 변경은 사고의 주요 원인이므로, 자동화된 변경 관리(점진 적용+탐지+롤백)가 중심이 되어야 한다. citeturn5search0turn4search6  

**어떻게 설계하는가**  
아래는 로컬/CI 어디서든 구현 가능한 “컨트롤 플레인 + 실행 워커” 모델이다(도구는 Claude Code든 다른 에이전트든 교체 가능).

image_group{"layout":"carousel","aspect_ratio":"16:9","query":["CI pipeline diagram gated stages","task queue worker architecture diagram","pull request workflow required status checks diagram","structured logging jsonl example"] ,"num_per_query":1}

### 운영 아키텍처(권장)

1) **Loop Controller(오케스트레이터)**  
- 역할: 작업 큐에서 1개 작업을 “대여(lease)”하고, 워커에게 실행을 위임한 뒤 결과를 판정해 다음 상태로 전이한다.  
- 핵심: Controller는 **유한상태머신(FSM)** 으로 설계한다. 예: `READY → PLAN → IMPLEMENT → VERIFY → INTEGRATE → PROMOTE → DONE/FAILED`.  
- “무인 안정성”은 FSM의 **중간 상태가 디스크에 강제 기록**되어 프로세스가 죽어도 재개 가능해야 한다(추정: 운영 설계 원칙).  
- 변경이 라이브 시스템 장애의 큰 비중을 차지한다는 SRE 관찰을 그대로 적용해, VERIFY/ROLLBACK을 1등 시민으로 둔다. citeturn5search0  

2) **Task Queue(작업 큐, 단일 진실 소스)**  
- 큐는 “할 일 목록”이 아니라, 각 작업의 **완료 조건/검증 명령/리스크 등급/예산**까지 포함해야 에이전트가 길을 잃지 않는다(컨텍스트 외부화). citeturn0search1  

3) **Workspace + Branch 격리(안전 샌드박스)**  
- 모든 작업은 새 워크스페이스(컨테이너/임시 디렉터리)에서 수행하고, git 브랜치는 `agent/<task-id>`로 분리한다.  
- 보호 브랜치에는 직접 푸시 금지, PR만 허용(아래 권한 섹션에서 구체화). citeturn1search0turn1search12  

4) **검증 게이트(빠른 것부터 계층화)**  
- 빠른 피드백이 품질의 핵심이라는 연속적 테스트 원칙을 따르되, 무인 루프에서는 “매 루프마다 전체 테스트”가 아니라 **계층형 게이트**로 비용을 통제한다. citeturn0search29turn0search6turn2search0  
  - Gate-0: 포맷/린트/타입체크(수십 초~수분)  
  - Gate-1: 변경 파일에 매핑된 단위 테스트(수분)  
  - Gate-2: 중간(통신/DB 없는) 통합 테스트(수분~수십 분)  
  - Gate-3: 큰(e2e) 테스트는 야간/주기 배치로 분리하거나 “격리 풀”에서만 돌림(플래키 리스크가 높음). citeturn2search18turn0search25  

5) **관측(Logs + Metrics + Artifacts)**  
- 무인 운영은 “새벽에 무슨 일이 있었는지”가 반드시 재구성 가능해야 한다. Google SRE가 모니터링/알림 원칙을 정리하듯, 루프도 자체 SLO/알람을 가져야 한다. citeturn4search6turn5search0  
- 추천 산출물(각 Task 단위):  
  - progress log(JSONL)  
  - decision log(Markdown + 구조화 메타)  
  - 실행 커맨드/출력 캡처  
  - diffstat, 변경 파일 리스트  
  - 테스트 리포트(JUnit XML 등)  

### “밤샘 안정성”을 높이는 루프 주기 설계(권장값, 추정/경험 기반)
- **루프 타임박스:** 10~25분(1 작업의 PLAN+IMPLEMENT+Gate-0/1까지), 실패 시 빠르게 중단/재시도.  
- **diff 제한:** 작업당 변경 파일 ≤ 10, 논리 변경 LOC ≤ 200~400(초기값). 작은 변경이 코드 건강과 검토/디버깅에 유리하다는 가이드를 운영 제약으로 강제한다. citeturn5search5turn5search12  
- **대화 세션 길이:** 30~60분마다 “새 세션”으로 리셋(컨텍스트 포화 방지), 리셋 시에는 “State Pack(요약팩)”만 주입. 컨텍스트 윈도우/예산 개념과 경고 메커니즘을 전제한 정책이다. citeturn0search1turn0search27  
- **CI 제약 대응:** GitHub-hosted runner는 job 6시간 제한이므로, “밤샘”은 (a) job 체이닝, (b) self-hosted runner(최대 5일)로 설계해야 한다. citeturn3search8  

### progress log / decision log / task queue 형식(권장)

- **Task Queue: YAML(사람 친화) + 엄격한 필드(기계 처리)**  
- **Progress Log: JSONL(append-only, 재시도/부분 실패에 강함)**  
- **Decision Log: Markdown(사람이 아침에 읽기 좋음) + decision events는 JSONL에도 병행 기록**

예시 스키마(요지):

```yaml
# task-queue.yaml
- id: T20260315-001
  title: "FooService: timeout 처리 경로 리팩터링"
  risk: "MEDIUM"        # LOW/MEDIUM/HIGH
  budget:
    max_minutes: 25
    max_api_calls: 40   # 추정: 구현에 맞게
    max_diff_loc: 300
  acceptance:
    - "foo 요청이 2초 이상 지연되면 504로 매핑"
    - "기존 행동(헤더/로그 포맷) 유지"
  verify:
    gate0: ["lint", "format", "typecheck"]
    gate1: ["pytest tests/foo/test_timeout.py -q"]
    gate2: ["pytest tests/integration/test_gateway.py -q"]
  rollback:
    strategy: "git revert"
    criteria:
      - "gate1 실패 2회 연속"
      - "flake suspected"
  notes:
    required_files:
      - "docs/architecture.md"
      - "src/foo/service.py"
```

```json
{"ts":"2026-03-15T23:05:12+09:00","task_id":"T20260315-001","step":"PLAN","model":"sonnet","summary":"리팩터링 범위를 timeout 경로로 제한","token_estimate":8200}
{"ts":"2026-03-15T23:18:49+09:00","task_id":"T20260315-001","step":"VERIFY_GATE1","cmd":"pytest tests/foo/test_timeout.py -q","exit":0,"duration_s":83}
{"ts":"2026-03-15T23:19:10+09:00","task_id":"T20260315-001","step":"COMMIT","hash":"abc123","diff_loc":182}
```

**흔한 안 좋은 예**  
- 작업 큐가 “해야 할 일 제목”만 있고, 완료 조건/검증 명령이 없다 → 에이전트가 컨텍스트를 잃으면 즉시 방황한다. citeturn0search1  
- 로그가 사람용 텍스트로만 남아 재시도/집계/원인 분석이 불가능하다(무인 운영에서 MTTR이 늘어난다). citeturn4search6turn4search18  
- CI 제한(6시간/job, 무출력 종료)을 무시하고 장시간 단일 실행에 매달린다. citeturn3search8turn3search5  

**더 나은 대안**  
- “작업 큐 = 완료 조건 + 검증 + 예산 + 리스크”를 필수 필드로 두고, Controller가 이를 강제한다. citeturn0search1  
- 로그는 JSONL로 append-only, 결정은 Markdown으로 요약(아침에 읽히는 형태) + 기계 집계가 동시에 가능하게 한다(추정: 운영 경험 기반).  
- CI 제약은 설계 입력값으로 받아들여 job 체이닝/runner 선택으로 구조를 맞춘다. citeturn3search8turn3search5  

## 권한 및 제한 관리 전략

**왜 중요한가**  
무인 루프는 “권한이 넓을수록 생산성↑”가 아니라 “권한이 넓을수록 복구 비용↑”으로 수렴한다. 특히 자동화 파이프라인은 토큰/비밀/배포 권한을 다루기 때문에, 원칙적으로 최소권한이 필요하다. citeturn4search3turn4search7  

**어떻게 설계하는가**  
권한은 “사전 승인 가능한 범위(allow)”와 “무조건 승인이 필요한 범위(block)”를 명확히 하고, 기술적으로 강제한다(Policy-as-Code).

### 사전 승인(무인 허용) 권한 범위(권장)
아래는 “밤샘 무인”에 필요한 최소 세트다(추정: 일반 저장소 기준).

- **읽기 권한**: repo checkout, 파일 읽기, grep, 코드 검색  
- **로컬 빌드/테스트 실행**: package install은 “락파일 기반 + 허용 레지스트리만”처럼 제한(가능하면 캐시/미러 사용)  
- **로컬 브랜치 생성/커밋**: 단, 보호 브랜치 직접 push 금지  
- **PR 생성/업데이트**: PR 본문에 자동 생성된 decision/progress 요약 포함  
- **CI 트리거**: PR 기반으로 자동 수행(사람 클릭 불필요)

이때 entity["company","GitHub","code hosting platform"] 기준으로는 보호 브랜치에 “필수 상태 체크 통과 전 병합 금지”를 강제할 수 있고, auto-merge도 “필수 조건 충족 시 자동 병합”으로 작동한다. citeturn1search0turn1search4  

### 승인 없이 돌리면 안 되는 작업(강력 제한)
다음은 “무인 루프에서 가장 사고를 내기 쉬운 범주”다(추정). 원칙적으로 Policy Gate에서 차단하거나, 최소한 “승인 토큰”이 있어야 실행되게 한다.

- **비밀/권한 취급**: 새 시크릿 생성/회전, 권한 확대, 토큰을 로그에 출력할 가능성이 있는 행동  
- **배포/릴리즈/프로덕션 변경**: 태그 푸시, 릴리즈 생성, 인프라 변경, DB 마이그레이션 적용  
- **대규모 파일 이동/삭제**: `rm -rf`, 리포지토리 정리, 대량 리네임(되돌리기 어려움)  
- **의존성 대규모 업데이트**: lockfile 대규모 변경, 공급망 리스크 증가  
- **보안 민감 변경**: 인증/인가/암호화/결제/PII 경로  
- **자동 머지(특히 main 직접 반영)**: 자체 규칙을 통과하더라도 리스크가 큼

### 최소권한(Least Privilege) 구현 포인트
- GitHub Actions는 `GITHUB_TOKEN` 권한을 최소로 설정하고 작업별로 필요할 때만 상승시키는 것을 권장한다(기본 read-only 권장). citeturn4search3turn4search31  
- 이 원칙을 “에이전트용 토큰”에도 그대로 적용한다(예: PR 생성만 가능한 토큰, 머지는 불가). citeturn4search3turn4search7  

### usage limit / 컨텍스트 한계를 고려한 운영 정책(필수)
- Claude Help Center는 usage limit을 “일정 기간의 대화 예산”으로 설명한다. 무인 루프는 “지속적으로” 사용하므로, **시간대별 작업량을 평준화**하지 않으면 새벽 중간에 정지한다. citeturn6search9  
- Claude API 문서의 rate limit/spend limit 구분을 그대로 운영 정책으로 가져가면 좋다:  
  - **Rate budget(분당/시간당 호출수)**: Controller에서 토큰 버킷(클라이언트 측 레이트 리밋)을 구현  
  - **Spend budget(일/주 비용)**: 하루 예산 초과 시 “더 이상 생성하지 않고 요약/정리 작업만 수행” 모드로 전환 citeturn0search0  
- 컨텍스트는 Claude 문서에서 모델별 윈도우(예: 200k/1M)와 예산 경고 형태로 설명된다. 운영적으로는 “대화 길이”가 아니라 **상태 팩 주입**으로 설계를 바꿔야 한다. citeturn0search1turn0search27turn0search4  
- (참고) 2025년경부터 주간 한도 같은 제한이 도입된 정황이 보도된 바 있다. 따라서 “밤샘”은 정책/한도 변화에도 멈추지 않도록 “작업량 조절 + 중단 후 재개”를 기본으로 둬야 한다. citeturn6search4  

**흔한 안 좋은 예**  
- 에이전트에 repo write + secrets + release 권한을 한꺼번에 부여(사고 시 복구 불가). citeturn4search3  
- 보호 브랜치 규칙 없이 main에 직접 커밋(검증 실패가 곧 서비스 장애로 연결). citeturn1search0turn5search0  
- usage limit에 걸리면 “계속 재시도”로 버팀 → 429/차단/세션 붕괴로 악화(우회가 아니라 악순환). citeturn0search0turn2search10  

**더 나은 대안**  
- 기본은 “PR 만들기까지” 자동, “머지/배포”는 강한 조건 또는 별도 승인지점으로 분리한다(무인이어도 정책상 승인이 가능하도록 ‘사전 승인 토큰’ 모델). citeturn1search0turn1search4  
- CI 토큰/권한은 최소권한으로 시작하고 job별 상승. citeturn4search3turn4search31  
- rate/usage는 Controller가 선제적으로 평준화하고, 한도 근접 시 “정리 모드”로 전환(작업 생산을 멈추고 상태를 안전하게 저장). citeturn6search9turn0search0  

## 사전 문서화 패키지

**왜 중요한가**  
무인 루프에서 문서는 “사람을 위한 설명”이 아니라, 에이전트가 컨텍스트를 잃지 않게 하는 **외부 메모리(ground truth)** 다. 컨텍스트 윈도우/세션 누적 한계를 문서로 외부화하지 않으면, 장시간 실행일수록 방향성이 붕괴한다. citeturn0search1turn0search27  

**어떻게 설계하는가**  
“최소 문서 패키지”를 저장소 루트에 고정된 경로로 두고, Controller가 매 세션 시작 시 이를 강제 로드하도록 한다.

### 최소 문서 패키지(권장 구성)
1) **AGENT_CHARTER.md (에이전트 헌장)**  
- 목표/금지/우선순위/정의(Definition of Done)  
- 허용 명령/금지 명령(권한 정책 요약)  
- “멈춰야 하는 조건” (예: Gate-1 연속 실패, 플래키 의심, 한도 80% 도달)  
- 사용량(usage)과 대화 길이(length) 제한을 고려한 “세션 리셋 규칙” citeturn6search9turn0search22turn0search1  

2) **REPO_PLAYBOOK.md (저장소 실행 지침서)**  
- 빌드/테스트/린트 표준 명령  
- “빠른 테스트 세트”와 “전체 테스트 세트” 정의(계층형 게이트) citeturn0search29turn2search0  
- 플랫폼 제한(예: GitHub Actions job 6h, GitLab 무출력 종료 등)을 반영한 CI 실행 전략 citeturn3search8turn3search5  

3) **ARCHITECTURE_BASELINE.md (현재 아키텍처 기준선)**  
- 핵심 모듈 경계, public API, 금지 패턴  
- 대규모 변경은 “점진적 변경” 기법(예: Branch by Abstraction)을 기본으로 함을 명시 citeturn1search2turn1search10  

4) **RISK_REGISTER.md (리스크 레지스터)**  
- 플래키 테스트 목록/격리 정책(large test가 더 플래키하다는 데이터 근거 포함) citeturn2search18turn0search25  
- 자주 깨지는 CI 스텝, 환경 의존성, 재현 불가 이슈의 우회로  

5) **TASK_QUEUE.yaml (단일 큐)**  
- 앞 섹션 제안 포맷대로 “완료 조건/검증/예산” 포함

### 문서 패키지를 “길 잃지 않게” 만드는 운영 규칙(권장)
- Controller는 매 작업 시작 시 `AGENT_CHARTER.md`와 해당 task의 “acceptance/verify”만을 컨텍스트에 넣는다(그 외는 필요 시 검색). 컨텍스트 윈도우 예산/경고 개념에 맞춘 설계다. citeturn0search1turn0search27  
- “대화가 길어질수록 잊는다”는 전제를 받아들이고, **규칙은 대화가 아니라 파일에 둔다**(추정: 운영 경험). citeturn0search1  

**흔한 안 좋은 예**  
- 문서가 위키/슬랙/노션 등 흩어져 있고, 저장소에는 없다 → 에이전트가 접근/검색 실패 시 방황한다(무인에서 치명적). citeturn0search1  
- 빌드/테스트 명령이 최신이 아니거나, CI와 로컬이 다르게 동작(비결정성 증가). 결정적/재현 가능한 빌드 환경 기술이 없으면 이런 문제가 누적된다. citeturn4search1turn4search9  

**더 나은 대안**  
- 문서의 “위치/파일명”을 표준화하고(루트 고정), Controller가 존재 여부를 사전 점검한다(없으면 시작하지 않음). citeturn0search1  
- 재현 가능한 빌드 환경을 문서로 기록하라는 권고(빌드 환경 경계 정리)를 따라, toolchain/버전을 명시한다. citeturn4search9turn4search1  

## 테스트 중심 대규모 코드 생성 전략

**왜 중요한가**  
무인 코딩은 “생산성”보다 “검증 가능성”이 병목이다. 테스트가 없으면 루프는 빠르게 코드를 쌓지만, 품질 신호가 없어져 결국 대규모 회귀/실패로 폭발한다. 또한 큰 테스트는 플래키 가능성이 높아 무인 안정성을 해친다. 따라서 **테스트 전략과 기능 구현 전략을 분리**해, “작고 빠른 테스트로 루프 안정성 확보”와 “필요한 범위 검증”을 동시에 만족해야 한다. citeturn2search18turn0search6turn2search0turn0search29  

**어떻게 설계하는가**  

### 테스트 전략(루프 안정성 관점)
- entity["people","Martin Fowler","software engineer author"]의 Test Pyramid는 테스트를 “granularity 버킷”으로 나누고, 빠른 테스트를 많이 두어 피드백을 빠르게 하는 방향을 제시한다. citeturn0search6  
- Google Testing Blog는 “테스트 크기(small/medium/large)” 개념을 소개하며, large 테스트의 플래키 비율이 높음을 보고한다. 무인 루프에서는 large를 “주력 게이트”로 쓰면 안정성이 급락한다. citeturn2search0turn2search18  
- Android 문서도 테스트 피라미드에서 “작은 테스트는 빠르고 신뢰성이 높고, 큰 테스트는 유지보수가 어렵다”고 정리한다. citeturn2search15  

따라서 무인 루프의 기본은:
- Gate-0/1(작고 빠른 테스트)을 “매 작업”에서 강제  
- Gate-2(중간)는 “리스크/영향”에 따라  
- Gate-3(큰/e2e)은 “야간 배치” 또는 “격리 파이프라인”

### 기능 구현 전략(대규모 생성 관점)
대규모 코드 생성(예: 10만 줄)에서 가장 흔한 실패는 에이전트가 **아키텍처 경계를 무시하고 복잡도를 한 번에 끌어올리는 것**이다. 이를 막으려면 “점진적 변경” 패턴이 필요하다.

- “Branch by Abstraction”은 대규모 변경을 점진적으로 진행하면서도 지속적으로 릴리즈할 수 있게 하는 기법으로 설명된다. 대규모 리포지토리 변경을 밤샘 루프에 태울 때 특히 유리하다. citeturn1search2turn1search10  
- 작은 배치/짧은 브랜치 전략(트렁크 기반)은 잦은 통합으로 리스크를 줄이는 방식으로 설명된다. citeturn1search3turn1search28  

### “왜 테스트 코드가 커지는가”(요구사항 포함, 추정+근거)
다음은 테스트 비중이 커지는 대표 메커니즘이다(핵심은 “대규모 변경일수록 품질 신호를 더 촘촘히 요구”하게 된다는 점).

1) **변경 표면적 증가**: 기능 코드가 늘면 public API/엣지 케이스/상태 조합이 늘어 테스트 케이스가 기하급수적으로 증가(추정).  
2) **회귀 방지 비용**: 무인 루프는 사람의 직관/리뷰를 대체해야 하므로, 자동 검증(테스트/정적 분석)에 더 큰 비중을 둔다. “자동 빌드(테스트 포함)로 통합을 검증”하는 CI 원칙과 맞닿아 있다. citeturn0search9turn0search29  
3) **테스트 인프라/픽스처/헬퍼 누적**: 대규모 시스템 테스트는 격리 계층(스텁/목/팩토리/데이터 빌더)이 생기고, 이 코드가 순수 기능 코드와 별개로 커진다(추정). “테스트 크기/스코프/의존성”을 구분해 설명하는 구글의 테스트 분류가 이를 뒷받침한다. citeturn2search4turn2search0  
4) **large 테스트의 리스크를 줄이기 위한 small/medium 확대**: large가 플래키할수록, 안정성을 위해 small/medium을 더 많이 만든다(무인 루프에서는 특히). citeturn2search18turn2search0  

### “10만 줄 결과물 + 7만 줄 테스트”를 가능하게 하는 전제와 루프 설계(요구사항)
아래는 “하룻밤에 17만 줄을 한 번에 생성”이 아니라, **장시간/다회 밤샘을 통해 누적 산출이 가능한 형태**를 목표로 한 전제다(현실적 재현성 중심).

전제(필수):
- **모듈 경계가 문서로 고정**되어 있고(ARCHITECTURE_BASELINE), 변경은 경계를 따라 들어간다. citeturn1search2turn1search10  
- **빠른 테스트 게이트가 충분히 촘촘**해, 작은 변경이 매번 빠르게 검증된다. citeturn0search6turn2search0turn0search29  
- **빌드/테스트 시간이 누적될수록 폭발하지 않게** 캐시/증분 빌드가 있다. 예: Bazel remote cache는 다른 머신의 빌드 산출물을 재사용할 수 있음을 문서화한다. citeturn3search3turn4search0  
- **재현 가능한(결정적) 빌드 환경**이 정리돼 있어 “어제 통과한 게 오늘 통과”한다(환경 드리프트 최소화). citeturn4search1turn4search9turn4search0  

루프 설계(권장):
- (a) 기능을 “수직 슬라이스”로 쪼개고, 각 슬라이스마다 **테스트(먼저)** → 구현 → 리팩터 → 통합의 동일 루프를 강제(추정).  
- (b) 테스트 생성도 “템플릿+규칙”을 둬서 중복을 줄이고, small/medium 중심으로 확장(구글 테스트 사이즈 개념 사용). citeturn2search0turn2search4turn2search18  
- (c) 매 N개 작업(예: 6~12개)마다 “품질 부채 스프린트(테스트 안정화/플래키 제거/리팩터)”를 큐에 강제로 삽입(Stop-the-line 성격, 추정). 플래키를 방치하면 CI 가치가 급락한다는 경고를 반영한다. citeturn0search25turn2search18  

**흔한 안 좋은 예**  
- e2e 테스트를 주 게이트로 두고, 밤새 실패하면 무한 재시도(large 테스트는 플래키 확률이 큰데 이를 정면으로 맞음). citeturn2search18  
- 테스트/빌드 시간이 길어져서 CI 시간 제한(6h/job, 무출력 종료 등)에 자주 걸림 → 안정성 급락. citeturn3search8turn3search5  
- 대규모 리팩터를 “한 PR”로 밀어붙임 → 충돌/리뷰/원인 규명이 어려워지고 롤백이 부담(“작은 변경” 원칙 위배). citeturn5search5turn1search6  

**더 나은 대안**  
- small/medium 테스트 중심의 빠른 게이트 + large는 격리/배치로 이동. citeturn2search18turn2search0turn0search6  
- 점진적 대규모 변경은 Branch by Abstraction 같은 패턴으로 “중간 상태도 동작”하게 유지. citeturn1search2turn1search10  
- 빌드 가속(캐시/증분)과 재현성(결정적 환경)을 전제로 CI 비용을 통제. citeturn3search3turn4search1turn4search0  

## 실패 복구 및 재시도 전략

**왜 중요한가**  
밤샘 무인에서 “실패 0”은 비현실적이다. entity["company","Google","technology company"] SRE가 error budget으로 “허용 가능한 실패”를 수치화하듯, 무인 루프도 실패를 전제로 **MTTR을 줄이는 복구 설계**가 있어야 한다. citeturn0search5turn2search3turn5search0  

**어떻게 설계하는가**  
복구는 “재시도”가 아니라 **분류(triage) → 격리 → 재현 → 최소 롤백**의 파이프라인이어야 한다.

### 실패 분류(Controller가 자동)
1) **Provider/서비스 장애**(로그인 실패, 5xx, 플랫폼 오류)  
- 예: Claude.ai/Claude Code 로그인 이슈가 공식 status에 올라오는 사건이 실제로 있었다. citeturn6search0  
- 처리: 즉시 중단 후 backoff, “정리 모드”(상태 저장, 리포트 생성)로 전환.  

2) **rate limit / 429 / throttle**  
- 429는 rate limit 초과를 의미하며, `Retry-After`를 존중하고 exponential backoff를 쓰라는 가이드가 다수 문서에 있다. citeturn2search10turn2search20turn2search2  
- 처리: (a) Controller가 자체 레이트 리미팅, (b) 재시도는 지수 백오프 + 지터 + 상한, (c) 병렬 재시도 금지. citeturn2search6turn2search10  

3) **테스트 실패**  
- “결정적 실패”와 “플래키 의심”을 분리해야 한다. large 테스트 플래키 비중이 크므로, large 단독 실패는 우선 격리/재시도 정책을 다르게 가져간다. citeturn2search18turn0search25  

4) **빌드/환경 실패(비재현)**  
- 재현 가능한 빌드/결정적 시스템 원칙에 어긋난 경우가 많다(시간/파일 순서/환경 차이). citeturn4search1turn4search9  
- 처리: 환경 캡처(컨테이너 이미지/lockfile/툴체인 버전) 기록 후, “환경 안정화 태스크”를 큐에 올린다. citeturn4search9  

### 재시도 정책(권장, 추정/경험 기반)
- **재시도는 “동일 입력 동일 결과”일 때만**: rate limit/네트워크/일시적 장애는 재시도 가치가 높음. citeturn2search10turn2search20  
- 테스트 실패 재시도는 1회 이내로 제한하고, 2회 연속 실패 시 “작업 롤백 + 플래키/원인 분석 태스크 생성”. large 테스트는 플래키가 높으므로 격리 정책을 둔다. citeturn2search18turn0search25  
- “무한 재시도”는 usage/rate를 태워서 새벽에 완전 정지시키는 최악 패턴이다. citeturn0search0turn6search9  

### 롤백 기준(운영 규칙으로 강제)
SRE의 변경 관리에서 “빠른 탐지와 안전한 롤백”이 핵심이라고 명시된다. citeturn5search0turn5search23  
무인 코딩에서는 이를 다음처럼 구체화한다(권장):

- Gate-1 실패 2회 연속 → 해당 task 브랜치 변경 전부 `git revert` 또는 브랜치 폐기  
- diff가 예산(LOC/파일 수)을 초과 → 커밋 금지, 작업을 더 쪼개서 큐에 재등록  
- 플래키 의심(동일 커밋에서 large만 간헐 실패) → large는 격리, small/medium 통과를 우선 신뢰 citeturn2search18turn2search0  

**흔한 안 좋은 예**  
- 429/limit에 걸렸는데 즉시 재시도 루프(“더 빨리 죽는” 구조). citeturn2search10turn0search0  
- 테스트 실패를 “일단 무시하고 다음 작업”으로 진행(회귀가 누적돼 아침에 폭발). citeturn0search29turn0search9  
- 롤백(되돌리기) 절차가 문서/자동화되어 있지 않아 실패 시 수동 개입이 필수. SRE는 안전한 롤백을 변화 관리의 핵심으로 본다. citeturn5search0turn5search23  

**더 나은 대안**  
- 실패 분류/재시도/롤백을 Controller 정책으로 코드화하고, 로그/리포트에 “왜 멈췄는지”를 남긴다. citeturn4search6turn5search0  
- rate limit은 `Retry-After` 존중 + 지수 백오프(상한/지터 포함)로 표준화한다. citeturn2search10turn2search20turn2search6  
- 플래키는 격리하고, 작은 테스트 중심으로 게이트를 재구성한다. citeturn2search18turn0search25turn2search0  

## 바로 적용 가능한 표준 운영 절차(SOP)

**왜 중요한가**  
무인 운영은 “좋은 아이디어”보다 “항상 같은 절차”가 안정성을 만든다. 절차가 없으면 한도/컨텍스트/플래키 같은 구조적 문제가 매번 다른 형태로 터지고, 아침에 원인 분석이 불가능해진다. citeturn4search6turn5search0turn6search9  

**어떻게 설계하는가**  
SOP는 “시작 전 준비 → 실행 → 자동 중단/복구 → 종료 리포트”로 단순화하고, 모든 것을 Controller가 강제한다.

### SOP 단계(권장)

**Phase 0. 사전 준비(한 번 세팅, 이후 유지)**  
- 보호 브랜치 규칙 설정: main 보호 + required status checks + (가능하면) PR 필수. citeturn1search0turn1search12turn1search25  
- CI 제한 확인: GitHub Actions job 6h(호스티드), self-hosted 5일; GitLab 기본 60분/무출력 60분 종료 등. “밤샘”을 어떤 실행 플랫폼에 태울지 결정. citeturn3search8turn3search5turn3search17  
- 토큰 최소권한 설정: `GITHUB_TOKEN` 기본 read-only + job별 상승. citeturn4search3turn4search31  
- (가능하면) 재현 가능한 빌드 기반: toolchain 버전 고정, deterministic build 원칙 문서화. citeturn4search1turn4search9  

**Phase 1. 밤샘 실행 전(매일 저녁 5~10분)**  
- TASK_QUEUE.yaml에 “오늘 밤 목표”를 넣되, 각 task에 acceptance/verify/budget/risk를 반드시 기입. citeturn0search1  
- 리스크가 HIGH인 항목(배포/보안/대규모 삭제)은 큐에 넣지 않거나 “승인 필요”로 마크. citeturn4search3turn5search0  
- 플래키 레지스터/격리 리스트 최신화(large 플래키 데이터 근거). citeturn2search18turn0search25  

**Phase 2. 실행(Controller 구동)**  
- Controller가 task lease → 새 workspace/브랜치 생성 → PLAN(짧게) → IMPLEMENT(타임박스) → Gate-0/1 실행. citeturn0search9turn0search29  
- Gate 통과 시에만 커밋. PR 생성 시 progress/decision 요약 자동 첨부. citeturn1search0turn1search4  
- 세션은 30~60분마다 리셋하고 State Pack(요약+현재 큐 상태+최근 결정)만 주입(컨텍스트 포화 방지). citeturn0search1turn0search27  
- rate/usage는 Controller가 예산을 추적하고, 한도 근접 시 “정리 모드”로 전환. citeturn6search9turn0search0  

**Phase 3. 자동 중단 조건(무인 안정성의 핵심)**  
- Provider 장애 감지(상태 페이지 장애/로그인 실패/연속 5xx) 시 즉시 중단 및 backoff. 실제로 Claude.ai/Claude Code 로그인 이슈가 발생한 사례가 있으므로 “외부 장애”는 정상 시나리오다. citeturn6search0  
- 429/레이트리밋은 `Retry-After` + exponential backoff로 제한 재시도, 임계치 초과 시 중단. citeturn2search10turn2search20turn2search6  
- Gate-1 연속 실패, diff 예산 초과, 플래키 의심 시 “작업 롤백 + 분석 태스크 생성” 후 다음 작업으로 넘어가지 않고 정리. citeturn2search18turn0search25  

**Phase 4. 종료(아침에 남기는 자동 리포트)**  
- 완료/실패/보류 PR 목록, 실패 원인 분류 통계, 한도 사용 추정치, 플래키 의심 목록, 다음 밤 큐 추천을 Markdown으로 생성(추정: 운영 설계). citeturn4search6turn6search9  

**흔한 안 좋은 예**  
- SOP 없이 “그때그때 프롬프트로 운영” → 밤마다 결과가 달라 재현 불가. citeturn0search1turn4search6  
- 자동 중단 조건이 없어 “실패 상태로 계속 전진” → 스택이 망가지고 아침에 대규모 롤백. citeturn5search0turn0search29  
- 보호 브랜치/상태 체크 없이 자동 커밋/머지. 변경이 장애의 큰 비중을 차지한다는 관찰에 정면으로 위배된다. citeturn5search0turn1search0  

**더 나은 대안**  
- 보호 브랜치 + 필수 체크 + 최소권한으로 “사고 가능성”을 구조적으로 줄이고, 실패는 “작게” 만들고 “빨리” 되돌린다. citeturn5search0turn1search0turn4search3  
- 작업을 작은 배치로 강제하고, 컨텍스트는 파일(문서/큐/로그)로 외부화한다. citeturn5search5turn0search1  

### A. 실행 전 체크리스트(밤샘 시작 직전)

- 보호 브랜치 규칙이 켜져 있고(required status checks), main 직접 푸시가 차단되어 있다. citeturn1search0turn1search12  
- CI 제한(예: GitHub Actions job 6h)을 고려한 실행 방식(job 체이닝 또는 self-hosted runner)으로 구성돼 있다. citeturn3search8  
- `GITHUB_TOKEN`/에이전트 토큰 권한이 최소로 설정돼 있다(기본 read-only). citeturn4search3turn4search31  
- TASK_QUEUE에 오늘 밤 작업이 “acceptance + verify + budget + risk”를 포함해 작성돼 있다. citeturn0search1  
- Gate-0/1이 로컬에서 1회라도 정상 실행됨(빌드/테스트 커맨드 유효성 확인). citeturn0search29  
- 플래키 레지스터가 최신이며, large 테스트는 격리/재시도 정책이 별도로 있다. citeturn2search18turn0search25  
- “중단/정리 모드”가 구현되어 있어 한도/장애 시 상태를 저장하고 멈출 수 있다. citeturn6search9turn0search0turn6search0  

### B. 최소 문서 템플릿 예시

```md
# AGENT_CHARTER.md

## Mission
- 밤샘 무인 루프로, TASK_QUEUE.yaml의 작업을 "작게/검증 가능하게" 처리한다.

## Hard Rules (Must)
- main(보호 브랜치)에 직접 push 금지. PR만 생성.
- Gate-0/1 성공 전 커밋 금지.
- diff 예산 초과 시 작업을 더 쪼개서 큐에 재등록.
- 429/limit 발생 시 즉시 재시도 금지. backoff 정책 준수.
- HIGH risk 작업(배포/보안/대규모 삭제/권한 변경)은 실행 금지.

## Session Policy
- 45분마다 새 세션으로 전환. State Pack만 주입.
- 1 task = 10~25분 타임박스.

## Stop Conditions
- Gate-1 연속 실패 2회
- large test flaky 의심
- usage 예산 80% 도달
- provider 장애 감지

## Deliverables per task
- PR(또는 브랜치) + changelog
- progress.jsonl / decisions.md
- 테스트 리포트
```

```md
# REPO_PLAYBOOK.md

## Fast Gates
- Gate-0: lint/format/typecheck
- Gate-1: changed-file mapped unit tests

## Full Gates (Batch/Nightly)
- Gate-2: integration
- Gate-3: e2e (격리 파이프라인)

## How to Run
- <project-specific commands here>

## Known Flakes
- tests/e2e/... (격리)
```

### C. 밤샘 실행 운영안 샘플(현실 재현형)

- **22:30–22:40** Phase 1(큐/문서 점검): 오늘 밤 12개 task 등록(각 10~25분).  
- **22:40–00:30** Loop A(저위험 LOW/MEDIUM): 4개 task 처리. 매 task는 Gate-0/1 통과 시 커밋+PR.  
- **00:30–00:45** “정리 모드” 체크포인트: State Pack 생성, 큐 재정렬(실패/보류 태스크 분리).  
- **00:45–02:30** Loop B(리팩터/테스트 강화): Branch by Abstraction 단계 1~2 수행(추정: 대상이 대규모 변경일 경우). citeturn1search2turn1search10  
- **02:30–03:00** Batch Gate-2(선택): MEDIUM 리스크 PR만 통합 테스트 실행. large/e2e는 격리. citeturn2search18turn2search0  
- **03:00–05:30** Loop C(잔여 작업): usage 예산 감시(80% 도달 시 생산 중단, 리포트로 전환). citeturn6search9  
- **05:30–06:00** 종료 리포트 자동 생성: 완료 PR 목록, 실패 분류, 플래키 후보, 다음 큐 추천.

### 가장 중요한 5가지 실수(별도 정리)

1) **작업을 크게 묶고 “마지막에 한 번” 검증**하려는 설계(플래키/한도/시간 제한에 취약). citeturn2search18turn3search8  
2) **보호 브랜치/필수 상태체크 없이** 무인 루프가 main을 바꾸게 두는 것(변경이 장애의 큰 원인이라는 관찰과 충돌). citeturn5search0turn1search0  
3) **권한 과다 부여(특히 토큰/배포/시크릿)**: 최소권한 원칙을 무시하면 사고 반경이 커진다. citeturn4search3turn4search31  
4) **플래키 테스트를 방치**하고 재시도로 덮는 것(무인 루프에서 재시도 폭발→한도/시간 초과). citeturn2search18turn0search25  
5) **컨텍스트를 대화에만 의존**하는 것(장시간일수록 규칙/목표/금지사항이 누락). 상태를 파일(큐/로그/문서)로 외부화해야 한다. citeturn0search1turn0search27