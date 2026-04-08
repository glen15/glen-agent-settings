# Preset 모드 — 실전 사이트 DESIGN.md 적용

awesome-design-md에서 추출한 프리셋 DESIGN.md를 프로젝트에 적용한다.
라이선스 필요 폰트는 대체 폰트로 매핑되어 있다.

## 입력

```
/design preset linear
/design preset stripe
/design preset <이름> --output ./path/DESIGN.md
```

## 사용 가능한 프리셋 (58개)

### AI / LLM / ML
| 프리셋 | 특징 |
|--------|------|
| `claude` | 따뜻한 파치먼트, 세리프 헤드라인, 문학적 살롱 |
| `cohere` | 엔터프라이즈 AI, 기하학 사은세리프 |
| `cursor` | 다크 에디터, 모노+세리프 하이브리드 |
| `elevenlabs` | 모던 AI 오디오, 미니멀 다크 |
| `lovable` | 크림 톤 웜, 바이브 코딩 |
| `minimax` | 멀티모달 AI, 기하학 그로테스크 |
| `mistral` | 프렌치 프리미엄, 미니멀 |
| `ollama` | 라운드 sans, 로컬 퍼스트 |
| `opencode` | 모노스페이스 유니버스, 미니멀 다크 |
| `replicate` | ML 플랫폼, 크림 톤 |
| `runwayml` | 크리에이티브 AI, 모던 아트 갤러리 |
| `together` | 파스텔 그라디언트, 기하학 모더니즘 |
| `x` | 흑백 sans + 모노 버튼, 초미니멀 |

### Dev Tools / DevOps
| 프리셋 | 특징 |
|--------|------|
| `cal` | 스케줄링, Cal Sans 디스플레이 |
| `composio` | MCP 통합 플랫폼, 다크 코드 중심 |
| `expo` | 모바일 dev, 정보 밀도 |
| `hashicorp` | 엔터프라이즈 인프라, 블루 액센트 |
| `linear` | 다크 퍼스트, 정밀 엔지니어링 |
| `mintlify` | 개발자 문서, 라이트 미니멀 |
| `posthog` | 프로덕트 애널리틱스, IBM Plex Sans |
| `resend` | 이메일 API, 도메인 세리프 |
| `sentry` | 에러 트래킹, 브랜드 인격 폰트 |
| `supabase` | 다크 에메랄드, 코드 퍼스트 |
| `vercel` | 흑백 정밀, 개발자 중심 |
| `voltagent` | 오픈소스 에이전트 프레임워크 |
| `warp` | AI 터미널, 웜 모노 |

### SaaS / 프로덕티비티
| 프리셋 | 특징 |
|--------|------|
| `airtable` | 스프레드시트+DB, Haas 계열 |
| `figma` | 멀티컬러 플레이풀, 모노스페이스 라벨 |
| `framer` | 볼드 흑청, 모션 퍼스트 |
| `intercom` | 고객 메시징, Saans + Serif 페어 |
| `miro` | 화이트보드 협업, Roobert 계열 |
| `notion` | 따뜻한 미니멀, 세리프 헤딩 |
| `sanity` | 헤드리스 CMS, 웜 중립 |
| `superhuman` | 프리미엄 이메일, Super Sans VF |
| `webflow` | 비주얼 웹 빌더, 기하학 sans |
| `zapier` | 오렌지 액센트, Degular Display |

### 결제 / 금융 / 핀테크
| 프리셋 | 특징 |
|--------|------|
| `coinbase` | 다크 크립토, 기관 신뢰 |
| `kraken` | 다크 보라, 트레이딩 퍼스트 |
| `revolut` | 다크 블루, 기하학 그로테스크 |
| `stripe` | 라이트, 금융급 프리미엄 |
| `wise` | 그린 액센트, 다중 통화 |

