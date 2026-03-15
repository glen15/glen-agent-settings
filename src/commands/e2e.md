---
description: Playwright를 사용하여 E2E 테스트 생성 및 실행. 테스트 여정 생성, 테스트 실행, 스크린샷/비디오/트레이스 캡처 및 아티팩트 업로드.
---

# E2E 커맨드

이 커맨드는 **e2e-runner** 에이전트를 호출하여 Playwright를 사용한 E2E 테스트를 생성, 유지 관리 및 실행합니다.

## 이 커맨드가 하는 일

1. **테스트 여정 생성** - 사용자 플로우에 대한 Playwright 테스트 생성
2. **E2E 테스트 실행** - 여러 브라우저에서 테스트 실행
3. **아티팩트 캡처** - 실패 시 스크린샷, 비디오, 트레이스 저장
4. **결과 업로드** - HTML 보고서 및 JUnit XML
5. **불안정한 테스트 식별** - 불안정한 테스트 격리

## 사용 시점

다음 경우에 `/e2e` 사용:
- 중요한 사용자 여정 테스트 (로그인, 거래, 결제)
- 다단계 플로우가 E2E로 작동하는지 확인
- UI 상호작용 및 내비게이션 테스트
- 프론트엔드와 백엔드 간 통합 검증
- 프로덕션 배포 준비

## 작동 방식

e2e-runner 에이전트가 수행하는 작업:

1. **사용자 플로우 분석** 및 테스트 시나리오 식별
2. **Playwright 테스트 생성** - Page Object Model 패턴 사용
3. **테스트 실행** - 여러 브라우저 (Chrome, Firefox, Safari)
4. **실패 캡처** - 스크린샷, 비디오, 트레이스
5. **보고서 생성** - 결과 및 아티팩트 포함
6. **불안정한 테스트 식별** 및 수정 권장

## 사용 예시

```
User: /e2e 마켓 검색 및 조회 플로우 테스트

Agent (e2e-runner):
# E2E 테스트 생성: 마켓 검색 및 조회 플로우

## 식별된 테스트 시나리오

**사용자 여정:** 마켓 검색 → 결과 확인 → 마켓 클릭 → 상세 조회

**테스트 커버리지:**
1. 마켓 페이지로 이동
2. 시맨틱 검색 수행
3. 검색 결과 확인
4. 첫 번째 결과 클릭
5. 마켓 상세 페이지 로드 확인
6. 차트 렌더링 확인

## 생성된 테스트 코드

```typescript
// tests/e2e/markets/search-and-view.spec.ts
import { test, expect } from '@playwright/test'
import { MarketsPage } from '../../pages/MarketsPage'
import { MarketDetailsPage } from '../../pages/MarketDetailsPage'

test.describe('마켓 검색 및 조회 플로우', () => {
  test('사용자가 마켓을 검색하고 상세를 볼 수 있다', async ({ page }) => {
    // 1. 마켓 페이지로 이동
    const marketsPage = new MarketsPage(page)
    await marketsPage.goto()

    // 페이지 로드 확인
    await expect(page).toHaveTitle(/Markets/)
    await expect(page.locator('h1')).toContainText('Markets')

    // 2. 시맨틱 검색 수행
    await marketsPage.searchMarkets('election')

    // API 응답 대기
    await page.waitForResponse(resp =>
      resp.url().includes('/api/markets/search') && resp.status() === 200
    )

    // 3. 검색 결과 확인
    const marketCards = marketsPage.marketCards
    await expect(marketCards.first()).toBeVisible()
    const resultCount = await marketCards.count()
    expect(resultCount).toBeGreaterThan(0)

    // 검색 결과 스크린샷
    await page.screenshot({ path: 'artifacts/search-results.png' })

    // 4. 첫 번째 결과 클릭
    const firstMarketTitle = await marketCards.first().textContent()
    await marketCards.first().click()

    // 5. 마켓 상세 페이지 로드 확인
    await expect(page).toHaveURL(/\/markets\/[a-z0-9-]+/)

    const detailsPage = new MarketDetailsPage(page)
    await expect(detailsPage.marketName).toBeVisible()
    await expect(detailsPage.marketDescription).toBeVisible()

    // 6. 차트 렌더링 확인
    await expect(detailsPage.priceChart).toBeVisible()

    // 마켓 상세 스크린샷
    await page.screenshot({ path: 'artifacts/market-details.png' })
  })
})
```

## 테스트 실행

```bash
# 생성된 테스트 실행
npx playwright test tests/e2e/markets/search-and-view.spec.ts

Running 3 tests using 3 workers

  ✓  [chromium] › search-and-view.spec.ts:5:3 › 사용자가 마켓을 검색하고 상세를 볼 수 있다 (4.2s)

  1 passed (4.2s)

