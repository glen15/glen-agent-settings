claude -p로 새 호출을 시작해도 Max 플랜의 5시간 usage window가 리셋되지는 않는다. 그건 컨텍스트 관리용이지, 플랜 한도 리셋용이 아니다. Claude와 Claude Code는 같은 Max 한도를 공유한다. 또 현재 공개 문서 기준으로 1M context는 Claude Max/Claude Code 구독 경로가 아니라 Sonnet 4의 API 베타 기능이고, Max 같은 유료 Claude 플랜의 개별 채팅 컨텍스트는 200K+ 기준이다. 그래서 밤샘 무인 운영의 핵심은 “더 긴 세션”이 아니라 “짧은 작업 단위 + 새 컨텍스트 회전 + 외부 상태 저장 + limit 도달 시 자동 정지/대기”다.
	1.	Max 200에서 밤샘 중 세션 리밋에 도달하면 어떻게 대처하나

먼저 구분해야 할 게 두 가지다. Anthropic이 Max 플랜 문서에서 말하는 “session”은 첫 메시지부터 시작되는 5시간 usage 구간이고, Claude Code JSON 결과에 나오는 session_id는 대화 세션 식별자다. claude -p를 새로 호출하면 보통 새 대화 세션은 만들지만, Max 플랜의 5시간 usage window를 새로 열거나 리셋하지는 않는다. 게다가 Claude 웹/앱과 Claude Code 사용량은 같은 Pro/Max 한도에 합산된다.

운영적으로는 이렇게 가져가는 게 가장 안전하다.
	•	밤샘 기본 모델은 Sonnet 우선으로 둔다. Max 사용자는 사용량 임계치에 도달하면 Claude Code가 Opus 4에서 Sonnet 4로 자동 전환되며, Max 20x에서는 그 기준이 50%다. Anthropic은 Opus가 Sonnet보다 usage limit를 대략 5배 빠르게 소모한다고 안내한다. 밤샘 루프는 “긴 탐색”이 많아서 Opus 고정이 특히 불리하다.
	•	작업 단위를 짧게 쪼개고, 각 단위마다 claude -p --max-turns N --output-format json으로 실행한다. --max-turns는 공식 플래그고, JSON 결과에는 session_id, num_turns, subtype가 들어오므로 스크립트가 상태를 해석하기 쉽다.
	•	limit 경고가 뜨거나 /status에서 잔여 용량이 낮으면, 모델 호출을 멈추고 로컬 작업만 진행한다. 예를 들면 테스트 재실행, 빌드, 로그 압축, task queue 재정렬까지는 계속하고, AI 호출은 reset까지 대기한다. Anthropic 공식 안내도 Max 사용자가 limit에 닿으면 현실적 선택지는 상위 플랜, PAYG 전환, reset 대기라고 설명한다. “플랜 안에서만” 운영하려면 PAYG 옵션은 거절하고 reset을 기다리는 쪽이 맞다.
	•	--output-format json은 대화 통계용이고, 잔여 플랜 한도 계량기는 아니다. 공식 문서상 /cost는 Max/Pro 구독자용 plan-capacity meter로 쓰는 용도가 아니다. 남은 allocation 확인은 /status와 경고 메시지 쪽이 더 맞다.

실무 권장 정책은 이렇다.
새 5시간 창이 막 열린 시점에 시작 → Sonnet 기본 → 태스크당 1세션 → 태스크 실패 시 새 세션으로 요약 재투입 → limit 근접 시 AI 정지 후 로컬 검증만 수행 → reset 후 재개. 이 패턴이 Max 구독 환경에서는 가장 재현성이 높다.

추가로, Max 플랜 문서에는 월 50 session을 넘으면 접근을 제한할 수 있다는 가이드가 있다. 이건 하드컷이라기보다 과도 사용을 제어하기 위한 유연한 기준이라고 적혀 있다. 밤샘 자동화를 매일 상시 운영하는 구조라면 이 월간 가이드도 같이 염두에 둬야 한다.
	2.	왜 Ralph loop 대신 bash에서 claude -p를 반복 호출하나? Ralph는 세션 내부 루프 아닌가?

공식 CLI 문서 기준으로 claude -p "query"는 비대화형으로 실행하고 종료한다. 반대로 이전 대화를 이어가려면 --continue나 --resume를 명시해야 한다. 즉, bash에서 claude -p만 반복 호출하는 패턴은 기본적으로 새 대화 컨텍스트를 계속 여는 방식이다. 이게 인기 있는 이유는 플랜 limit를 피해서가 아니라, 컨텍스트 길이·드리프트·실패 전파를 통제하기 쉽기 때문이다.

반면 Ralph Loop의 공식 설명은, stop hook으로 세션 종료를 가로채고 동일한 프롬프트를 다시 넣어서, 파일 수정과 git 히스토리를 보존한 채 같은 작업을 반복 개선한다고 되어 있다. 즉 Ralph는 “같은 목표를 반복적으로 재급입하는 오케스트레이션”이다. 공개 설명만 보면 단일 대화가 끝없이 늘어나는 구조라기보다는, 종료 지점을 감지해서 반복 사이클을 이어 주는 loop에 가깝다. 다만 반복마다 동일한 conversation session_id를 유지하는지까지는 공개 문서로 확인되지 않으므로, 그 부분은 추정을 섞지 말고 “plugin-managed iterative loop” 정도로 보는 게 안전하다.