### 인프라 / 데이터 / 클라우드
| 프리셋 | 특징 |
|--------|------|
| `clickhouse` | OLAP DB, 노란 액센트 |
| `ibm` | 엔터프라이즈, IBM Plex 패밀리 |
| `mongodb` | 데이터 플랫폼, Fraunces 세리프 + 그린 |
| `nvidia` | 그린 액센트, 하드웨어 프리미엄 |

### 크리에이터 / 브랜드 / 미디어
| 프리셋 | 특징 |
|--------|------|
| `airbnb` | 따뜻한 코랄, 사진 중심 |
| `clay` | 브루탈리스트 에이전시, Roobert |
| `pinterest` | 이미지 큐레이션, 빨간 액센트 |
| `raycast` | 슬릭 다크, 그라디언트 액센트 |
| `spotify` | 바이브런트 그린 온 다크 |
| `uber` | 블랙 앤 화이트, UberMove |

### 우주 / 모빌리티 / 럭셔리
| 프리셋 | 특징 |
|--------|------|
| `apple` | Apple 제품 페이지, 미니멀 프리미엄 |
| `bmw` | 모빌리티 다크, BMWType 계열 |
| `ferrari` | 레드 액센트, 레이싱 헤리티지 |
| `lamborghini` | 블랙 + 각진 타입, Neo-Grotesk |
| `renault` | NouvelR 단일 폰트, 미니멀 |
| `spacex` | 우주 테크, D-DIN 산업용 |
| `tesla` | Universal Sans, 통합 생태계 |

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

## 출처 및 재싱크

모든 프리셋은 [VoltAgent/awesome-design-md](https://github.com/VoltAgent/awesome-design-md)에서 자동 싱크된다.

```bash
# 업스트림 최신 상태로 재싱크
./src/skills/glen-design/scripts/sync-presets.sh
```

스크립트 동작:
1. `gh api` 로 업스트림 tarball 다운로드
2. `scripts/font-substitutions.tsv` 매핑 규칙으로 프로프라이어터리 폰트를 무료 대체
3. 각 파일에 라이선스 헤더 + 제목 정규화
4. `resources/presets/<브랜드>.md`로 저장 (도메인 접미사 제거: `linear.app` → `linear`)

프리셋 파일 상단 주석:
```
<!-- Source: VoltAgent/awesome-design-md (MIT License) -->
<!-- Synced by: src/skills/glen-design/scripts/sync-presets.sh -->
<!-- Font substitutions: see scripts/font-substitutions.tsv -->
```

## 폰트 대체 규칙 요약

라이선스 필요 커스텀 폰트는 다음과 같이 무료 Google Fonts/시스템 폰트로 매핑된다:

| 원본 계열 | 대체 |
|----------|------|
| Airbnb Cereal, Saans, Pin Sans, Euclid Circular A | `Manrope` |
| Circular, Aeonik Pro, GT Walsheim, Degular, Spotify Mix | `Outfit` |
| Haas, CohereText, Kraken-Brand, NVIDIA-EMEA, BMW/Ferrari/Lambo, Dammit Sans, The Future, PP Neue Montreal, rb-freigeist | `Space Grotesk` |
| sohne-var, CoinbaseDisplay, Universal Sans, Wise Sans, Waldenburg | `Geist` |
| Anthropic Serif, Domaine, Serrif, MongoDB Value Serif, GT Alpina, jjannon | `Fraunces` |
| Berkeley Mono, berkeleyMono, PP Neue Montreal Mono, commitMono, figmaMono | `JetBrains Mono` |
| Anthropic Mono, CohereMono | `Geist Mono` |
| D-DIN, D-DIN-Bold | `Oswald` |
| Camera Plain Variable | `Cabinet Grotesk` |
| SF Pro Display/Text, NotionInter, abcDiatype, CursorGothic, figmaSans, Roobert, Matter, UberMove, WF Visual Sans, Super Sans VF 기타 다수 | `Inter` |

전체 규칙은 [`scripts/font-substitutions.tsv`](../scripts/font-substitutions.tsv) 참조.