생성된 아티팩트:
- artifacts/search-results.png
- artifacts/market-details.png
- playwright-report/index.html
```

## 테스트 보고서

```
╔══════════════════════════════════════════════════════════════╗
║                    E2E 테스트 결과                            ║
╠══════════════════════════════════════════════════════════════╣
║ 상태:      ✅ 모든 테스트 통과                                ║
║ 총합:      1 테스트                                          ║
║ 통과:      1 (100%)                                          ║
║ 실패:      0                                                 ║
║ 불안정:    0                                                 ║
║ 소요시간:  4.2s                                              ║
╚══════════════════════════════════════════════════════════════╝

아티팩트:
📸 스크린샷: 2 파일
📹 비디오: 0 파일 (실패 시에만)
🔍 트레이스: 0 파일 (실패 시에만)
📊 HTML 보고서: playwright-report/index.html

보고서 보기: npx playwright show-report
```

✅ CI/CD 통합 준비 완료!
```

## 테스트 아티팩트

테스트 실행 시 캡처되는 아티팩트:

**모든 테스트:**
- 타임라인 및 결과가 포함된 HTML 보고서
- CI 통합용 JUnit XML

**실패 시에만:**
- 실패 상태의 스크린샷
- 테스트 비디오 녹화
- 디버깅용 트레이스 파일 (단계별 재생)
- 네트워크 로그
- 콘솔 로그

## 아티팩트 보기

```bash
# 브라우저에서 HTML 보고서 보기
npx playwright show-report

# 특정 트레이스 파일 보기
npx playwright show-trace artifacts/trace-abc123.zip

# 스크린샷은 artifacts/ 디렉토리에 저장
open artifacts/search-results.png
```

## 불안정한 테스트 감지

테스트가 간헐적으로 실패하는 경우:

```
⚠️  불안정한 테스트 감지: tests/e2e/markets/trade.spec.ts

테스트 통과 7/10 회 (70% 통과율)

일반적인 실패:
"'[data-testid="confirm-btn"]' 요소 대기 중 타임아웃"

권장 수정:
1. 명시적 대기 추가: await page.waitForSelector('[data-testid="confirm-btn"]')
2. 타임아웃 증가: { timeout: 10000 }
3. 컴포넌트의 경쟁 조건 확인
4. 애니메이션에 의해 요소가 숨겨지지 않는지 확인

격리 권장: 수정될 때까지 test.fixme()로 표시
```

## 브라우저 설정

기본적으로 여러 브라우저에서 테스트 실행:
- ✅ Chromium (Desktop Chrome)
- ✅ Firefox (Desktop)
- ✅ WebKit (Desktop Safari)
- ✅ Mobile Chrome (선택 사항)

브라우저 조정은 `playwright.config.ts`에서 설정.

## CI/CD 통합

CI 파이프라인에 추가:

```yaml
# .github/workflows/e2e.yml
- name: Install Playwright
  run: npx playwright install --with-deps

- name: Run E2E tests
  run: npx playwright test

- name: Upload artifacts
  if: always()
  uses: actions/upload-artifact@v3
  with:
    name: playwright-report
    path: playwright-report/
```

## 모범 사례

**권장:**
- ✅ 유지보수성을 위해 Page Object Model 사용
- ✅ 셀렉터에 data-testid 속성 사용
- ✅ 임의의 타임아웃이 아닌 API 응답 대기
- ✅ 중요한 사용자 여정을 E2E로 테스트
- ✅ main 병합 전 테스트 실행
- ✅ 테스트 실패 시 아티팩트 검토

**금지:**
- ❌ 취약한 셀렉터 사용 (CSS 클래스는 변경될 수 있음)
- ❌ 구현 세부사항 테스트
- ❌ 프로덕션에서 테스트 실행
- ❌ 불안정한 테스트 무시
- ❌ 실패 시 아티팩트 검토 건너뛰기
- ❌ 모든 엣지 케이스를 E2E로 테스트 (유닛 테스트 사용)

## 다른 커맨드와의 통합

- `/plan`을 사용하여 테스트할 중요 여정 식별
- `/tdd`를 사용하여 유닛 테스트 (더 빠르고 세분화됨)
- `/e2e`를 사용하여 통합 및 사용자 여정 테스트
- `/code-review`를 사용하여 테스트 품질 검증

## 관련 에이전트

이 커맨드는 다음 위치의 `e2e-runner` 에이전트를 호출:
`~/.claude/agents/e2e-runner.md`

## 빠른 명령어

```bash
# 모든 E2E 테스트 실행
npx playwright test

# 특정 테스트 파일 실행
npx playwright test tests/e2e/markets/search.spec.ts

# 브라우저 표시 모드로 실행
npx playwright test --headed

# 테스트 디버그
npx playwright test --debug

# 테스트 코드 생성
npx playwright codegen http://localhost:3000

# 보고서 보기
npx playwright show-report
```
