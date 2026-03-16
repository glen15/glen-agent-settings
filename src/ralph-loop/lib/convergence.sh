#!/bin/bash
# Ralph Loop - 수렴 루프 (Convergent Loop)
# 라운드 기반 반복 연마로 파일 품질 수렴

# ── 스코프 초기화 ──
# 사용법: init_scope_state <scope> <project_dir> <state_file> [skip_after] [convergence_threshold]
init_scope_state() {
  local scope="$1"
  local project_dir="$2"
  local state_file="$3"
  local skip_after="${4:-3}"
  local conv_threshold="${5:-2}"

  local file_list
  file_list=$(resolve_scope "$scope" "$project_dir")

  if [ -z "$file_list" ]; then
    echo "오류: 스코프에 해당하는 파일이 없습니다: $scope" >&2
    return 1
  fi

  local file_count
  file_count=$(echo "$file_list" | wc -l | tr -d ' ')

  # scope-state.json 생성
  local files_json="{}"
  while IFS= read -r filepath; do
    [ -z "$filepath" ] && continue
    files_json=$(echo "$files_json" | jq -c \
      --arg f "$filepath" \
      '. + {($f): {"status": "active", "consecutive_skips": 0, "last_modified_round": 0, "total_modifications": 0}}')
  done <<< "$file_list"

  jq -n \
    --arg scope "$scope" \
    --argjson skip_after "$skip_after" \
    --argjson conv_threshold "$conv_threshold" \
    --arg started_at "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    --argjson files "$files_json" \
    '{
      mode: "converge",
      scope: $scope,
      skip_after: $skip_after,
      convergence_threshold: $conv_threshold,
      started_at: $started_at,
      current_round: 0,
      total_changes: 0,
      consecutive_zero_rounds: 0,
      files: $files
    }' > "$state_file"

  echo "[수렴] 스코프 초기화: ${file_count}개 파일" >&2
}

# ── 스코프 해석 ──
# all, glob 패턴, @파일목록, batch:N 지원
resolve_scope() {
  local scope="$1"
  local project_dir="$2"

  local exclude_pattern='-not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/.ralph-logs/*" -not -path "*/__pycache__/*" -not -path "*/.next/*" -not -path "*/dist/*"'

  case "$scope" in
    all)
      eval "find \"$project_dir\" -type f $exclude_pattern" | sort
      ;;
    @*)
      # @files.txt — 파일 목록에서 읽기
      local list_file="${scope#@}"
      if [ ! -f "$list_file" ]; then
        echo "오류: 파일 목록 없음: $list_file" >&2
        return 1
      fi
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        [[ "$line" == \#* ]] && continue
        if [ -f "$project_dir/$line" ]; then
          echo "$project_dir/$line"
        elif [ -f "$line" ]; then
          echo "$line"
        fi
      done < "$list_file"
      ;;
    *)
      # glob 패턴
      (cd "$project_dir" && find . -type f -name "$scope" $exclude_pattern 2>/dev/null | sed "s|^\\./|${project_dir}/|" | sort) || \
      (cd "$project_dir" && eval "ls -1 $scope 2>/dev/null" | while read -r f; do echo "${project_dir}/$f"; done)
      ;;
  esac
}

# ── 라운드 시작 태그 ──
mark_round_start() {
  local round="$1"
  git -C "$PROJECT_DIR" tag -f "ralph-round-${round}-start" HEAD 2>/dev/null || true
}

