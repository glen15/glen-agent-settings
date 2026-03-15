#!/bin/bash
# stagnation.sh 단위 테스트

source "${PROJECT_DIR}/src/ralph-loop/lib/stagnation.sh"

echo "-- compute_output_hash --"

# 임시 파일로 해시 테스트
TMP_DIR=$(mktemp -d)
echo "hello world" > "${TMP_DIR}/test1.txt"
echo "hello world" > "${TMP_DIR}/test2.txt"
echo "different content" > "${TMP_DIR}/test3.txt"

hash1=$(compute_output_hash "${TMP_DIR}/test1.txt")
hash2=$(compute_output_hash "${TMP_DIR}/test2.txt")
hash3=$(compute_output_hash "${TMP_DIR}/test3.txt")
hash_missing=$(compute_output_hash "${TMP_DIR}/nonexistent.txt")

assert_eq "$hash1" "$hash2" "동일 내용은 동일 해시"
if [ "$hash1" != "$hash3" ]; then
  PASS=$((PASS + 1))
  echo -e "  ${GREEN}PASS${NC} 다른 내용은 다른 해시"
else
  FAIL=$((FAIL + 1))
  echo -e "  ${RED}FAIL${NC} 다른 내용인데 동일 해시"
fi
assert_eq "" "$hash_missing" "존재하지 않는 파일은 빈 해시"

echo "-- detect_stagnation --"

# 순환 감지 시나리오
STAG_DIR=$(mktemp -d)
echo "same output" > "${STAG_DIR}/iteration-1.json"
echo "same output" > "${STAG_DIR}/iteration-2.json"
echo "same output" > "${STAG_DIR}/iteration-3.json"

assert_exit 0 detect_stagnation "$STAG_DIR" 3 3
assert_exit 1 detect_stagnation "$STAG_DIR" 1 3  # window보다 적음

# 비순환 시나리오
echo "different output" > "${STAG_DIR}/iteration-2.json"
assert_exit 1 detect_stagnation "$STAG_DIR" 3 3

# 정리
rm -rf "$TMP_DIR" "$STAG_DIR"
