#!/bin/bash
# gate.sh 단위 테스트

source "${PROJECT_DIR}/src/ralph-loop/lib/gate.sh"

echo "-- check_convergence_state --"

GATE_DIR=$(mktemp -d)

# scope-state.json 생성 (수렴 완료)
cat > "${GATE_DIR}/scope-state-converged.json" << 'EOF'
{"mode": "converge", "consecutive_zero_rounds": 3, "files": {}}
EOF
assert_exit 0 check_convergence_state "${GATE_DIR}/scope-state-converged.json" 2

# scope-state.json 생성 (아직 수렴 안됨)
cat > "${GATE_DIR}/scope-state-active.json" << 'EOF'
{"mode": "converge", "consecutive_zero_rounds": 1, "files": {}}
EOF
assert_exit 1 check_convergence_state "${GATE_DIR}/scope-state-active.json" 2

# 파일 없음
assert_exit 1 check_convergence_state "${GATE_DIR}/nonexistent.json"

# 정리
rm -rf "$GATE_DIR"
