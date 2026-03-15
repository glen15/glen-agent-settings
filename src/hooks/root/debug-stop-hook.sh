#!/usr/bin/env bash
# Stop hook 디버그: stdin JSON을 파일에 저장
INPUT="$(cat)"
LOGFILE="$HOME/.claude/hooks/stop-hook-debug.json"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $1" >> "$LOGFILE"
echo "$INPUT" | python3 -m json.tool >> "$LOGFILE" 2>/dev/null || echo "$INPUT" >> "$LOGFILE"
echo "---" >> "$LOGFILE"