# ── 파일 상태 업데이트 ──
# 라운드 종료 후 git diff로 수정된 파일 추출, scope-state.json 업데이트
update_file_state() {
  local state_file="$1"
  local round="$2"

  # 라운드 시작 태그 대비 diff
  local changed_files=""
  if git -C "$PROJECT_DIR" rev-parse "ralph-round-${round}-start" >/dev/null 2>&1; then
    changed_files=$(git -C "$PROJECT_DIR" diff --name-only "ralph-round-${round}-start" HEAD 2>/dev/null || echo "")
  fi

  # working tree 변경도 포함
  local wt_changes
  wt_changes=$(git -C "$PROJECT_DIR" diff --name-only 2>/dev/null || echo "")
  if [ -n "$wt_changes" ]; then
    changed_files=$(printf '%s\n%s' "$changed_files" "$wt_changes" | sort -u)
  fi

  local changes_count=0
  local tmp="${state_file}.tmp"

  # 현재 상태 읽기
  cp "$state_file" "$tmp"

  # active 파일 순회
  local active_files
  active_files=$(jq -r '.files | to_entries[] | select(.value.status == "active") | .key' "$state_file")

  while IFS= read -r filepath; do
    [ -z "$filepath" ] && continue

    # 상대 경로로 변환하여 비교
    local rel_path
    rel_path=$(echo "$filepath" | sed "s|^${PROJECT_DIR}/||" | sed 's|^\./||')

    if echo "$changed_files" | grep -qF "$rel_path"; then
      # 수정된 파일
      changes_count=$((changes_count + 1))
      jq --arg f "$filepath" --argjson r "$round" \
        '.files[$f].consecutive_skips = 0 | .files[$f].last_modified_round = $r | .files[$f].total_modifications += 1' \
        "$tmp" > "${tmp}.2" && mv "${tmp}.2" "$tmp"
    else
      # 미수정 파일
      jq --arg f "$filepath" \
        '.files[$f].consecutive_skips += 1' \
        "$tmp" > "${tmp}.2" && mv "${tmp}.2" "$tmp"
    fi
  done <<< "$active_files"

  # 라운드 메타 업데이트
  jq --argjson r "$round" --argjson c "$changes_count" \
    '.current_round = $r | .total_changes += $c' \
    "$tmp" > "${tmp}.2" && mv "${tmp}.2" "$tmp"

  # 연속 무변경 라운드 카운트
  if [ "$changes_count" -eq 0 ]; then
    jq '.consecutive_zero_rounds += 1' "$tmp" > "${tmp}.2" && mv "${tmp}.2" "$tmp"
  else
    jq '.consecutive_zero_rounds = 0' "$tmp" > "${tmp}.2" && mv "${tmp}.2" "$tmp"
  fi

  mv "$tmp" "$state_file"
  echo "$changes_count"
}

# ── 점진적 제외 ──
apply_exclusions() {
  local state_file="$1"
  local skip_after="${2:-3}"
  local round="${3:-0}"

  local tmp="${state_file}.tmp"
  local excluded_count=0

  # skip_after 이상 연속 미수정인 active 파일을 excluded로 전환
  local to_exclude
  to_exclude=$(jq -r --argjson n "$skip_after" \
    '.files | to_entries[] | select(.value.status == "active" and .value.consecutive_skips >= $n) | .key' \
    "$state_file")

  if [ -n "$to_exclude" ]; then
    cp "$state_file" "$tmp"
    while IFS= read -r filepath; do
      [ -z "$filepath" ] && continue
      excluded_count=$((excluded_count + 1))
      jq --arg f "$filepath" --argjson r "$round" \
        '.files[$f].status = "excluded" | .files[$f].excluded_at_round = $r' \
        "$tmp" > "${tmp}.2" && mv "${tmp}.2" "$tmp"
    done <<< "$to_exclude"
    mv "$tmp" "$state_file"
  fi

  echo "$excluded_count"
}

