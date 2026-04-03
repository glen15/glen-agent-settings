# Preset 모드 — 실전 사이트 DESIGN.md 적용

awesome-design-md에서 추출한 프리셋 DESIGN.md를 프로젝트에 적용한다.
라이선스 필요 폰트는 대체 폰트로 매핑되어 있다.

## 입력

```
/design preset linear
/design preset stripe
/design preset <이름> --output ./path/DESIGN.md
```

## 사용 가능한 프리셋

| 프리셋 | 특징 | 원본 폰트 → 대체 |
|--------|------|------------------|
| `linear` | 다크 퍼스트, 정밀 엔지니어링 | Berkeley Mono → JetBrains Mono |
| `stripe` | 라이트, 금융급 프리미엄 | sohne-var → Geist |
| `vercel` | 흑백 정밀, 개발자 중심 | Geist (무료, 유지) |
| `supabase` | 다크 에메랄드, 코드 퍼스트 | (무료 폰트, 유지) |
| `notion` | 따뜻한 미니멀, 세리프 헤딩 | (무료 폰트, 유지) |
| `raycast` | 슬릭 다크, 그라디언트 액센트 | (시스템 폰트, 유지) |
| `framer` | 볼드 흑청, 모션 퍼스트 | (무료 폰트, 유지) |
| `spotify` | 바이브런트 그린 온 다크 | Circular → Outfit |
| `airbnb` | 따뜻한 코랄, 사진 중심 | Cereal → Manrope |
| `figma` | 멀티컬러, 플레이풀 | (시스템 폰트, 유지) |

## 프로세스

1. `resources/presets/<이름>.md` 파일 존재 확인
2. 없으면 사용 가능한 프리셋 목록 표시
3. 있으면 `.stitch/DESIGN.md`로 복사
4. 사용자에게 적용 완료 알림 + 커스터마이징 안내

## 커스터마이징

프리셋 적용 후 수정이 필요하면:

```
/design generate "linear 기반이지만 액센트를 에메랄드로"
```

기존 `.stitch/DESIGN.md`를 읽어서 수정 사항만 반영한다.

## 출처

프리셋 파일 상단에 출처 고지:
```
<!-- Source: VoltAgent/awesome-design-md (MIT License) -->
<!-- Font substitutions applied for license compliance -->
```
