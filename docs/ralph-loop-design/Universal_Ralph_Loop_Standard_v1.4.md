# 📘 Universal Ralph Loop Standard (URLS)

## Version 1.4 --- Enterprise Edition (Self-Mutating + Meta-Ralph + OpenClaw Implementation)

------------------------------------------------------------------------

# 1. Executive Summary

Ralph Loop는 AI 및 에이전트 시스템이 단발성 응답으로 종료하지 않고,
**반복 실행 기반 수렴(convergence-driven execution)** 을 통해 완료
기준을 만족할 때까지 작업을 지속하도록 강제하는 표준 운영 구조이다.

본 문서는 다음을 모두 포함한다:

-   Base Ralph Loop
-   Self-Mutating Ralph (전략 진화 루프)
-   Meta-Ralph (상위 감독 루프)
-   OpenClaw 전용 구현 스켈레톤
-   거버넌스 및 안전 가이드
-   관련 오픈소스 및 연구 레퍼런스

------------------------------------------------------------------------

# 2. Base Ralph Loop Specification

## 2.1 Core Execution Model

Let:

-   T = Task Specification
-   Sₙ = System State at iteration n
-   Aₙ = Action
-   Vₙ = Verification Result
-   D = Definition of Done

```{=html}
<!-- -->
```
    S₀ = initialize(T)

    for n in range(MAX_ITER):
        Aₙ = plan(Sₙ)
        Sₙ₊₁ = execute(Aₙ)
        Vₙ = verify(Sₙ₊₁)

        record(Sₙ₊₁, Vₙ)

        if satisfies(Vₙ, D):
            terminate(success)

------------------------------------------------------------------------

# 3. Self-Mutating Ralph Loop

## 3.1 Concept

Self-Mutating Ralph는 반복 중 전략을 동적으로 진화시킨다.

### Mutation Trigger Conditions

-   동일 오류 3회 반복
-   Δₙ = 0 (진전 없음)
-   동일 diff 반복
-   동일 테스트 실패

### Mutation Types

1.  Planning Mutation
2.  Model Mutation
3.  Prompt Mutation
4.  Tool Mutation

### Mutation Model

    if stagnation_detected:
        strategy = mutate(strategy)
        reset_loop_context()

------------------------------------------------------------------------

# 4. Meta-Ralph Architecture

Meta-Ralph는 Ralph Loop를 감독하는 상위 루프다.

    Meta Loop
        └── Ralph Loop
                └── Execution Loop

## Meta Responsibilities

-   비용 모니터링
-   전략 변이 승인
-   루프 강제 종료
-   반복 효율 분석

------------------------------------------------------------------------

# 5. OpenClaw Implementation Skeleton

## Directory Structure

    project/
        prd.md
        progress.md
        state.json
        strategy_log.json
        logs/
        tests/

## Ralph Controller Example

``` python
MAX_ITER = 10
STAGNATION_LIMIT = 3

stagnation_count = 0

for i in range(MAX_ITER):

    session = spawn_session()

    result = session.run_task("Execute next step")

    verification = run_tests()

    delta = measure_progress()

    log_iteration(i, result, verification, delta)

    if verification.success:
        break

    if delta == 0:
        stagnation_count += 1
    else:
        stagnation_count = 0

    if stagnation_count >= STAGNATION_LIMIT:
        mutate_strategy()
        stagnation_count = 0
```

------------------------------------------------------------------------

# 6. Governance & Safety

Mandatory:

-   Iteration Hard Cap
-   Token Budget
-   Time Budget
-   Repeated Error Abort
-   Audit Logging
-   Externalized State Storage

------------------------------------------------------------------------

# 7. Referenced Implementations & Resources

## Ralph Loop Implementations

-   Vercel Ralph Loop Agent\
    https://github.com/vercel-labs/ralph-loop-agent

-   Claude Code Ralph Plugin\
    https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum

-   Snarktank Ralph Implementation\
    https://github.com/snarktank/ralph

-   Goose Ralph Loop Tutorial\
    https://block.github.io/goose/docs/tutorials/ralph-loop/

## Research Foundations

-   ReAct (Reason + Act)\
    https://arxiv.org/abs/2210.03629

-   Reflexion\
    https://arxiv.org/abs/2303.11366

-   Self-Refine\
    https://arxiv.org/abs/2303.17651

-   Tree of Thoughts\
    https://arxiv.org/abs/2305.10601

-   Voyager\
    https://arxiv.org/abs/2305.16291

------------------------------------------------------------------------

# 8. Final Principle

Ralph Loop는 반복이다.\
Self-Mutating Ralph는 진화다.\
Meta-Ralph는 통제된 진화다.

모든 조직의 AI는 수렴하도록 설계되어야 한다.
