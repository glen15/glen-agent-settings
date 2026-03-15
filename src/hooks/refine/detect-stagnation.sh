#!/bin/bash
# Refine Loop - 정체 감지 스크립트
# 사용법: detect-stagnation.sh <transcript_path> <prev_error_hash> <prev_files_changed>
# 출력: "stagnation_delta|new_error_hash|new_repeated_count|current_files_changed"
#   stagnation_delta: 0 (진전 있음) 또는 1 (정체 감지)

set -euo pipefail

TRANSCRIPT_PATH="${1:-}"
PREV_ERROR_HASH="${2:-}"
PREV_FILES_CHANGED="${3:-0}"

# ── 에러 반복 감지 ──
detect_error_repetition() {
  local new_hash=""
  local repeated=0

  if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    local last_assistant
    last_assistant=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1 || echo "")
    if [ -n "$last_assistant" ]; then
      local error_text
      error_text=$(echo "$last_assistant" | jq -r '
        .message.content |
        map(select(.type == "text")) |
        map(.text) |
        join("\n")
      ' 2>/dev/null | grep -iE '(error|fail|exception|traceback|cannot|unable)' | head -5 || echo "")

      if [ -n "$error_text" ]; then
        new_hash=$(echo "$error_text" | md5 -q 2>/dev/null || echo "$error_text" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "")
        if [ -n "$PREV_ERROR_HASH" ] && [ "$new_hash" = "$PREV_ERROR_HASH" ]; then
          repeated=1
        fi
      fi
    fi
  fi

  echo "${new_hash}|${repeated}"
}

# ── Zero Delta 감지 ──
detect_zero_delta() {
  local current_files=0
  if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    current_files=$(git diff --stat HEAD 2>/dev/null | tail -1 | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || echo "0")
    if [ -z "$current_files" ]; then
      current_files=$(git diff --stat 2>/dev/null | tail -1 | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || echo "0")
    fi
  fi
  echo "$current_files"
}

# ── 종합 판단 ──
aggregate_stagnation() {
  local error_result
  error_result=$(detect_error_repetition)
  local new_hash
  new_hash=$(echo "$error_result" | cut -d'|' -f1)
  local error_repeated
  error_repeated=$(echo "$error_result" | cut -d'|' -f2)

  local current_files
  current_files=$(detect_zero_delta)

  local zero_delta=0
  if [ "$current_files" = "$PREV_FILES_CHANGED" ] && [ "$PREV_FILES_CHANGED" != "0" ]; then
    zero_delta=1
  fi

  local stagnation_delta=0
  if [ "$error_repeated" = "1" ] || [ "$zero_delta" = "1" ]; then
    stagnation_delta=1
  fi

  echo "${stagnation_delta}|${new_hash}|${error_repeated}|${current_files}"
}

aggregate_stagnation
