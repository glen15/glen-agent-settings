#!/bin/bash
# gate.sh 단위 테스트

source "${PROJECT_DIR}/src/ralph-loop/lib/gate.sh"

echo "-- check_all_passing --"

GATE_DIR=$(mktemp -d)

# 모든 기능 통과
cat > "${GATE_DIR}/prd-pass.json" << 'EOF'
{"features": [{"id": "f1", "status": "passing"}, {"id": "f2", "status": "passing"}]}
EOF
assert_exit 0 check_all_passing "${GATE_DIR}/prd-pass.json"

# 일부 실패
cat > "${GATE_DIR}/prd-fail.json" << 'EOF'
{"features": [{"id": "f1", "status": "passing"}, {"id": "f2", "status": "failing"}]}
EOF
assert_exit 1 check_all_passing "${GATE_DIR}/prd-fail.json"

# 모든 기능 실패
cat > "${GATE_DIR}/prd-all-fail.json" << 'EOF'
{"features": [{"id": "f1", "status": "failing"}, {"id": "f2", "status": "failing"}]}
EOF
assert_exit 1 check_all_passing "${GATE_DIR}/prd-all-fail.json"

# 파일 없음
assert_exit 1 check_all_passing "${GATE_DIR}/nonexistent.json"

echo "-- update_prd_status --"

cat > "${GATE_DIR}/prd-update.json" << 'EOF'
{"features": [{"id": "f1", "status": "failing"}, {"id": "f2", "status": "failing"}]}
EOF
update_prd_status "${GATE_DIR}/prd-update.json" "f1" "passing"
local_status=$(jq -r '.features[] | select(.id == "f1") | .status' "${GATE_DIR}/prd-update.json")
assert_eq "passing" "$local_status" "f1 상태가 passing으로 변경"

local_f2_status=$(jq -r '.features[] | select(.id == "f2") | .status' "${GATE_DIR}/prd-update.json")
assert_eq "failing" "$local_f2_status" "f2 상태는 그대로 failing"

# 정리
rm -rf "$GATE_DIR"
