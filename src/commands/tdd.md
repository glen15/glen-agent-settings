---
description: 테스트 주도 개발 워크플로우 적용. 인터페이스 스캐폴딩, 테스트 먼저 생성, 최소한의 코드로 통과. 80%+ 커버리지 보장.
---

# TDD 커맨드

이 커맨드는 **tdd-guide** 에이전트를 호출하여 테스트 주도 개발 방법론을 적용합니다.

## 이 커맨드가 하는 일

1. **인터페이스 스캐폴딩** - 타입/인터페이스 먼저 정의
2. **테스트 먼저 생성** - 실패하는 테스트 작성 (RED)
3. **최소한의 코드 구현** - 통과할 만큼만 작성 (GREEN)
4. **리팩토링** - 테스트를 통과하면서 코드 개선 (REFACTOR)
5. **커버리지 확인** - 80%+ 테스트 커버리지 보장

## 사용 시점

다음 경우에 `/tdd` 사용:
- 새로운 기능 구현
- 새로운 함수/컴포넌트 추가
- 버그 수정 (버그를 재현하는 테스트 먼저 작성)
- 기존 코드 리팩토링
- 핵심 비즈니스 로직 구축

## 작동 방식

tdd-guide 에이전트가 수행하는 작업:

1. **인터페이스 정의** - 입력/출력
2. **실패할 테스트 작성** (코드가 아직 없으므로)
3. **테스트 실행** - 올바른 이유로 실패하는지 확인
4. **최소한의 구현 작성** - 테스트 통과
5. **테스트 실행** - 통과 확인
6. **코드 리팩토링** - 테스트 통과 유지
7. **커버리지 확인** - 80% 미만이면 테스트 추가

## TDD 사이클

```
RED → GREEN → REFACTOR → REPEAT

RED:      실패하는 테스트 작성
GREEN:    통과할 최소한의 코드 작성
REFACTOR: 코드 개선, 테스트 통과 유지
REPEAT:   다음 기능/시나리오
```

## 사용 예시

```
User: /tdd 마켓 유동성 점수 계산 함수 필요

Agent (tdd-guide):
# TDD 세션: 마켓 유동성 점수 계산기

## 1단계: 인터페이스 정의 (SCAFFOLD)

```typescript
// lib/liquidity.ts
export interface MarketData {
  totalVolume: number
  bidAskSpread: number
  activeTraders: number
  lastTradeTime: Date
}

export function calculateLiquidityScore(market: MarketData): number {
  // TODO: 구현
  throw new Error('Not implemented')
}
```

## 2단계: 실패하는 테스트 작성 (RED)

```typescript
// lib/liquidity.test.ts
import { calculateLiquidityScore } from './liquidity'

describe('calculateLiquidityScore', () => {
  it('유동성이 높은 마켓에서 높은 점수 반환', () => {
    const market = {
      totalVolume: 100000,
      bidAskSpread: 0.01,
      activeTraders: 500,
      lastTradeTime: new Date()
    }

    const score = calculateLiquidityScore(market)

    expect(score).toBeGreaterThan(80)
    expect(score).toBeLessThanOrEqual(100)
  })

  it('유동성이 낮은 마켓에서 낮은 점수 반환', () => {
    const market = {
      totalVolume: 100,
      bidAskSpread: 0.5,
      activeTraders: 2,
      lastTradeTime: new Date(Date.now() - 86400000) // 1일 전
    }

    const score = calculateLiquidityScore(market)

    expect(score).toBeLessThan(30)
    expect(score).toBeGreaterThanOrEqual(0)
  })

  it('엣지 케이스 처리: 거래량 0', () => {
    const market = {
      totalVolume: 0,
      bidAskSpread: 0,
      activeTraders: 0,
      lastTradeTime: new Date()
    }

    const score = calculateLiquidityScore(market)

    expect(score).toBe(0)
  })
})
```

## 3단계: 테스트 실행 - 실패 확인

```bash
npm test lib/liquidity.test.ts

FAIL lib/liquidity.test.ts
  ✕ 유동성이 높은 마켓에서 높은 점수 반환 (2 ms)
    Error: Not implemented

1 test failed, 0 passed
```

✅ 예상대로 테스트 실패. 구현 준비 완료.

## 4단계: 최소한의 코드 구현 (GREEN)

```typescript
// lib/liquidity.ts
export function calculateLiquidityScore(market: MarketData): number {
  // 거래량 0 엣지 케이스 처리
  if (market.totalVolume === 0) {
    return 0
  }

  // 컴포넌트 점수 계산 (0-100 스케일)
  const volumeScore = Math.min(market.totalVolume / 1000, 100)
  const spreadScore = Math.max(100 - (market.bidAskSpread * 1000), 0)
  const traderScore = Math.min(market.activeTraders / 10, 100)

  // 최근 활동 보너스
  const hoursSinceLastTrade = (Date.now() - market.lastTradeTime.getTime()) / (1000 * 60 * 60)
  const recencyScore = Math.max(100 - (hoursSinceLastTrade * 10), 0)

  // 가중 평균
  const score = (
    volumeScore * 0.4 +
    spreadScore * 0.3 +
    traderScore * 0.2 +
    recencyScore * 0.1
  )

  return Math.min(Math.max(score, 0), 100) // 0-100으로 제한
}
```

## 5단계: 테스트 실행 - 통과 확인

```bash
npm test lib/liquidity.test.ts

