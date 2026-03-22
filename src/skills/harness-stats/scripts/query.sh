#!/bin/bash
# harness-stats — 사용 통계 조회
# 사용법: bash query.sh <subcommand> [args]
set -euo pipefail

DB_PATH="${HOME}/.claude/harness-usage.db"

if [ ! -f "$DB_PATH" ]; then
  echo '{"error": "DB 없음. 도구 사용 후 자동 생성됩니다."}'
  exit 0
fi

cmd="${1:-today}"
shift 2>/dev/null || true

case "$cmd" in
  today)
    sqlite3 -json "$DB_PATH" \
      "SELECT tool_category, COUNT(*) as count,
              SUM(CASE WHEN success=0 THEN 1 ELSE 0 END) as fails
       FROM tool_usage
       WHERE date(timestamp) = date('now')
       GROUP BY tool_category ORDER BY count DESC;"
    ;;

  week)
    sqlite3 -json "$DB_PATH" \
      "SELECT tool_category, tool_name, COUNT(*) as count,
              SUM(CASE WHEN success=0 THEN 1 ELSE 0 END) as fails
       FROM tool_usage
       WHERE timestamp > datetime('now', '-7 days')
       GROUP BY tool_category, tool_name ORDER BY count DESC;"
    ;;

  month)
    sqlite3 -json "$DB_PATH" \
      "SELECT tool_category, tool_name, COUNT(*) as count,
              SUM(CASE WHEN success=0 THEN 1 ELSE 0 END) as fails
       FROM tool_usage
       WHERE timestamp > datetime('now', '-30 days')
       GROUP BY tool_category, tool_name ORDER BY count DESC;"
    ;;

  top)
    sqlite3 -json "$DB_PATH" \
      "SELECT tool_name, detail, tool_category, COUNT(*) as count
       FROM tool_usage
       WHERE timestamp > datetime('now', '-7 days')
       GROUP BY tool_name, detail ORDER BY count DESC LIMIT 15;"
    ;;

  unused)
    # 등록된 도구 중 최근 30일간 사용되지 않은 것
    sqlite3 -json "$DB_PATH" \
      "SELECT DISTINCT tool_name, detail, tool_category,
              MAX(timestamp) as last_used
       FROM tool_usage
       GROUP BY tool_name, detail
       HAVING MAX(timestamp) < datetime('now', '-30 days')
       ORDER BY last_used ASC;"
    ;;

  skills)
    sqlite3 -json "$DB_PATH" \
      "SELECT detail as skill, COUNT(*) as count,
              MIN(timestamp) as first_used, MAX(timestamp) as last_used
       FROM tool_usage
       WHERE tool_category IN ('skill', 'skill_script')
       GROUP BY detail ORDER BY count DESC;"
    ;;

  project)
    project_dir=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    sqlite3 -json "$DB_PATH" \
      "SELECT tool_category, tool_name, COUNT(*) as count
       FROM tool_usage
       WHERE project_dir = '$(printf '%s' "$project_dir" | sed "s/'/''/g")'
       GROUP BY tool_category, tool_name ORDER BY count DESC;"
    ;;

  trend)
    sqlite3 -json "$DB_PATH" \
      "SELECT date(timestamp) as day, COUNT(*) as total,
              SUM(CASE WHEN tool_category='skill' THEN 1 ELSE 0 END) as skills,
              SUM(CASE WHEN tool_category='mcp' THEN 1 ELSE 0 END) as mcp,
              SUM(CASE WHEN tool_category='cli' THEN 1 ELSE 0 END) as cli,
              SUM(CASE WHEN tool_category IN ('file_write','file_edit') THEN 1 ELSE 0 END) as writes,
              SUM(CASE WHEN tool_category='file_read' THEN 1 ELSE 0 END) as reads,
              SUM(CASE WHEN tool_category='search' THEN 1 ELSE 0 END) as searches
       FROM tool_usage
       WHERE timestamp > datetime('now', '-14 days')
       GROUP BY day ORDER BY day;"
    ;;

  fails)
    sqlite3 -json "$DB_PATH" \
      "SELECT tool_name, detail, COUNT(*) as fail_count,
              MAX(timestamp) as last_fail
       FROM tool_usage
       WHERE success = 0 AND timestamp > datetime('now', '-7 days')
       GROUP BY tool_name, detail ORDER BY fail_count DESC LIMIT 10;"
    ;;

  cleanup)
    days="${1:-90}"
    deleted=$(sqlite3 "$DB_PATH" \
      "DELETE FROM tool_usage WHERE timestamp < datetime('now', '-${days} days');
       SELECT changes();")
    echo "{\"deleted\": ${deleted}, \"older_than_days\": ${days}}"
    ;;

  raw)
    query="$*"
    if [ -z "$query" ]; then
      echo '{"error": "SQL 쿼리를 입력하세요"}'
      exit 1
    fi
    sqlite3 -json "$DB_PATH" "$query"
    ;;

  *)
    echo '{"error": "알 수 없는 명령. 사용 가능: today, week, month, top, unused, skills, project, trend, fails, cleanup, raw"}'
    exit 1
    ;;
esac
