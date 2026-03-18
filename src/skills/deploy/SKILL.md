---
name: deploy
description: "GitHub Actions CI/CD 워크플로우 생성 및 배포 관리. /deploy init — 워크플로우 스캐폴딩, /deploy tag v1.0.0 — 프로덕션 태그 배포, /deploy status — CI 상태 확인. 배포, CI/CD, GitHub Actions 설정 시 사용."
user_invocable: true
argument-hint: <init|tag|status> [인자...]
---

# Deploy — GitHub Actions CI/CD 관리

GitHub Actions 기반 CI/CD 파이프라인을 생성하고 관리한다.

## 배포 전략 (표준)

| 환경 | 트리거 | 브랜치/태그 |
|------|--------|------------|
| CI (테스트/린트/빌드) | PR 생성·업데이트 | 모든 브랜치 |
| 테스트 인프라 | push | `dev` 브랜치 |
| 프로덕션 | 태그 push | `v*` (semver) |

## 명령어

| 명령 | 설명 | 예시 |
|------|------|------|
| `init` | 프로젝트에 맞는 GitHub Actions 워크플로우 생성 | `/deploy init` |
| `tag <버전>` | 버전 태그 생성 + push (프로덕션 배포 트리거) | `/deploy tag v1.2.0` |
| `status` | 현재 브랜치의 CI/워크플로우 상태 확인 | `/deploy status` |
| (인자 없음) | 현재 배포 상태 요약 | `/deploy` |

## 실행 로직

### `init` — 워크플로우 스캐폴딩

1. **프로젝트 분석**: `package.json`, `Dockerfile`, `pyproject.toml` 등에서 스택 감지
2. **사용자에게 확인**: 감지된 스택, 배포 대상(Vercel/Cloudflare/Docker/etc), 환경변수 목록
3. **워크플로우 생성**: `.github/workflows/` 아래에 파일 생성

생성되는 워크플로우:

#### ci.yml — PR 검증
```yaml
# 트리거: PR 생성/업데이트
# 작업: 린트 → 테스트 → 빌드
# 실패 시 PR에 코멘트
```

#### deploy-test.yml — 테스트 환경 배포
```yaml
# 트리거: dev 브랜치 push
# 작업: 빌드 → 테스트 환경에 배포
# 환경변수: secrets에서 주입
```

#### deploy-prod.yml — 프로덕션 배포
```yaml
# 트리거: v* 태그 push
# 작업: 빌드 → 프로덕션 배포
# 안전장치: 테스트 통과 필수, environment protection rules
```

**주의**: 템플릿을 그대로 복사하지 말 것. `templates/` 폴더의 기본 구조를 참고하되, 프로젝트의 실제 스택/스크립트에 맞게 커스텀.

### `tag <버전>` — 프로덕션 배포

1. 현재 브랜치가 `main`인지 확인 (아니면 경고)
2. 버전 형식 검증 (semver: `v1.2.3`)
3. 최신 태그와 비교하여 버전 순서 검증

```bash
# 실행할 명령 (사용자 확인 후)
git tag -a <버전> -m "release: <버전>"
git push origin <버전>
```

4. `gh run list`로 트리거된 워크플로우 확인

### `status` — CI 상태 확인

```bash
# 현재 브랜치 최근 워크플로우 실행
gh run list --branch $(git branch --show-current) --limit 5

# 실패한 것이 있으면 상세 확인
gh run view <run-id>
```

### 인자 없음 — 배포 현황 요약

1. 최신 프로덕션 태그: `git describe --tags --abbrev=0`
2. dev 브랜치 상태: `gh run list --branch dev --limit 1`
3. 현재 브랜치 CI 상태: `gh run list --limit 3`

## Gotchas

> Claude가 CI/CD 설정에서 자주 실수하는 것. 실패할 때마다 한 줄 추가.

1. **시크릿을 워크플로우에 하드코딩** — `${{ secrets.XXX }}` 사용. 값을 직접 넣지 않기.
2. **node 버전 미고정** — `node-version: '20'`처럼 명시. `latest` 사용 금지.
3. **캐시 미설정** — `actions/cache` 또는 `setup-node`의 `cache: 'npm'` 활용으로 CI 속도 개선.
4. **permissions 미설정** — 최소 권한 원칙. `permissions: contents: read` 등 명시.
5. **concurrency 미설정** — 동일 브랜치 중복 실행 방지: `concurrency: group: ${{ github.ref }}`.
6. **환경 보호 없는 프로덕션 배포** — `environment: production` + GitHub에서 protection rules 설정.
7. **태그를 main이 아닌 브랜치에서 생성** — 프로덕션 태그는 반드시 main 브랜치에서.