PASS lib/liquidity.test.ts
  ✓ 유동성이 높은 마켓에서 높은 점수 반환 (3 ms)
  ✓ 유동성이 낮은 마켓에서 낮은 점수 반환 (2 ms)
  ✓ 엣지 케이스 처리: 거래량 0 (1 ms)

3 tests passed
```

✅ 모든 테스트 통과!

## 6단계: 리팩토링 (IMPROVE)

```typescript
// lib/liquidity.ts - 상수와 가독성 개선으로 리팩토링
const WEIGHTS = {
  VOLUME: 0.4,
  SPREAD: 0.3,
  TRADERS: 0.2,
  RECENCY: 0.1,
} as const

const SCALE_FACTORS = {
  VOLUME: 1000,
  SPREAD: 1000,
  TRADERS: 10,
  RECENCY_PENALTY: 10,
} as const

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max)
}

export function calculateLiquidityScore(market: MarketData): number {
  if (market.totalVolume === 0) return 0

  const volumeScore = Math.min(market.totalVolume / SCALE_FACTORS.VOLUME, 100)
  const spreadScore = clamp(100 - (market.bidAskSpread * SCALE_FACTORS.SPREAD), 0, 100)
  const traderScore = Math.min(market.activeTraders / SCALE_FACTORS.TRADERS, 100)

  const hoursSinceLastTrade = (Date.now() - market.lastTradeTime.getTime()) / (1000 * 60 * 60)
  const recencyScore = clamp(100 - (hoursSinceLastTrade * SCALE_FACTORS.RECENCY_PENALTY), 0, 100)

  const weightedScore =
    volumeScore * WEIGHTS.VOLUME +
    spreadScore * WEIGHTS.SPREAD +
    traderScore * WEIGHTS.TRADERS +
    recencyScore * WEIGHTS.RECENCY

  return clamp(weightedScore, 0, 100)
}
```

## 7단계: 테스트 여전히 통과 확인

```bash
npm test lib/liquidity.test.ts

PASS lib/liquidity.test.ts
  ✓ 유동성이 높은 마켓에서 높은 점수 반환 (3 ms)
  ✓ 유동성이 낮은 마켓에서 낮은 점수 반환 (2 ms)
  ✓ 엣지 케이스 처리: 거래량 0 (1 ms)

3 tests passed
```

✅ 리팩토링 완료, 테스트 여전히 통과!

## 8단계: 커버리지 확인

```bash
npm test -- --coverage lib/liquidity.test.ts

File           | % Stmts | % Branch | % Funcs | % Lines
---------------|---------|----------|---------|--------
liquidity.ts   |   100   |   100    |   100   |   100

Coverage: 100% ✅ (Target: 80%)
```

✅ TDD 세션 완료!
```

## TDD 모범 사례

**권장:**
- ✅ 구현 전에 테스트 먼저 작성
- ✅ 구현 전에 테스트 실행하여 실패 확인
- ✅ 테스트 통과할 최소한의 코드 작성
- ✅ 테스트가 통과한 후에만 리팩토링
- ✅ 엣지 케이스 및 오류 시나리오 추가
- ✅ 80%+ 커버리지 목표 (핵심 코드는 100%)

**금지:**
- ❌ 테스트 전에 구현 작성
- ❌ 각 변경 후 테스트 실행 건너뛰기
- ❌ 한 번에 너무 많은 코드 작성
- ❌ 실패하는 테스트 무시
- ❌ 구현 세부사항 테스트 (동작 테스트)
- ❌ 모든 것을 모킹 (통합 테스트 선호)

## 포함할 테스트 유형

**유닛 테스트** (함수 수준):
- Happy path 시나리오
- 엣지 케이스 (empty, null, max 값)
- 오류 조건
- 경계값

**통합 테스트** (컴포넌트 수준):
- API 엔드포인트
- 데이터베이스 작업
- 외부 서비스 호출
- 훅이 있는 React 컴포넌트

**E2E 테스트** (`/e2e` 커맨드 사용):
- 중요한 사용자 플로우
- 다단계 프로세스
- 풀 스택 통합

## 커버리지 요구사항

- **최소 80%** 모든 코드
- **100% 필수** 대상:
  - 금융 계산
  - 인증 로직
  - 보안 관련 코드
  - 핵심 비즈니스 로직

## 중요 사항

**필수**: 테스트는 반드시 구현 전에 작성. TDD 사이클:

1. **RED** - 실패하는 테스트 작성
2. **GREEN** - 통과하도록 구현
3. **REFACTOR** - 코드 개선

절대 RED 단계를 건너뛰지 말 것. 절대 테스트 전에 코드 작성하지 말 것.

## 다른 커맨드와의 통합

- `/plan`을 먼저 사용하여 구축할 내용 이해
- `/tdd`를 사용하여 테스트와 함께 구현
- `/build-and-fix`를 사용하여 빌드 오류 발생 시
- `/code-review`를 사용하여 구현 검토
- `/test-coverage`를 사용하여 커버리지 확인

## 관련 에이전트

이 커맨드는 다음 위치의 `tdd-guide` 에이전트를 호출:
`~/.claude/agents/tdd-guide.md`