# ── exception.md 파싱 ──
# 반환: 세 변수를 export
#   EXCEPTION_FIXES - 수정 요청 내용
#   EXCEPTION_EXCLUDES - 제외 요청 파일 목록
#   EXCEPTION_CRITERIA - 기준 변경 내용
parse_exception_md() {
  local exception_file="$1"
  local state_file="${2:-}"

  EXCEPTION_FIXES=""
  EXCEPTION_EXCLUDES=""
  EXCEPTION_CRITERIA=""

  if [ ! -f "$exception_file" ]; then
    return 0
  fi

  local current_section=""
  while IFS= read -r line; do
    case "$line" in
      *"수정 요청"*|*"Fix"*|*"fix"*)
        current_section="fixes" ;;
      *"제외 요청"*|*"Exclude"*|*"exclude"*)
        current_section="excludes" ;;
      *"기준 변경"*|*"Criteria"*|*"criteria"*)
        current_section="criteria" ;;
      "## "*)
        current_section="" ;;
      *)
        [ -z "$line" ] && continue
        case "$current_section" in
          fixes)    EXCEPTION_FIXES="${EXCEPTION_FIXES}${line}\n" ;;
          excludes) EXCEPTION_EXCLUDES="${EXCEPTION_EXCLUDES}${line}\n" ;;
          criteria) EXCEPTION_CRITERIA="${EXCEPTION_CRITERIA}${line}\n" ;;
        esac
        ;;
    esac
  done < "$exception_file"

  # 제외 요청된 파일을 state에 반영
  if [ -n "$EXCEPTION_EXCLUDES" ] && [ -n "$state_file" ]; then
    local tmp="${state_file}.tmp"
    cp "$state_file" "$tmp"
    while IFS= read -r exc_line; do
      [ -z "$exc_line" ] && continue
      # "- path/to/file: 설명" 형태에서 경로 추출
      local exc_path
      exc_path=$(echo "$exc_line" | sed 's/^- //' | cut -d: -f1 | tr -d ' ')
      [ -z "$exc_path" ] && continue
      # state에 해당 파일이 있으면 excluded로 전환
      if jq -e --arg f "$exc_path" '.files[$f]' "$tmp" >/dev/null 2>&1; then
        jq --arg f "$exc_path" '.files[$f].status = "excluded"' \
          "$tmp" > "${tmp}.2" && mv "${tmp}.2" "$tmp"
      fi
    done <<< "$EXCEPTION_EXCLUDES"
    mv "$tmp" "$state_file" 2>/dev/null || true
  fi
}

# ── 수렴 감지 ──
check_convergence() {
  local state_file="$1"
  local threshold="${2:-2}"

  local zero_rounds
  zero_rounds=$(jq '.consecutive_zero_rounds' "$state_file" 2>/dev/null || echo "0")

  [ "$zero_rounds" -ge "$threshold" ]
}

# ── active 파일 목록 조회 ──
get_active_files() {
  local state_file="$1"
  jq -r '.files | to_entries[] | select(.value.status == "active") | .key' "$state_file" 2>/dev/null
}

# ── active 파일 수 조회 ──
get_active_count() {
  local state_file="$1"
  jq '[.files | to_entries[] | select(.value.status == "active")] | length' "$state_file" 2>/dev/null || echo "0"
}

# ── 배치 분할 ──
# active 파일에서 batch_size만큼만 반환
get_batch_files() {
  local state_file="$1"
  local batch_size="$2"
  local offset="${3:-0}"

  if [ "$batch_size" -le 0 ]; then
    get_active_files "$state_file"
  else
    get_active_files "$state_file" | tail -n "+$((offset + 1))" | head -n "$batch_size"
  fi
}

# ── 라운드 요약 생성 ──
generate_round_summary() {
  local state_file="$1"
  local round="$2"
  local changes_count="$3"
  local excluded_count="$4"

  local active_count
  active_count=$(get_active_count "$state_file")
  local total_files
  total_files=$(jq '.files | length' "$state_file")
  local zero_rounds
  zero_rounds=$(jq '.consecutive_zero_rounds' "$state_file")

  echo "라운드 #${round} | 변경: ${changes_count}건 | 제외: ${excluded_count}건 | 활성: ${active_count}/${total_files} | 연속무변경: ${zero_rounds}"
}
