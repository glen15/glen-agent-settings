---
name: security-review
description: "사용자 입력 처리, 인증, API 엔드포인트, 결제, 시크릿 관련 코드 작성 시 자동 활성화. 프로젝트 특화 보안 함정과 체크리스트 제공."
---

# Security Review

코드 변경 시 보안 관점에서 검토한다. **Claude가 이미 아는 일반 보안 상식은 적지 않는다.**
이 스킬은 "Claude가 구체적으로 놓치는 부분"에만 집중한다.

## 트리거 조건

- 인증/인가 코드 추가·수정
- 사용자 입력을 받는 API 엔드포인트
- 시크릿/환경변수 관련 작업
- 결제/금융 기능
- 파일 업로드 처리
- 서드파티 API 통합

## 체크리스트 (커밋 전 필수)

- [ ] 하드코딩된 시크릿 없음 → 환경변수 사용
- [ ] `.env` → `.gitignore` 포함
- [ ] 사용자 입력 Zod 등으로 검증
- [ ] 에러 메시지에 스택 트레이스/내부 정보 노출 없음
- [ ] 인가 체크가 컨트롤러가 아닌 미들웨어/가드에서 수행
- [ ] Rate limiting 적용 (특히 인증/검색 엔드포인트)
- [ ] Supabase RLS 활성화 확인 (Supabase 사용 시)

## Gotchas

> Claude가 이 영역에서 자주 실수하는 것. 실패할 때마다 한 줄 추가.

1. **JWT를 localStorage에 저장** — Claude가 기본으로 `localStorage.setItem('token', ...)` 패턴을 쓴다. 반드시 httpOnly 쿠키 사용.
2. **에러에서 원본 메시지 노출** — `catch (e) { return { error: e.message } }` 패턴을 쓰면 내부 DB 스키마, 파일 경로가 노출된다. 사용자에겐 제네릭 메시지만.
3. **CORS에 와일드카드** — 개발 중 `origin: '*'`를 넣고 프로덕션에 그대로 가는 경우. 명시적 origin 리스트 사용.
4. **환경변수 존재 확인 누락** — `process.env.API_KEY`를 바로 쓰되, undefined 체크 없이 진행. 부팅 시 필수 환경변수 검증 패턴 사용.
5. **Supabase 서비스 키를 클라이언트에서 사용** — `SUPABASE_SERVICE_ROLE_KEY`는 서버 전용. 클라이언트는 `SUPABASE_ANON_KEY`만.
6. **비밀번호 비교에 === 사용** — timing attack 방지를 위해 `crypto.timingSafeEqual` 사용.