그래서 bash wrapper를 쓰는 이유는 보통 네 가지다.
	•	새 컨텍스트 강제: task당 fresh session을 쉽게 강제할 수 있다.
	•	외부 상태 관리: progress log, task queue, retry policy를 Claude 바깥에서 관리할 수 있다.
	•	정책 삽입: 테스트 실패 횟수, diff 크기, touched files 수에 따라 회전/중단 규칙을 넣기 쉽다.
	•	복구 단순화: 프로세스 죽음, 터미널 종료, 한도 도달 시 재시작 로직을 셸이 담당한다.

즉, Ralph가 나쁜 게 아니라, 밤샘 무인 운영에서는 “자율 개선”보다 “예측 가능성”이 더 중요할 때 bash orchestration이 더 유리한 것이다. 이건 limit 우회가 아니라, limit와 context를 더 보수적으로 관리하려는 선택이다.
	3.	1M context 업데이트 때문에 limit/성능이 걱정된다. context threshold를 걸 수 있나?

여기서는 먼저 사실관계부터 바로잡는 게 좋다.

현재 공개 문서 기준으로 1M context는 Claude Sonnet 4의 API 베타 기능이고, Anthropic API / Bedrock / Vertex AI 쪽에서 안내된다. 반면 유료 Claude 플랜의 일반 채팅 컨텍스트는 200K+이고, 별도 도움말에는 Enterprise의 Sonnet 4 채팅만 500K를 쓸 수 있다고 적혀 있다. Max/Claude Code 구독 경로를 기준으로 보면, 지금 운영 대상은 사실상 200K 컨텍스트 설계가 맞다. 따라서 지금 질문하신 “300K에서 loop 종료”는 Max 200 구독 기반 Claude Code 운영에는 현재 기준으로 맞지 않는 상한이다.

또 “1M에서 모든 토큰에 standard pricing 적용”은 공식 가격 문서와 다르다. Anthropic 공식 가격 문서에는 200K 입력 토큰을 초과하면 모든 토큰에 premium long-context pricing이 적용된다고 되어 있다. 즉, 그 부분은 현재 공개 문서 기준으로는 반대로 이해하는 게 맞다.

성능 저하 수치에 대해서는, 내가 확인한 공식 문서들은 1M의 가용성, 가격, rate limit, long-context prompting 팁은 설명하지만, 질문에 적으신 “25% 미만 저하 vs 경쟁사 50% 이상” 같은 운영 결정을 걸 만한 공식 수치는 찾지 못했다. 그래서 그 수치는 운영 전제로 삼지 않는 편이 안전하다. 공개 문서만 기준으로 보면, long context에서 중요한 건 벤치마크 숫자보다 컨텍스트를 길게 쓸수록 usage와 drift 관리가 더 중요해진다는 점이다.

그리고 가장 중요한 답:
현재 공개된 Claude Code CLI에는 --max-turns는 있지만, --max-context-tokens 같은 문서화된 플래그는 보이지 않는다. 공식 문서상 쓸 수 있는 건 --max-turns, --continue, --resume, --model, --output-format 정도다. 따라서 bash 루프에서 “300K 넘으면 종료” 같은 토큰 기반 하드 threshold를 네이티브 옵션으로 거는 건 현재 문서상 불가로 보는 게 맞다.

대신 실무에서는 이렇게 우회가 아니라 대체 정책으로 푼다.
	•	fresh-session policy: 밤샘 루프에서는 기본적으로 --continue/--resume를 쓰지 않는다. 한 태스크 = 한 fresh session.
	•	turn budget policy: --max-turns를 4~8 정도로 두고, 넘기면 결과 요약만 남기고 다음 fresh session으로 넘긴다.
	•	compaction policy: 정말 같은 세션을 이어야 할 때만 /compact나 auto-compact를 쓰고, 그마저도 마일스톤 이후에는 새 세션으로 자른다. Claude Code 문서에는 /compact, /clear, auto-compact가 있다.
	•	wrapper guardrail: “토큰 수” 대신 num_turns, diff 크기, 수정 파일 수, 실패 테스트 수, 경과 시간, 동일 오류 반복 횟수로 종료 조건을 건다. JSON 출력에는 num_turns와 session_id, 오류 subtype가 포함된다.

내 권장안은 이렇다.
Max 200 구독 기반 bash loop라면 context threshold를 토큰으로 잡지 말고, 세션 회전 규칙으로 잡아라. 구체적으로는 “태스크 1개 또는 최대 6턴 또는 테스트 실패 2회 누적 또는 diff 500~1000 LOC 초과 시 fresh session 회전” 같은 식이 훨씬 안정적이다. 이건 공식 플래그 범위 안에서 구현 가능하고, Max limit에도 더 잘 맞는다.

한 줄 결론:
당신 환경에서는 “1M context를 어떻게 잘 쓰나”보다 “200K 안에서 길어지기 전에 어떻게 자를까”가 맞는 문제다.