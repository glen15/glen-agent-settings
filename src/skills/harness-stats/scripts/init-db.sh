#!/bin/bash
# harness-stats — SQLite DB 초기화
# 사용법: bash init-db.sh
set -euo pipefail

DB_PATH="${HOME}/.claude/harness-usage.db"

sqlite3 "$DB_PATH" <<'SQL'
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS tool_usage (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    session_id  TEXT,
    project_dir TEXT,
    tool_name   TEXT    NOT NULL,
    tool_category TEXT  NOT NULL,
    detail      TEXT,
    file_path   TEXT,
    success     INTEGER DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_tool_usage_timestamp ON tool_usage(timestamp);
CREATE INDEX IF NOT EXISTS idx_tool_usage_category  ON tool_usage(tool_category);
CREATE INDEX IF NOT EXISTS idx_tool_usage_project   ON tool_usage(project_dir);
CREATE INDEX IF NOT EXISTS idx_tool_usage_tool      ON tool_usage(tool_name);

CREATE VIEW IF NOT EXISTS daily_summary AS
SELECT
    date(timestamp) AS day,
    tool_category,
    tool_name,
    COUNT(*)  AS call_count,
    SUM(CASE WHEN success = 0 THEN 1 ELSE 0 END) AS fail_count,
    project_dir
FROM tool_usage
GROUP BY day, tool_category, tool_name, project_dir;
SQL

echo "DB 초기화 완료: $DB_PATH"
