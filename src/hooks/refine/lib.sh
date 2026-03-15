#!/bin/bash
# Refine Loop - 공유 함수 라이브러리
# 모든 Refine Loop 훅에서 source하여 사용합니다.

# ── 경로 상수 ──
REFINE_STATE_FILE=".claude/refine-loop.local.md"
REFINE_STATE_JSON=".claude/refine-state.json"
REFINE_LEGACY_FILE=".claude/ralph-loop.local.md"

# ── YAML Frontmatter 파싱 ──

# frontmatter 전체를 추출 (--- 사이의 내용)
parse_frontmatter() {
  local file="$1"
  if [ ! -f "$file" ]; then
    return 1
  fi
  sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$file"
}

# frontmatter에서 특정 필드 값 추출
get_frontmatter_field() {
  local file="$1"
  local key="$2"
  local default="${3:-}"
  if [ ! -f "$file" ]; then
    echo "$default"
    return
  fi
  local value
  value=$(parse_frontmatter "$file" | grep "^${key}:" | head -1 | sed "s/^${key}: *//; s/\"//g; s/ *#.*//")
  if [ -z "$value" ]; then
    echo "$default"
  else
    echo "$value"
  fi
}

# frontmatter 뒤의 프롬프트 본문 추출
parse_prompt_body() {
  local file="$1"
  if [ ! -f "$file" ]; then
    return 1
  fi
  awk '/^---$/{i++; next} i>=2' "$file"
}

# ── 상태 업데이트 ──

# frontmatter의 특정 필드를 원자적으로 업데이트
update_frontmatter_field() {
  local file="$1"
  local key="$2"
  local value="$3"
  if [ ! -f "$file" ]; then
    return 1
  fi
  local tmp="${file}.tmp"
  # 숫자, boolean은 따옴표 없이, 문자열은 따옴표로 감싸기
  if [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [[ "$value" =~ ^(true|false)$ ]]; then
    sed "s/^${key}: .*/${key}: ${value}/" "$file" > "$tmp" && mv "$tmp" "$file"
  else
    sed "s/^${key}: .*/${key}: \"${value}\"/" "$file" > "$tmp" && mv "$tmp" "$file"
  fi
}

# 여러 필드를 한 번에 업데이트
update_frontmatter_fields() {
  local file="$1"
  shift
  while [ $# -ge 2 ]; do
    update_frontmatter_field "$file" "$1" "$2"
    shift 2
  done
}

# ── 시간 유틸리티 ──

# ISO 8601 UTC 타임스탬프를 epoch seconds로 변환
# macOS date -j는 TZ를 무시하므로 TZ=UTC를 명시
parse_utc_timestamp() {
  local ts="$1"
  if [ -z "$ts" ]; then
    echo "0"
    return
  fi
  TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null \
    || date -d "$ts" +%s 2>/dev/null \
    || echo "0"
}

# 시작 시간부터 경과한 분 수 계산
elapsed_minutes_since() {
  local started_at="$1"
  local started_epoch
  started_epoch=$(parse_utc_timestamp "$started_at")
  local now_epoch
  now_epoch=$(date +%s)
  echo $(( (now_epoch - started_epoch) / 60 ))
}

# ── 상태 파일 관리 ──

# Refine Loop 활성 여부 확인
is_refine_active() {
  [ -f "$REFINE_STATE_FILE" ] && [ "$(get_frontmatter_field "$REFINE_STATE_FILE" "active" "false")" = "true" ]
}

# 상태 파일 제거 및 종료
cleanup_state() {
  local reason="${1:-완료}"
  echo "Refine Loop 종료: ${reason}" >&2
  rm -f "$REFINE_STATE_FILE"
}

# ── 레거시 마이그레이션 (ralph → refine) ──

# 기존 ralph 상태 파일을 refine으로 변환
migrate_legacy_if_needed() {
  if [ ! -f "$REFINE_LEGACY_FILE" ]; then
    return 0
  fi
  if [ -f "$REFINE_STATE_FILE" ]; then
    rm -f "$REFINE_LEGACY_FILE"
    return 0
  fi

  # ralph 상태 파일을 refine으로 복사 후 키워드 변환
  cp "$REFINE_LEGACY_FILE" "$REFINE_STATE_FILE"
  local tmp="${REFINE_STATE_FILE}.tmp"
  sed 's/RALPH_DONE/REFINE_DONE/g' "$REFINE_STATE_FILE" > "$tmp" && mv "$tmp" "$REFINE_STATE_FILE"
  rm -f "$REFINE_LEGACY_FILE"
  echo "Ralph → Refine 마이그레이션 완료" >&2
}
